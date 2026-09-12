import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'storage_keys.dart';

/// Names used inside the versioned financial-data envelope.
class FinancialSections {
  FinancialSections._();

  static const transactions = 'transactions';
  static const netWorthEntries = 'netWorthEntries';
  static const selectedNetWorthMonth = 'selectedNetWorthMonth';
  static const categoryBudgetLimits = 'categoryBudgetLimits';
  static const savingsGoals = 'savingsGoals';
  static const recurringTransactions = 'recurringTransactions';
  static const categories = 'categories';
  static const transactionTags = 'transactionTags';
  static const categorizationRules = 'categorizationRules';
  static const appSettings = 'appSettings';
}

/// A versioned snapshot of all core financial state.
class FinancialSnapshot {
  final int schemaVersion;
  final int revision;
  final Map<String, dynamic> sections;

  const FinancialSnapshot({
    required this.schemaVersion,
    required this.revision,
    required this.sections,
  });

  /// The state of a device that has never stored anything.
  static const FinancialSnapshot empty = FinancialSnapshot(
    schemaVersion: AtomicFinancialStore.schemaVersion,
    revision: 0,
    sections: <String, dynamic>{},
  );

  FinancialSnapshot copyWithSections(Map<String, dynamic> updates) {
    return FinancialSnapshot(
      schemaVersion: schemaVersion,
      revision: revision + 1,
      sections: Map<String, dynamic>.from(sections)..addAll(updates),
    );
  }
}

/// Thrown when the store cannot read or durably write the financial data.
class FinancialStoreException implements Exception {
  final String message;
  final Object? cause;

  const FinancialStoreException(this.message, [this.cause]);

  @override
  String toString() =>
      cause == null ? message : '$message (${cause.runtimeType}: $cause)';
}

/// Stores all financial state as one checksummed file with a last-known-good
/// backup, in the app's application-support directory.
///
/// Why a file and not `SharedPreferences`: on iOS that API is backed by
/// `NSUserDefaults`, which gives no durability guarantee for a write that has
/// "completed", caps a defaults domain at roughly 4 MB, and reads back empty
/// while the device is locked before first unlock. None of those failures are
/// observable from Dart because the plugin answers every write from its own
/// in-memory cache. A file written to a temporary path, flushed, and renamed
/// into place is either fully there or not there at all, and can be read back
/// from disk to prove it.
///
/// Commit protocol for every write:
///   1. Serialize the next snapshot and write it to `<primary>.tmp`, flushed.
///   2. Copy the current primary to the backup (only if it is itself intact,
///      so a corrupt primary never replaces a good backup).
///   3. Atomically rename `<primary>.tmp` over the primary.
///   4. Read the primary back from disk and verify its checksum and revision.
///      Any mismatch surfaces as a [FinancialStoreException] to the caller.
///
/// On load, the primary and backup are both decoded and the newest readable
/// revision wins. On the first launch after this store was introduced, the
/// previous `SharedPreferences` envelope, its backup, and the legacy
/// per-feature keys are migrated, again preferring the newest readable copy.
class AtomicFinancialStore {
  static const int schemaVersion = 2;
  static const String directoryName = 'financial_store';
  static const String primaryFileName = 'financial_store_v2.json';
  static const String backupFileName = 'financial_store_v2.backup.json';

  static const String _formatTag = 'budgie-financial-store';

  /// Keys the previous, `SharedPreferences`-backed store used.
  static const String legacyPreferencesPrimaryKey = 'financial_store_v1';
  static const String legacyPreferencesBackupKey = 'financial_store_v1_backup';

  /// Legacy keys that carried a copy of a section this envelope now owns.
  /// They are removed after a verified migration so the defaults domain
  /// stops growing with the ledger.
  static const List<String> migratedPreferenceKeys = [
    legacyPreferencesPrimaryKey,
    legacyPreferencesBackupKey,
    StorageKeys.transactions,
    StorageKeys.netWorthEntries,
    StorageKeys.netWorthSelectedMonth,
    StorageKeys.categoryBudgetLimits,
    StorageKeys.savingsGoals,
    StorageKeys.recurringTransactions,
    StorageKeys.categories,
    StorageKeys.transactionTags,
    StorageKeys.categorizationRules,
  ];

  static final AtomicFinancialStore instance = AtomicFinancialStore._();

  AtomicFinancialStore._();

