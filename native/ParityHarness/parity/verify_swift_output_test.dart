// Loads every store the Swift side wrote through the real Dart store and
// models, and fails loudly on anything the Flutter app would reject, drop,
// or silently reset. This is the proof that the Flutter build can be
// reinstalled over the Swift app.
//
// Layout of $SWIFT_OUT/<case>/:
//   financial_store/   files written by BudgieCore
//   prefs.json         typed preferences (optional)
//   swift.json         {"revision": int, "sectionsFnv": "<fnv of Dart-canonical sections>",
//                       optional "categoryBudgetLimits", "netWorthEntries",
//                       "selectedNetWorthMonth", "savingsGoals", "appSettings",
//                       "themeMode", "categories", "categoriesAddedAtLaunch",
//                       "transactionCategories", "templateCategories",
//                       "ruleCategories": what the Dart models must hold}
//
// Writes $SWIFT_OUT/dart-verification.json and fails if any case failed.

import 'dart:convert';
import 'dart:io';

import 'package:budget_app/storage/atomic_financial_store.dart';
import 'package:budget_app/theme_provider.dart';
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
      // swift.json is optional: files pulled from a simulator have no
      // Swift-side expectation, only the load checks below.
      final swiftFile = File('${dir.path}/swift.json');
      final swift = swiftFile.existsSync()
          ? jsonDecode(swiftFile.readAsStringSync()) as Map<String, dynamic>
          : <String, dynamic>{};
      final prefs = prefsFrom(File('${dir.path}/prefs.json'));

      // Work on a copy: loading may legitimately write (restore, migration).
      final work = await Directory.systemTemp.createTemp('verify_$name');
      final storeDir = Directory('${work.path}/financial_store');
      copyDir(Directory('${dir.path}/financial_store'), storeDir);

      SharedPreferences.setMockInitialValues(Map.of(prefs));
      pinClock(launchNow);
      await AtomicFinancialStore.instance.resetForTesting(directory: storeDir);
      final snapshot = await AtomicFinancialStore.instance.read();
      if (swift.isNotEmpty && snapshot.revision != swift['revision']) {
        problems.add('revision: dart ${snapshot.revision} swift ${swift['revision']}');
      }
      final canonical = sectionsJson(snapshot);
      if (swift.isNotEmpty && canonical['fnv'] != swift['sectionsFnv']) {
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
        // Budget limits the Swift side wrote: Dart must hold exactly these,
        // in this order (values compared as Dart's toString).
        final budgetLimits = swift['categoryBudgetLimits'];
        if (budgetLimits is List) {
          final dart = jsonEncode([
            for (final e in app.transactionModel.categoryBudgetLimits.entries)
              [e.key, e.value.toString()]
          ]);
          final expected = jsonEncode(budgetLimits);
          if (dart != expected) {
            problems.add('budget limits: dart $dart swift $expected');
          }
        }
        // Net worth the Swift side wrote: Dart must hold exactly these
        // accounts, in this order, and this selected month.
        final netWorthEntries = swift['netWorthEntries'];
        if (netWorthEntries is List) {
          final dart = jsonEncode([
            for (final e in app.transactionModel.netWorthEntries)
              [
                e.id,
                e.name,
                e.type.name,
                iso(e.createdAt),
                [
                  for (final s in e.snapshots)
                    [iso(s.recordedAt), s.amount.toString()]
                ],
              ]
          ]);
          final expected = jsonEncode(netWorthEntries);
          if (dart != expected) {
            problems.add('net worth entries: dart $dart swift $expected');
          }
        }
        // Savings goals the Swift side wrote: Dart must hold exactly these,
        // in this order (amounts as Dart's toString).
        final savingsGoals = swift['savingsGoals'];
        if (savingsGoals is List) {
          final dart = jsonEncode([
            for (final g in app.transactionModel.savingsGoals)
              [
                g.id,
                g.name,
                g.targetAmount.toString(),
                g.currentAmount.toString(),
                iso(g.targetDate),
                iso(g.createdAt),
                g.completedAt == null ? null : iso(g.completedAt!),
              ]
          ]);
          final expected = jsonEncode(savingsGoals);
          if (dart != expected) {
            problems.add('savings goals: dart $dart swift $expected');
          }
        }
        final selectedNetWorthMonth = swift['selectedNetWorthMonth'];
        if (selectedNetWorthMonth is String &&
            iso(app.transactionModel.selectedNetWorthMonth) !=
                selectedNetWorthMonth) {
          problems.add('selected net worth month: dart '
              '${iso(app.transactionModel.selectedNetWorthMonth)} '
              'swift $selectedNetWorthMonth');
        }
        // Settings the Swift side set: Dart must load exactly these.
        final appSettings = swift['appSettings'];
        if (appSettings is Map) {
          final s = app.appSettings;
          final dart = jsonEncode({
            'appLockEnabled': s.appLockEnabled,
            'autoLockTimeoutSeconds': s.autoLockTimeoutSeconds,
            'baseCurrencyCode': s.baseCurrencyCode,
            'hideBalances': s.hideBalances,
            'localeOverride': s.localeOverride,
          });
          final expected = jsonEncode({
            for (final key in (appSettings.keys.toList()..sort()))
              key: appSettings[key]
          });
          if (dart != expected) {
            problems.add('app settings: dart $dart swift $expected');
          }
        }
        // Categories the Swift side edited: Dart's launch pass must end with
        // exactly these definitions (every field, stored order), plus only
        // what Swift's own launch pass adds on the same bytes (ids aside:
        // a re-added padded name gets a fresh uuid). This also proves a
        // rename left no orphan name behind.
        final categories = swift['categories'];
        if (categories is List) {
          final dart = [
            for (final c in app.categoryProvider.categories)
              [
                c.id,
                c.type.name,
                c.name,
                c.iconIdentifier,
                c.colorToken,
                c.sortOrder,
                c.isArchived,
                c.isBuiltIn,
              ]
          ];
          final kept = jsonEncode(dart.take(categories.length).toList());
          if (kept != jsonEncode(categories)) {
            problems.add('categories: dart $kept swift ${jsonEncode(categories)}');
          }
          final added = jsonEncode(
              [for (final row in dart.skip(categories.length)) row.sublist(1)]);
          final expectedAdded = jsonEncode(swift['categoriesAddedAtLaunch']);
          if (added != expectedAdded) {
            problems.add('categories added at launch: dart $added swift $expectedAdded');
          }
        }
        // The category names the rename cascade wrote into every section.
        void compareRows(String key, List<List<Object?>> dart) {
          final expected = swift[key];
          if (expected is! List) return;
          if (jsonEncode(dart) != jsonEncode(expected)) {
            problems.add('$key: dart ${jsonEncode(dart)} swift ${jsonEncode(expected)}');
          }
        }

        compareRows('transactionCategories', [
          for (final t in app.transactionModel.transactions)
            [t.id, t.type.name, t.category]
        ]);
        compareRows('templateCategories', [
          for (final t in app.recurringModel.recurringTransactions)
            [t.id, t.type.name, t.category]
        ]);
        compareRows('ruleCategories', [
          for (final r in (app.categorizationProvider.rules.toList()
            ..sort((a, b) => a.id.compareTo(b.id))))
            [r.id, r.category]
        ]);
        final themeMode = swift['themeMode'];
        if (themeMode is String) {
          final theme = ThemeProvider();
          // ThemeProvider loads its preference asynchronously.
          await Future<void>.delayed(Duration.zero);
          await Future<void>.delayed(const Duration(milliseconds: 10));
          if (theme.themeMode.name != themeMode) {
            problems.add('theme mode: dart ${theme.themeMode.name} swift $themeMode');
          }
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
