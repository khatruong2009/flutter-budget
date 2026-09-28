// Loads every store the Swift side wrote through the real Dart store and
// models, and fails loudly on anything the Flutter app would reject, drop,
// or silently reset. This is the proof that the Flutter build can be
// reinstalled over the Swift app.
//
// Layout of $SWIFT_OUT/<case>/:
//   financial_store/   files written by BudgieCore
//   prefs.json         typed preferences (optional)
//   swift.json         {"revision": int, "sectionsFnv": "<fnv of Dart-canonical sections>"}
//
// Writes $SWIFT_OUT/dart-verification.json and fails if any case failed.

import 'dart:convert';
import 'dart:io';

import 'package:budget_app/storage/atomic_financial_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixture_runner.dart';
import 'harness_support.dart';
import 'model_summary.dart';

Map<String, Object> prefsFrom(File file) {
  if (!file.existsSync()) return {};
  final typed = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final out = <String, Object>{};
  typed.forEach((key, value) {
    final entry = value as Map<String, dynamic>;
    final raw = entry['value'];
    out[key] = switch (entry['type']) {
      'bool' => raw as bool,
      'int' => raw as int,
      'double' => (raw as num).toDouble(),
      'string' => raw as String,
      'stringList' => List<String>.from(raw as List),
      _ => throw ArgumentError('bad pref type ${entry['type']}'),
    };
  });
  return out;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final root = Directory(Platform.environment['SWIFT_OUT'] ??
      (throw StateError('SWIFT_OUT not set')));
  final cases = root.existsSync()
      ? (root.listSync().whereType<Directory>().toList()
        ..sort((a, b) => a.path.compareTo(b.path)))
      : <Directory>[];
  final report = <String, Object?>{};

  tearDownAll(() {
    writeJson('${root.path}/dart-verification.json', {
      'commit': parityCommit,
      'tz': parityTz,
      'cases': report,
    });
  });

  test('there is something to verify', () {
    expect(cases, isNotEmpty, reason: 'no Swift output under ${root.path}');
  });

  for (final dir in cases) {
    final name = dir.uri.pathSegments.where((s) => s.isNotEmpty).last;
    test(name, () async {
      final problems = <String>[];
      final swift = jsonDecode(File('${dir.path}/swift.json').readAsStringSync())
          as Map<String, dynamic>;
      final prefs = prefsFrom(File('${dir.path}/prefs.json'));

      // Work on a copy: loading may legitimately write (restore, migration).
      final work = await Directory.systemTemp.createTemp('verify_$name');
      final storeDir = Directory('${work.path}/financial_store');
      copyDir(Directory('${dir.path}/financial_store'), storeDir);

      SharedPreferences.setMockInitialValues(Map.of(prefs));
      pinClock(launchNow);
      await AtomicFinancialStore.instance.resetForTesting(directory: storeDir);
      final snapshot = await AtomicFinancialStore.instance.read();
      if (snapshot.revision != swift['revision']) {
        problems.add('revision: dart ${snapshot.revision} swift ${swift['revision']}');
      }
      final canonical = sectionsJson(snapshot);
      if (canonical['fnv'] != swift['sectionsFnv']) {
        problems.add('sections differ: dart ${canonical['fnv']} swift ${swift['sectionsFnv']}');
      }
      final filesBefore = listing(storeDir);

      // Full app load, as a reinstalled Flutter build would do it.
      final app = AppHarness();
      Map<String, Object?>? summary;
      try {
        await app.initialize(generate: false);
        summary = summarize(app, asOf: launchNow);
      } catch (error) {
        problems.add('app load threw ${error.runtimeType}: $error');
      }

      int rawCount(String section) {
        final value = snapshot.sections[section];
        return value is List ? value.length : 0;
      }

      if (summary != null) {
        // Rows the models skip or reset silently count as data loss.
        final txRaw = rawCount('transactions');
        if (app.transactionModel.transactions.length != txRaw) {
          problems.add('transactions: raw $txRaw loaded ${app.transactionModel.transactions.length}');
        }
        final rtRaw = rawCount('recurringTransactions');
        if (app.recurringModel.recurringTransactions.length != rtRaw) {
          problems.add('recurring: raw $rtRaw loaded ${app.recurringModel.recurringTransactions.length}');
        }
        final nwRaw = rawCount('netWorthEntries');
        if (nwRaw > 0 && app.transactionModel.netWorthEntries.length != nwRaw) {
          problems.add('net worth: raw $nwRaw loaded ${app.transactionModel.netWorthEntries.length}');
        }
        final goalsRaw = rawCount('savingsGoals');
        if (app.transactionModel.savingsGoals.length != goalsRaw) {
          problems.add('goals: raw $goalsRaw loaded ${app.transactionModel.savingsGoals.length}');
        }
        final tagsRaw = rawCount('transactionTags');
        if (app.categorizationProvider.tags.length != tagsRaw) {
          problems.add('tags: raw $tagsRaw loaded ${app.categorizationProvider.tags.length}');
        }
        final rulesRaw = rawCount('categorizationRules');
        if (app.categorizationProvider.rules.length != rulesRaw) {
          problems.add('rules: raw $rulesRaw loaded ${app.categorizationProvider.rules.length}');
        }
        final catRaw = rawCount('categories');
        if (catRaw > 0 && app.categoryProvider.categories.length < catRaw) {
          problems.add('categories: raw $catRaw loaded ${app.categoryProvider.categories.length}');
        }
        if (app.transactionModel.hasUnsavedChanges ||
            app.recurringModel.hasUnsavedChanges) {
          problems.add('a model reports unsaved changes after load');
        }
      }

      report[name] = {
        'problems': problems,
        'revision': snapshot.revision,
        'sections': canonical..remove('json'),
        'filesBeforeApp': filesBefore,
        if (summary != null) 'summary': summary,
      };
      expect(problems, isEmpty, reason: problems.join('\n'));
    });
  }
}
