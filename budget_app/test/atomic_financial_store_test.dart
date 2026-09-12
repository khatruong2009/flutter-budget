import 'dart:convert';
import 'dart:io';

import 'package:budget_app/storage/atomic_financial_store.dart';
import 'package:budget_app/storage/storage_keys.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Builds an envelope in the format the previous SharedPreferences-backed
/// store wrote, so migration can be exercised against real bytes.
String legacyEnvelope({
  required int revision,
  required Map<String, dynamic> sections,
}) {
  final payload = <String, dynamic>{
    'schemaVersion': 1,
    'revision': revision,
    'sections': sections,
  };
  return jsonEncode({
    ...payload,
    'checksum': _fnv1a(utf8.encode(jsonEncode(payload))),
  });
}

String _fnv1a(List<int> bytes) {
  var hash = 0xcbf29ce484222325;
  for (final byte in bytes) {
    hash ^= byte;
    hash = (hash * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
  }
  return hash.toRadixString(16).padLeft(16, '0');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;
  late File primary;
  late File backup;
  final store = AtomicFinancialStore.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    directory = await Directory.systemTemp.createTemp('budgie_store_test');
    await store.resetForTesting(directory: directory);
    primary = File('${directory.path}/${AtomicFinancialStore.primaryFileName}');
    backup = File('${directory.path}/${AtomicFinancialStore.backupFileName}');
  });

  tearDown(() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  /// Simulates a process restart: memory is gone, only files remain.
  Future<void> relaunch() => store.resetForTesting(directory: directory);

  List<dynamic> transactionsOf(FinancialSnapshot snapshot) =>
      snapshot.sections[FinancialSections.transactions] as List<dynamic>;

  test('a fresh install reads empty and writes nothing', () async {
    final snapshot = await store.read();

    expect(snapshot.revision, 0);
    expect(snapshot.sections, isEmpty);
    expect(await primary.exists(), isFalse);
    expect(await backup.exists(), isFalse);
  });

  test('commits survive a relaunch and each one keeps the previous as backup',
      () async {
    await store.updateSection(FinancialSections.transactions, [
      {'description': 'Rent'}
    ]);
    await store.updateSections({
      FinancialSections.transactions: [
        {'description': 'Rent'},
        {'description': 'Coffee'}
      ],
      FinancialSections.savingsGoals: [
        {'name': 'Emergency fund'}
      ],
    });

    await relaunch();
    final reloaded = await store.read();

    expect(reloaded.revision, 2);
    expect(transactionsOf(reloaded), hasLength(2));
    expect(
      (reloaded.sections[FinancialSections.savingsGoals] as List).single,
      {'name': 'Emergency fund'},
    );
    expect(await backup.exists(), isTrue);
  });

  test('verification reads the file back from disk, not from memory', () async {
    await store.updateSection(FinancialSections.transactions, [
      {'description': 'Rent'}
    ]);
    // Make the directory unwritable so the next commit cannot land.
    await primary.delete();
    await directory.delete(recursive: true);
    await File(directory.path).writeAsString('not a directory');

    await expectLater(
      store.updateSection(FinancialSections.transactions, [
        {'description': 'Lost'}
      ]),
      throwsA(isA<FinancialStoreException>()),
    );

    await File(directory.path).delete();
  });

  test('a corrupt primary is recovered from the backup on load', () async {
    await store.updateSection(FinancialSections.transactions, [
      {'description': 'Last known good'}
    ]);
    await store.updateSection(FinancialSections.transactions, [
      {'description': 'Last known good'},
      {'description': 'Newest'}
    ]);
    await primary.writeAsString('garbage');

    await relaunch();
    final recovered = await store.read();

    expect(
        transactionsOf(recovered).single, {'description': 'Last known good'});
    // The primary is rebuilt from the backup so the next load is clean.
    await relaunch();
    expect(transactionsOf(await store.read()).single,
        {'description': 'Last known good'});
  });

  test('a corrupt primary never overwrites a good backup', () async {
    await store.updateSection(FinancialSections.transactions, [
      {'description': 'Good'}
    ]);
    await store.updateSection(FinancialSections.transactions, [
      {'description': 'Good'},
      {'description': 'Also good'}
    ]);
    await primary.writeAsString('garbage');
    // Load recovers revision 1 from the backup and continues from there.
    await relaunch();
    await store.read();

    await store.updateSection(FinancialSections.transactions, [
      {'description': 'Good'},
      {'description': 'After recovery'}
    ]);

    await relaunch();
    final latest = await store.read();
    expect(transactionsOf(latest).last, {'description': 'After recovery'});
    await relaunch();
    await primary.writeAsString('garbage again');
    final fallback = await store.read();
    expect(transactionsOf(fallback).single, {'description': 'Good'});
  });

  test('the newest readable revision wins between primary and backup',
      () async {
    await store.updateSection(FinancialSections.transactions, [
      {'description': 'One'}
    ]);
    await store.updateSection(FinancialSections.transactions, [
      {'description': 'One'},
      {'description': 'Two'}
    ]);
    // Swap the files: an older primary next to a newer backup.
    final primaryBytes = await primary.readAsBytes();
    final backupBytes = await backup.readAsBytes();
    await primary.writeAsBytes(backupBytes);
    await backup.writeAsBytes(primaryBytes);

    await relaunch();
    final loaded = await store.read();

    expect(loaded.revision, 2);
    expect(transactionsOf(loaded), hasLength(2));
  });

  test('a store that cannot be read is an error, never an empty ledger',
      () async {
    await store.updateSection(FinancialSections.transactions, [
      {'description': 'Rent'}
    ]);
    // Replace the primary with a directory: exists() is true, reading throws.
    await primary.delete();
    await Directory(primary.path).create();

    await relaunch();
    await expectLater(store.read(), throwsA(isA<FinancialStoreException>()));
    expect(store.isLoaded, isFalse);
  });

  group('migration from SharedPreferences', () {
    test('imports the previous envelope and clears the bulky keys', () async {
      SharedPreferences.setMockInitialValues({
        AtomicFinancialStore.legacyPreferencesPrimaryKey: legacyEnvelope(
          revision: 7,
          sections: {
            FinancialSections.transactions: [
              {'description': 'From envelope'}
            ],
            FinancialSections.categoryBudgetLimits: {'Eating Out': 100},
          },
        ),
        StorageKeys.transactions: jsonEncode([
          {'description': 'From envelope'}
        ]),
        StorageKeys.baseCurrencyCode: 'EUR',
      });

      final migrated = await store.read();

      expect(migrated.revision, 7);
      expect(transactionsOf(migrated).single, {'description': 'From envelope'});
      expect(
        migrated.sections[FinancialSections.categoryBudgetLimits],
        {'Eating Out': 100},
      );
      expect(
        (migrated.sections[FinancialSections.appSettings]
            as Map)['baseCurrencyCode'],
        'EUR',
      );
      expect(await primary.exists(), isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AtomicFinancialStore.legacyPreferencesPrimaryKey),
          isNull);
      expect(prefs.getString(StorageKeys.transactions), isNull);
      // Real preferences stay where they are.
      expect(prefs.getString(StorageKeys.baseCurrencyCode), 'EUR');

      await relaunch();
      expect(transactionsOf(await store.read()).single,
          {'description': 'From envelope'});
    });

    test('imports the legacy per-feature keys when no envelope exists',
        () async {
      SharedPreferences.setMockInitialValues({
        StorageKeys.transactions: jsonEncode([
          {'description': 'Coffee'}
        ]),
        StorageKeys.recurringTransactions: jsonEncode([
          {'description': 'Rent'}
        ]),
      });

      final migrated = await store.read();

      expect(transactionsOf(migrated).single, {'description': 'Coffee'});
      expect(
        (migrated.sections[FinancialSections.recurringTransactions] as List)
            .single,
        {'description': 'Rent'},
      );
      expect(migrated.sections.containsKey(FinancialSections.savingsGoals),
          isFalse);
    });

    test(
        'a malformed envelope falls back to its backup plus the newer '
        'transaction mirror', () async {
      SharedPreferences.setMockInitialValues({
        AtomicFinancialStore.legacyPreferencesPrimaryKey: '{"corrupt":true}',
        AtomicFinancialStore.legacyPreferencesBackupKey: legacyEnvelope(
          revision: 3,
          sections: {
            FinancialSections.transactions: [
              {'id': 'old'}
            ],
            FinancialSections.savingsGoals: [
              {'name': 'Kept from backup'}
            ],
          },
        ),
        // The old store wrote this mirror after every envelope commit, so it
        // carries the row the corrupt primary would have held.
        StorageKeys.transactions: jsonEncode([
          {'id': 'old'},
          {'id': 'newest'}
        ]),
      });

      final migrated = await store.read();

      expect(migrated.revision, 3);
      expect(transactionsOf(migrated).map((row) => row['id']),
          orderedEquals(['old', 'newest']));
      expect(
        (migrated.sections[FinancialSections.savingsGoals] as List).single,
        {'name': 'Kept from backup'},
      );
    });

    test('does not touch preferences when there is nothing to migrate',
        () async {
      SharedPreferences.setMockInitialValues({
        StorageKeys.onboardingCompleted: true,
      });

      await store.read();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(StorageKeys.onboardingCompleted), isTrue);
      expect(await primary.exists(), isFalse);
    });
  });
}
