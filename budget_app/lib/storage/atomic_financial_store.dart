import 'dart:convert';

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

  FinancialSnapshot copyWithSections(Map<String, dynamic> updates) {
    return FinancialSnapshot(
      schemaVersion: schemaVersion,
      revision: revision + 1,
      sections: Map<String, dynamic>.from(sections)..addAll(updates),
    );
  }
}

/// Stores financial state as one checksummed envelope with a last-known-good
/// backup. Every multi-section update is committed as a single preference
/// write, avoiding partial restores across the old per-feature keys.
///
/// Calls are serialized in-process. On platforms where SharedPreferences uses
/// an atomic file replacement, readers observe either the previous or next
/// complete envelope.
class AtomicFinancialStore {
  static const int schemaVersion = 1;
  static const String _primaryKey = 'financial_store_v1';
  static const String _backupKey = 'financial_store_v1_backup';

  static final AtomicFinancialStore instance = AtomicFinancialStore._();

  AtomicFinancialStore._();

  Future<void> _writeQueue = Future<void>.value();

  Future<FinancialSnapshot> read() async {
    final preferences = await SharedPreferences.getInstance();
    final primary = preferences.getString(_primaryKey);
    if (primary != null) {
      final decoded = _decode(primary);
      if (decoded != null) return decoded;
    }

    final backup = preferences.getString(_backupKey);
    if (backup != null) {
      final decoded = _decode(backup);
      if (decoded != null) {
        await preferences.setString(_primaryKey, backup);
        return decoded;
      }
    }

    final migrated = _readLegacy(preferences);
    await _commit(preferences, migrated);
    return migrated;
  }

  Future<void> updateSection(String section, dynamic value) {
    return updateSections({section: value});
  }

  Future<void> updateSections(Map<String, dynamic> updates) {
    return _enqueue(() async {
      final preferences = await SharedPreferences.getInstance();
      final current = await read();
      await _commit(preferences, current.copyWithSections(updates));
    });
  }

  Future<void> replace(FinancialSnapshot snapshot) {
    return _enqueue(() async {
      final preferences = await SharedPreferences.getInstance();
      final replacement = FinancialSnapshot(
        schemaVersion: schemaVersion,
        revision: snapshot.revision + 1,
        sections: Map<String, dynamic>.from(snapshot.sections),
      );
      await _commit(preferences, replacement);
    });
  }

  Future<void> _enqueue(Future<void> Function() operation) {
    final result = _writeQueue.then((_) => operation());
    _writeQueue = result.then<void>(
      (_) {},
      onError: (_, __) {},
    );
    return result;
  }

  Future<void> _commit(
    SharedPreferences preferences,
    FinancialSnapshot next,
  ) async {
    final current = preferences.getString(_primaryKey);
    if (current != null && _decode(current) != null) {
      final backupSaved = await preferences.setString(_backupKey, current);
      if (!backupSaved) {
        throw StateError('Could not preserve the previous financial snapshot');
      }
    }

    final encoded = _encode(next);
    final saved = await preferences.setString(_primaryKey, encoded);
    if (!saved) {
      throw StateError('Could not commit the financial snapshot');
    }

    final verified = _decode(preferences.getString(_primaryKey) ?? '');
    if (verified == null || verified.revision != next.revision) {
      throw const FormatException('Financial snapshot verification failed');
    }
  }

  FinancialSnapshot _readLegacy(SharedPreferences preferences) {
    dynamic decodeOr(String key, dynamic fallback) {
      final raw = preferences.getString(key);
      if (raw == null || raw.isEmpty) return fallback;
      try {
        return jsonDecode(raw);
      } catch (_) {
        return fallback;
      }
    }

    return FinancialSnapshot(
      schemaVersion: schemaVersion,
      revision: 0,
      sections: {
        FinancialSections.transactions:
            decodeOr(StorageKeys.transactions, <dynamic>[]),
        FinancialSections.netWorthEntries:
            decodeOr(StorageKeys.netWorthEntries, <dynamic>[]),
        FinancialSections.selectedNetWorthMonth:
            preferences.getString(StorageKeys.netWorthSelectedMonth),
        FinancialSections.categoryBudgetLimits:
            decodeOr(StorageKeys.categoryBudgetLimits, <String, dynamic>{}),
        FinancialSections.savingsGoals:
            decodeOr(StorageKeys.savingsGoals, <dynamic>[]),
        FinancialSections.recurringTransactions:
            decodeOr(StorageKeys.recurringTransactions, <dynamic>[]),
        FinancialSections.categories:
            decodeOr(StorageKeys.categories, <dynamic>[]),
        FinancialSections.transactionTags:
            decodeOr(StorageKeys.transactionTags, <dynamic>[]),
        FinancialSections.categorizationRules:
            decodeOr(StorageKeys.categorizationRules, <dynamic>[]),
        FinancialSections.appSettings: <String, dynamic>{
          'baseCurrencyCode':
              preferences.getString(StorageKeys.baseCurrencyCode) ?? 'USD',
          'localeOverride': preferences.getString(StorageKeys.localeOverride),
          'appLockEnabled':
              preferences.getBool(StorageKeys.appLockEnabled) ?? false,
          'autoLockTimeoutSeconds':
              preferences.getInt(StorageKeys.autoLockTimeoutSeconds) ?? 60,
          'hideBalances':
              preferences.getBool(StorageKeys.hideBalances) ?? false,
        },
      },
    );
  }

  String _encode(FinancialSnapshot snapshot) {
    final payload = <String, dynamic>{
      'schemaVersion': snapshot.schemaVersion,
      'revision': snapshot.revision,
      'sections': snapshot.sections,
    };
    final canonicalPayload = jsonEncode(payload);
    return jsonEncode({
      ...payload,
      'checksum': _checksum(canonicalPayload),
    });
  }

  FinancialSnapshot? _decode(String encoded) {
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map<String, dynamic>) return null;
      final storedChecksum = decoded.remove('checksum');
      if (storedChecksum is! String) return null;
      if (_checksum(jsonEncode(decoded)) != storedChecksum) return null;

      final version = decoded['schemaVersion'];
      final revision = decoded['revision'];
      final sections = decoded['sections'];
      if (version is! int ||
          version > schemaVersion ||
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

  /// FNV-1a detects accidental corruption. This is not a security primitive.
  String _checksum(String value) {
    var hash = 0xcbf29ce484222325;
    for (final byte in utf8.encode(value)) {
      hash ^= byte;
      hash = (hash * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }
}