  _StoreBackend? _backend;
  FinancialSnapshot? _snapshot;
  Future<FinancialSnapshot>? _loading;

  /// Tail of the serialized write queue; null while idle. Kept nullable on
  /// purpose: a pre-completed placeholder future would carry the zone it was
  /// created in, and continuations chained onto it from another zone (a
  /// widget test's fake event loop after a `setUp` reset) would never run.
  Future<void>? _writeQueue;

  /// Drains pending writes, forgets in-memory state, and points the store at
  /// [directory]. Without a directory the store keeps its files in memory,
  /// which is what widget tests need: they run under FakeAsync, where real
  /// file I/O never completes.
  @visibleForTesting
  Future<void> resetForTesting({Directory? directory}) async {
    final pending = _writeQueue;
    if (pending != null) {
      try {
        // A queue left behind by a widget test lives in that test's fake
        // event loop and can never complete here; do not wait forever.
        await pending.timeout(const Duration(seconds: 2));
      } catch (_) {
        // Failures or leftovers of the previous test's writes are its own
        // business; this test starts from a clean store either way.
      }
    }
    _snapshot = null;
    _loading = null;
    _writeQueue = null;
    _backend = directory == null ? null : _DirectoryBackend(directory);
  }

  /// The directory holding the store files. Only meaningful for the real,
  /// directory-backed store.
  Future<Directory> storageDirectory() async {
    final backend = await _resolveBackend();
    if (backend is _DirectoryBackend) return backend.directory;
    throw StateError('The financial store is not backed by a directory');
  }

  /// Whether a snapshot has been loaded into memory yet.
  bool get isLoaded => _snapshot != null;

  /// Returns the current snapshot, loading it from disk on first use. The
  /// load itself never writes an empty snapshot: a fresh install simply
  /// returns [FinancialSnapshot.empty] until the first real mutation.
  Future<FinancialSnapshot> read() {
    final loaded = _snapshot;
    if (loaded != null) return Future<FinancialSnapshot>.value(loaded);
    return _loading ??= _load().then((snapshot) {
      _snapshot = snapshot;
      return snapshot;
    }).whenComplete(() => _loading = null);
  }

  Future<void> updateSection(String section, dynamic value) {
    return updateSections({section: value});
  }

  Future<void> updateSections(Map<String, dynamic> updates) {
    return _enqueue(() async {
      final current = await read();
      final next = current.copyWithSections(updates);
      await _commit(next);
      _snapshot = next;
    });
  }

  Future<void> replace(FinancialSnapshot snapshot) {
    return _enqueue(() async {
      final current = await read();
      final replacement = FinancialSnapshot(
        schemaVersion: schemaVersion,
        revision: current.revision + 1,
        sections: Map<String, dynamic>.from(snapshot.sections),
      );
      await _commit(replacement);
      _snapshot = replacement;
    });
  }

  Future<void> _enqueue(Future<void> Function() operation) {
    final previous = _writeQueue;
    final result =
        previous == null ? operation() : previous.then((_) => operation());
    late final Future<void> tail;
    tail = result
        .then<void>(
      (_) {},
      onError: (_, __) {},
    )
        .whenComplete(() {
      if (identical(_writeQueue, tail)) _writeQueue = null;
    });
    _writeQueue = tail;
    return result;
  }

  // ---------------------------------------------------------------------------
  // Loading

  Future<FinancialSnapshot> _load() async {
    final backend = await _resolveBackend();

    final primaryBytes = await backend.readIfPresent(primaryFileName);
    final backupBytes = await backend.readIfPresent(backupFileName);
    final primary = primaryBytes == null ? null : _decodeBytes(primaryBytes);
    final backup = backupBytes == null ? null : _decodeBytes(backupBytes);

    if (primary != null || backup != null) {
      if (primary != null &&
          (backup == null || primary.revision >= backup.revision)) {
        return primary;
      }
      // The primary is missing, unreadable, or older than the backup. Restore
      // the primary from the backup so the next load does not depend on it.
      final restored = backup!;
      debugPrint(
        'Financial store: primary ${primary == null ? 'unreadable' : 'stale'}, '
        'restoring revision ${restored.revision} from backup',
      );
      await backend.writeAtomically(primaryFileName, _encode(restored));
      await _verifyOnDisk(backend, restored.revision);
      return restored;
    }

    if (primaryBytes != null || backupBytes != null) {
      // Both files exist but neither decodes. Keep them for forensics and
      // fall through to the legacy sources rather than silently starting over.
      final stamp = DateTime.now().millisecondsSinceEpoch;
      if (primaryBytes != null) {
        await backend.setAside(primaryFileName, '.corrupt-$stamp');
      }
      if (backupBytes != null) {
        await backend.setAside(backupFileName, '.corrupt-$stamp');
      }
      debugPrint(
          'Financial store: both files unreadable, set aside as .corrupt-$stamp');
    }

    final migrated = await _migrateFromPreferences();
    if (migrated == null) {
      return FinancialSnapshot.empty;
    }
    await _commit(migrated);
    await _removeMigratedPreferenceKeys();
    return migrated;
  }

