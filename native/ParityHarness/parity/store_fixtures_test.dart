// Emits native/Fixtures/store/<scenario>/ :
//   input/            on-disk state before launch (financial_store/ files)
//   prefs.json        SharedPreferences state before launch (typed, flutter.*)
//   expected.json     what the Dart store and app do with that input
//
// Every file under input/ was written by the real AtomicFinancialStore via
// the real models (or derived from such a file by the stated mutation).

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:budget_app/storage/atomic_financial_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'harness_support.dart';
import 'fixture_runner.dart';
import 'store_scenarios.dart';

Uint8List readBytes(Directory dir, String name) =>
    File('${dir.path}/$name').readAsBytesSync();

/// Re-encodes a valid store file with a modified header (valid checksum).
Uint8List withHeader(Uint8List bytes, Map<String, Object?> Function(Map<String, Object?>) edit) {
  final newline = bytes.indexOf(0x0A);
  final header = Map<String, Object?>.from(
      jsonDecode(utf8.decode(bytes.sublist(0, newline))) as Map);
  return Uint8List.fromList([
    ...utf8.encode(jsonEncode(edit(header))),
    0x0A,
    ...bytes.sublist(newline + 1),
  ]);
}

/// A syntactically valid store file around arbitrary payload bytes.
Uint8List fileWithPayload(List<int> payload, {int revision = 7}) {
  final header = jsonEncode({
    'format': 'budgie-financial-store',
    'schemaVersion': 2,
    'revision': revision,
    'payloadLength': payload.length,
    'payloadChecksum': fnv(payload),
    'writtenAt': '2026-09-01T00:00:00.000',
  });
  return Uint8List.fromList([...utf8.encode(header), 0x0A, ...payload]);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory typical;

  setUpAll(() async {
    final work = await scratch('typical');
    typical = Directory('${work.path}/financial_store');
    SharedPreferences.setMockInitialValues({});
    seedUuids(1);
    await store.resetForTesting(directory: typical);
    await buildTypicalStore(AppHarness());
    await store.resetForTesting();
  });

  setUp(() => seedUuids(2));

  Directory variant(String name, void Function(Directory dir) mutate) {
    final dir = Directory('${Directory.systemTemp.path}/parity_variant_$name');
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    copyDir(typical, dir);
    mutate(dir);
    return dir;
  }

  test('fresh install', () async {
    final none = Directory('${Directory.systemTemp.path}/parity_none');
    if (none.existsSync()) none.deleteSync(recursive: true);
    emit('fresh_install', none, {}, await expectFor(none, {}),
        description: 'No files, no preferences.');
  });

  test('typical', () async {
    emit('typical', typical, {}, await expectFor(typical, {}),
        description: 'Sixteen months driven through the real models; every '
            'section, every enum, awkward strings and numbers, edits, deletes, '
            'recurring generation, net worth carry-forward.');
  });

  test('large 10k', () async {
    final work = await scratch('large');
    final dir = Directory('${work.path}/financial_store');
    copyDir(typical, dir);
    SharedPreferences.setMockInitialValues({});
    await store.resetForTesting(directory: dir);
    final app = AppHarness();
    pinClock(DateTime(2026, 9, 1, 12));
    await app.initialize(generate: false);
    final model = app.transactionModel;
    final categories = ['Groceries', 'Eating Out', 'Housing', 'Travel', 'Pet Food'];
    for (var i = 0; i < 10000; i++) {
      final day = DateTime(2020, 1, 1).add(Duration(hours: 7 * i + (i % 5)));
      model.transactions.add(model.transactions.first.copyWith(
        id: 'bulk-$i',
        description: 'Bulk row $i ${i % 7 == 0 ? 'ü' : ''}',
        amount: (i % 997) * 1.01 + 0.01,
        category: categories[i % categories.length],
        date: day,
        createdAt: DateTime(2026, 9, 1, 12).add(Duration(microseconds: i)),
        updatedAt: DateTime(2026, 9, 1, 12).add(Duration(microseconds: i)),
        tagIds: const [],
      ));
    }
    expect(await model.saveTransactions(model.transactions), isTrue);
    await store.resetForTesting();
    emit('large_10k', dir, {}, await expectFor(dir, {}),
        description: 'Typical plus 10,000 transactions saved in one commit.');
  });

  test('old schema rows', () async {
    final work = await scratch('old');
    final dir = Directory('${work.path}/financial_store');
    SharedPreferences.setMockInitialValues({});
    await store.resetForTesting(directory: dir);
    pinClock(DateTime(2025, 3, 6, 8));
    await store.replace(FinancialSnapshot(
        schemaVersion: 2, revision: 0, sections: oldSchemaSections()));
    await store.resetForTesting();
    emit('old_schema', dir, {}, await expectFor(dir, {}),
        description: 'Rows missing ids/timestamps/tagIds, duplicate and blank '
            'ids, legacy monthKey snapshots, template without isActive, '
            'lenient savings goal, non-positive budget limits, sparse '
            'categories. Written through the real store.');
  });

  test('unknown future data', () async {
    final work = await scratch('unknown');
    final dir = Directory('${work.path}/financial_store');
    copyDir(typical, dir);
    SharedPreferences.setMockInitialValues({});
    await store.resetForTesting(directory: dir);
    final base = await store.read();
    pinClock(DateTime(2026, 9, 21, 7));
    await store.replace(FinancialSnapshot(
        schemaVersion: 2,
        revision: 0,
        sections: unknownDataSections(base.sections)));
    await store.resetForTesting();
    emit('unknown_data', dir, {}, await expectFor(dir, {}),
        description: 'Typical plus an unknown section, unknown keys in a '
            'transaction row, and an unknown appSettings key.');
  });

  // ---- Damaged files (all derived from the typical store) ----

  final damaged = <String, (String, void Function(Directory))>{
    'primary_truncated': ('Primary cut to half its length.', (d) {
      final b = readBytes(d, primaryName);
      File('${d.path}/$primaryName').writeAsBytesSync(b.sublist(0, b.length ~/ 2));
    }),
    'primary_bitflip': ('One payload byte of the primary changed.', (d) {
      final b = readBytes(d, primaryName);
      b[b.length - 10] ^= 0x01;
      File('${d.path}/$primaryName').writeAsBytesSync(b);
    }),
    'primary_empty': ('Primary is a zero-length file.', (d) {
      File('${d.path}/$primaryName').writeAsBytesSync([]);
    }),
    'primary_no_newline': ('Primary header with no newline separator.', (d) {
      final b = readBytes(d, primaryName);
      File('${d.path}/$primaryName')
          .writeAsBytesSync(b.where((x) => x != 0x0A).toList());
    }),
    'primary_schema3': ('Primary header claims schemaVersion 3.', (d) {
      File('${d.path}/$primaryName').writeAsBytesSync(
          withHeader(readBytes(d, primaryName), (h) => {...h, 'schemaVersion': 3}));
    }),
    'primary_revision_double': ('Primary header revision written as a double.', (d) {
      File('${d.path}/$primaryName').writeAsBytesSync(withHeader(
          readBytes(d, primaryName),
          (h) => {...h, 'revision': (h['revision'] as int).toDouble()}));
    }),
    'primary_wrong_format_tag': ('Primary header has another format tag.', (d) {
      File('${d.path}/$primaryName').writeAsBytesSync(withHeader(
          readBytes(d, primaryName), (h) => {...h, 'format': 'something-else'}));
    }),
    'primary_length_mismatch': ('Primary payloadLength off by one.', (d) {
      File('${d.path}/$primaryName').writeAsBytesSync(withHeader(
          readBytes(d, primaryName),
          (h) => {...h, 'payloadLength': (h['payloadLength'] as int) + 1}));
    }),
    'primary_invalid_utf8': (
      'Primary payload is invalid UTF-8 with a correct checksum.',
      (d) {
        File('${d.path}/$primaryName')
            .writeAsBytesSync(fileWithPayload([0x7B, 0xFF, 0xFE, 0x7D], revision: 999));
      }
    ),
    'primary_payload_not_object': (
      'Primary payload is a JSON array with a correct checksum.',
      (d) {
        File('${d.path}/$primaryName')
            .writeAsBytesSync(fileWithPayload(utf8.encode('[]'), revision: 999));
      }
    ),
    'primary_missing': ('Only the backup exists.', (d) {
      File('${d.path}/$primaryName').deleteSync();
    }),
    'primary_stale': ('Primary and backup swapped: primary is older.', (d) {
      final p = readBytes(d, primaryName);
      final b = readBytes(d, backupName);
      File('${d.path}/$primaryName').writeAsBytesSync(b);
      File('${d.path}/$backupName').writeAsBytesSync(p);
    }),
    'backup_corrupt': ('Backup bit-flipped, primary fine.', (d) {
      final b = readBytes(d, backupName);
      b[b.length - 3] ^= 0x20;
      File('${d.path}/$backupName').writeAsBytesSync(b);
    }),
    'backup_missing': ('Only the primary exists.', (d) {
      File('${d.path}/$backupName').deleteSync();
    }),
    'both_corrupt': ('Both files damaged, no legacy preferences.', (d) {
      for (final name in [primaryName, backupName]) {
        final b = readBytes(d, name);
        File('${d.path}/$name').writeAsBytesSync(b.sublist(0, b.length - 1));
      }
    }),
    'tmp_leftover_garbage': ('Garbage .tmp files next to good files.', (d) {
      File('${d.path}/$primaryName.tmp').writeAsStringSync('{"partial');
      File('${d.path}/$backupName.tmp').writeAsBytesSync([0, 1, 2]);
    }),
    'tmp_leftover_valid_newer': (
      'A valid, newer primary sits in .tmp (crash before rename).',
      (d) {
        File('${d.path}/$primaryName.tmp').writeAsBytesSync(withHeader(
            readBytes(d, primaryName),
            (h) => {...h, 'revision': (h['revision'] as int) + 1}));
      }
    ),
    'corrupt_leftovers': ('Old .corrupt-<ms> files from a previous recovery.', (d) {
      File('${d.path}/$primaryName.corrupt-1700000000000')
          .writeAsStringSync('old junk');
    }),
  };

  for (final entry in damaged.entries) {
    test('damaged: ${entry.key}', () async {
      final dir = variant(entry.key, entry.value.$2);
      emit(entry.key, dir, {}, await expectFor(dir, {}),
          description: entry.value.$1);
    });
  }

  test('damaged: both corrupt with legacy preferences', () async {
    final dir = variant('both_corrupt_legacy', damaged['both_corrupt']!.$2);
    final prefs = <String, Object>{
      'transactions': jsonEncode([
        {
          'id': 'legacy-1',
          'type': 'expense',
          'description': 'From prefs',
          'amount': 9.99,
          'category': 'General',
          'date': '2024-05-05T00:00:00.000',
        }
      ]),
      'base_currency_code': 'GBP',
    };
    emit('both_corrupt_with_legacy', dir, prefs, await expectFor(dir, prefs),
        description: 'Both files damaged; bare legacy keys present.');
  });

  test('damaged: primary path is a directory', () async {
    final dir = variant('primary_is_dir', (d) {
      File('${d.path}/$primaryName').deleteSync();
      Directory('${d.path}/$primaryName').createSync();
    });
    emit('primary_is_directory', dir, {},
        await expectFor(dir, {}, runApp: false),
        description: 'A directory where the primary should be: a read error, '
            'never an empty store.');
  });
}