  Future<FinancialSnapshot?> _migrateFromPreferences() async {
    final preferences = await SharedPreferences.getInstance();
    final envelopePrimary = _decodeLegacyEnvelope(
      preferences.getString(legacyPreferencesPrimaryKey),
    );
    final envelopeBackup = _decodeLegacyEnvelope(
      preferences.getString(legacyPreferencesBackupKey),
    );
    final legacySections = _readLegacySections(preferences);
    final hasLegacyData = legacySections.values.any((value) => value != null);

    if (envelopePrimary == null && envelopeBackup == null && !hasLegacyData) {
      return null;
    }

    FinancialSnapshot? chosen;
    var chosePrimary = false;
    if (envelopePrimary != null &&
        (envelopeBackup == null ||
            envelopePrimary.revision >= envelopeBackup.revision)) {
      chosen = envelopePrimary;
      chosePrimary = true;
    } else {
      chosen = envelopeBackup;
    }

    final sections = <String, dynamic>{
      if (chosen != null) ...chosen.sections,
    };

    // The old store mirrored the transaction list to its legacy key after
    // every envelope commit, so that mirror is at least as new as the backup
    // envelope. Prefer it whenever the primary envelope could not be used.
    final legacyTransactions = legacySections[FinancialSections.transactions];
    if (!chosePrimary && legacyTransactions is List) {
      sections[FinancialSections.transactions] = legacyTransactions;
    }

    // Fill anything the envelope does not carry from the legacy keys.
    legacySections.forEach((section, value) {
      if (value != null && !sections.containsKey(section)) {
        sections[section] = value;
      }
    });

    final migrated = FinancialSnapshot(
      schemaVersion: schemaVersion,
      revision: chosen?.revision ?? 0,
      sections: sections,
    );
    debugPrint(
      'Financial store: migrating revision ${migrated.revision} from '
      'SharedPreferences (${chosen == null ? 'legacy keys' : chosePrimary ? 'envelope' : 'envelope backup'})',
    );
    return migrated;
  }

  Future<void> _removeMigratedPreferenceKeys() async {
    final preferences = await SharedPreferences.getInstance();
    for (final key in migratedPreferenceKeys) {
      if (preferences.containsKey(key)) {
        await preferences.remove(key);
      }
    }
  }

  /// Decodes the pre-file envelope format: a JSON object carrying its own
  /// checksum over the re-encoded remainder.
  FinancialSnapshot? _decodeLegacyEnvelope(String? encoded) {
    if (encoded == null) return null;
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map<String, dynamic>) return null;
      final storedChecksum = decoded.remove('checksum');
      if (storedChecksum is! String) return null;
      if (_checksumBytes(utf8.encode(jsonEncode(decoded))) != storedChecksum) {
        return null;
      }
      final version = decoded['schemaVersion'];
      final revision = decoded['revision'];
      final sections = decoded['sections'];
      if (version is! int ||
          version > 1 ||
          revision is! int ||
          sections is! Map<String, dynamic>) {
        return null;
      }
      return FinancialSnapshot(
        schemaVersion: version,
        revision: revision,
        sections: Map<String, dynamic>.from(sections),
      );
    } catch (_) {
      return null;
    }
  }

  /// The per-feature keys from before the envelope existed. A null value
  /// means the key was absent or unreadable.
  Map<String, dynamic> _readLegacySections(SharedPreferences preferences) {
    dynamic decodeOrNull(String key) {
      final raw = preferences.getString(key);
      if (raw == null || raw.isEmpty) return null;
      try {
        return jsonDecode(raw);
      } catch (_) {
        return null;
      }
    }

    final hasAppSettings =
        preferences.containsKey(StorageKeys.baseCurrencyCode) ||
            preferences.containsKey(StorageKeys.localeOverride) ||
            preferences.containsKey(StorageKeys.appLockEnabled) ||
            preferences.containsKey(StorageKeys.autoLockTimeoutSeconds) ||
            preferences.containsKey(StorageKeys.hideBalances);

    return {
      FinancialSections.transactions: decodeOrNull(StorageKeys.transactions),
      FinancialSections.netWorthEntries:
          decodeOrNull(StorageKeys.netWorthEntries),
      FinancialSections.selectedNetWorthMonth:
          preferences.getString(StorageKeys.netWorthSelectedMonth),
      FinancialSections.categoryBudgetLimits:
          decodeOrNull(StorageKeys.categoryBudgetLimits),
      FinancialSections.savingsGoals: decodeOrNull(StorageKeys.savingsGoals),
      FinancialSections.recurringTransactions:
          decodeOrNull(StorageKeys.recurringTransactions),
      FinancialSections.categories: decodeOrNull(StorageKeys.categories),
      FinancialSections.transactionTags:
          decodeOrNull(StorageKeys.transactionTags),
      FinancialSections.categorizationRules:
          decodeOrNull(StorageKeys.categorizationRules),
      FinancialSections.appSettings: hasAppSettings
          ? <String, dynamic>{
              'baseCurrencyCode':
                  preferences.getString(StorageKeys.baseCurrencyCode) ?? 'USD',
              'localeOverride':
                  preferences.getString(StorageKeys.localeOverride),
              'appLockEnabled':
                  preferences.getBool(StorageKeys.appLockEnabled) ?? false,
              'autoLockTimeoutSeconds':
                  preferences.getInt(StorageKeys.autoLockTimeoutSeconds) ?? 60,
              'hideBalances':
                  preferences.getBool(StorageKeys.hideBalances) ?? false,
            }
          : null,
    };
  }

  // ---------------------------------------------------------------------------
  // Committing

  Future<void> _commit(FinancialSnapshot next) async {
    final backend = await _resolveBackend();
    final encoded = _encode(next);

    // 1. Preserve the current primary as the backup, but only when it is
    //    intact: a damaged primary must never replace a good backup.
    final currentBytes = await backend.readIfPresent(primaryFileName);
    if (currentBytes != null && _verifyBytes(currentBytes) != null) {
      await backend.writeAtomically(backupFileName, currentBytes);
    }

    // 2. Write the new primary to a staging path and rename it into place.
    await backend.writeAtomically(primaryFileName, encoded);

    // 3. Prove it from disk, not from anything cached in this process.
    await _verifyOnDisk(backend, next.revision);
  }

  Future<void> _verifyOnDisk(
      _StoreBackend backend, int expectedRevision) async {
    final written = await backend.readIfPresent(primaryFileName);
    final header = written == null ? null : _verifyBytes(written);
    if (header == null || header.revision != expectedRevision) {
      throw FinancialStoreException(
        'Financial snapshot verification failed '
        '(expected revision $expectedRevision, found ${header?.revision})',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Encoding
  //
  // File layout: one JSON header line, a newline, then the sections JSON.
  // The checksum covers the exact payload bytes, so verification never
  // depends on JSON re-encoding being byte-for-byte stable.

  Uint8List _encode(FinancialSnapshot snapshot) {
    final payload = utf8.encode(jsonEncode(snapshot.sections));
    final header = jsonEncode(<String, dynamic>{
      'format': _formatTag,
      'schemaVersion': snapshot.schemaVersion,
      'revision': snapshot.revision,
      'payloadLength': payload.length,
      'payloadChecksum': _checksumBytes(payload),
      'writtenAt': DateTime.now().toIso8601String(),
    });
    final builder = BytesBuilder(copy: false)
      ..add(utf8.encode(header))
      ..addByte(0x0A)
      ..add(payload);
    return builder.takeBytes();
  }

  /// Validates the header and payload checksum without decoding the payload.
  _FileHeader? _verifyBytes(Uint8List bytes) {
    final newline = bytes.indexOf(0x0A);
    if (newline <= 0) return null;
    try {
      final header = jsonDecode(utf8.decode(bytes.sublist(0, newline)));
      if (header is! Map<String, dynamic>) return null;
      final format = header['format'];
      final version = header['schemaVersion'];
      final revision = header['revision'];
      final length = header['payloadLength'];
      final checksum = header['payloadChecksum'];
      if (format != _formatTag ||
          version is! int ||
          version > schemaVersion ||
          revision is! int ||
          length is! int ||
          checksum is! String) {
        return null;
      }
      final payload = Uint8List.sublistView(bytes, newline + 1);
      if (payload.length != length) return null;
      if (_checksumBytes(payload) != checksum) return null;
      return _FileHeader(
        schemaVersion: version,
        revision: revision,
        payload: payload,
      );
    } catch (_) {
      return null;
    }
  }

  FinancialSnapshot? _decodeBytes(Uint8List bytes) {
    final header = _verifyBytes(bytes);
    if (header == null) return null;
    try {
      final sections = jsonDecode(utf8.decode(header.payload));
      if (sections is! Map<String, dynamic>) return null;
      return FinancialSnapshot(
        schemaVersion: header.schemaVersion,
        revision: header.revision,
        sections: sections,
      );
    } catch (_) {
      return null;
    }
  }

  /// FNV-1a detects accidental corruption. This is not a security primitive.
  String _checksumBytes(List<int> bytes) {
    var hash = 0xcbf29ce484222325;
    for (final byte in bytes) {
      hash ^= byte;
      hash = (hash * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }

  // ---------------------------------------------------------------------------
  // Location

  Future<_StoreBackend> _resolveBackend() async {
    final existing = _backend;
    if (existing != null) return existing;

    // The test runner has no path_provider, and under a widget test's fake
    // event loop a platform call would never even come back. Tests that need
    // real files pass a directory to [resetForTesting]; everything else runs
    // against memory. A real app never takes this branch.
    if (Platform.environment['FLUTTER_TEST'] == 'true') {
      return _backend = _MemoryBackend();
    }
    final base = await getApplicationSupportDirectory();
    final directory = Directory('${base.path}/$directoryName');
    return _backend = _DirectoryBackend(directory);
  }
}

/// The few file operations the store needs, so the same commit protocol runs
/// against real files in the app and against memory in widget tests.
abstract class _StoreBackend {
  /// Returns the file's bytes, or null only when it does not exist. Any other
  /// failure (a directory in its place, permissions, protected data
  /// unavailable, I/O) is a [FinancialStoreException]: a read error must
  /// never be mistaken for an empty store.
  Future<Uint8List?> readIfPresent(String name);

  /// Writes [bytes] so that [name] is either fully replaced or untouched.
  Future<void> writeAtomically(String name, Uint8List bytes);

  /// Renames [name] out of the way, keeping its contents for forensics.
  Future<void> setAside(String name, String suffix);
}

class _DirectoryBackend implements _StoreBackend {
  final Directory directory;

  _DirectoryBackend(this.directory);

  String _path(String name) => '${directory.path}/$name';

  @override
  Future<Uint8List?> readIfPresent(String name) async {
    final path = _path(name);
    try {
      final type = await FileSystemEntity.type(path);
      if (type == FileSystemEntityType.notFound) return null;
      return await File(path).readAsBytes();
    } on FileSystemException catch (error) {
      throw FinancialStoreException('Could not read $path', error);
    }
  }

  @override
  Future<void> writeAtomically(String name, Uint8List bytes) async {
    final path = _path(name);
    try {
      await directory.create(recursive: true);
      final staged = File('$path.tmp');
      await staged.writeAsBytes(bytes, flush: true);
      // rename(2) replaces the target atomically.
      await staged.rename(path);
    } on FileSystemException catch (error) {
      throw FinancialStoreException('Could not write $path', error);
    }
  }

  @override
  Future<void> setAside(String name, String suffix) async {
    final path = _path(name);
    try {
      await File(path).rename('$path$suffix');
    } on FileSystemException catch (error) {
      throw FinancialStoreException('Could not set aside $path', error);
    }
  }
}

class _MemoryBackend implements _StoreBackend {
  final Map<String, Uint8List> _files = {};

  @override
  Future<Uint8List?> readIfPresent(String name) async => _files[name];

  @override
  Future<void> writeAtomically(String name, Uint8List bytes) async {
    _files[name] = Uint8List.fromList(bytes);
  }

  @override
  Future<void> setAside(String name, String suffix) async {
    final bytes = _files.remove(name);
    if (bytes != null) _files['$name$suffix'] = bytes;
  }
}

class _FileHeader {
  final int schemaVersion;
  final int revision;
  final Uint8List payload;

  const _FileHeader({
    required this.schemaVersion,
    required this.revision,
    required this.payload,
  });
}
