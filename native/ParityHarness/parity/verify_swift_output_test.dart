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
//                       "ruleCategories", "transactionTags",
//                       "categorizationRules": what the Dart models must hold;
//                       "newTagIds", "newRuleIds": rows Swift made;
//                       optional "backup": {"appVersion", "exportedAt", "themeMode"}}
//   backup.json        optional: Swift's backup export of this store after a
//                       launch (see verifyBackup)
//
// Writes $SWIFT_OUT/dart-verification.json and fails if any case failed.

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:budget_app/backup.dart';
import 'package:budget_app/categorization_rule.dart';
import 'package:budget_app/storage/atomic_financial_store.dart';
import 'package:budget_app/theme_provider.dart';
import 'package:budget_app/transaction_tag.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixture_runner.dart';
import 'harness_support.dart';
import 'model_summary.dart';

/// A Swift-exported backup of the store in [dir]:
///  1. equals Flutter's export of the same store after a launch (load and
///     recurring generation), ids generated during that launch aside;
///  2. `decodeBackup` accepts it;
///  3. restored into an empty store by the page's restore chain, then
///     exported again, it is the same file.
Future<List<String>> verifyBackup(Directory dir, File backupFile,
    Map<String, dynamic> spec, Map<String, Object> prefs) async {
  final problems = <String>[];
  final bytes = backupFile.readAsBytesSync();
  final swiftText = utf8.decode(bytes);
  final appVersion = spec['appVersion'] as String;
  final exportedAt = DateTime.parse(spec['exportedAt'] as String);
  final theme = themeFrom(spec['themeMode'] as String?);
  String firstDifference(String a, String b) {
    var i = 0;
    while (i < a.length && i < b.length && a[i] == b[i]) {
      i++;
    }
    final from = max(0, i - 80);
    return 'at $i: swift «${a.substring(from, min(a.length, i + 80))}» '
        'dart «${b.substring(from, min(b.length, i + 80))}»';
  }

  // 1. Flutter's export after its own launch of the same files.
  final work = await Directory.systemTemp.createTemp('verify_backup');
  final storeDir = Directory('${work.path}/financial_store');
  copyDir(Directory('${dir.path}/financial_store'), storeDir);
  SharedPreferences.setMockInitialValues(Map.of(prefs));
  pinClock(launchNow);
  await AtomicFinancialStore.instance.resetForTesting(directory: storeDir);
  final sections = (await AtomicFinancialStore.instance.read()).sections;
  final launched = AppHarness();
  await launched.initialize(generate: true);
  final dartText = encodeBackup(exportData(launched, theme),
      appVersion: appVersion, exportedAt: exportedAt);
  final aligned = alignGeneratedIds(swiftText, dartText, sections);
  if (aligned == null) {
    problems.add('backup: generated ids differ in number');
  } else if (aligned != dartText) {
    problems.add('backup: Flutter export differs ${firstDifference(aligned, dartText)}');
  }

  // 2. Flutter reads it.
  BackupData? decoded;
  try {
    decoded = decodeBackup(utf8.decode(bytes, allowMalformed: true));
  } catch (error) {
    problems.add('backup: decodeBackup threw $error');
  }

  // 3. Restore into an empty store, export again.
  if (decoded != null) {
    final restoreWork = await Directory.systemTemp.createTemp('verify_restore');
    SharedPreferences.setMockInitialValues({});
    await AtomicFinancialStore.instance.resetForTesting(
        directory: Directory('${restoreWork.path}/financial_store'));
    final restored = AppHarness();
    await restored.initialize(generate: false);
    final themeProvider = ThemeProvider();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    try {
      await restoreChain(restored, themeProvider, decoded);
      final again = encodeBackup(exportData(restored, themeProvider.themeMode),
          appVersion: appVersion, exportedAt: exportedAt);
      if (again != swiftText) {
        problems.add('backup: restore then export differs ${firstDifference(swiftText, again)}');
      }
      if (restored.transactionModel.hasUnsavedChanges ||
          restored.recurringModel.hasUnsavedChanges) {
        problems.add('backup: unsaved changes after the restore');
      }
    } catch (error) {
      problems.add('backup: restore threw $error');
    }
  }
  return problems;
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
        // Tags and rules the Swift side edited: Dart must load exactly
        // these (`rules` in its getter's order, bounds as toString); the
        // rows Swift made must be Dart's `toJson` byte for byte; and the
        // state must be one Flutter's backup import accepts (unique tag and
        // rule ids, every rule tag id a tag; backup.dart:124-133).
        final transactionTags = swift['transactionTags'];
        if (transactionTags is List) {
          final provider = app.categorizationProvider;
          compareRows('transactionTags', [
            for (final t in provider.tags) [t.id, t.name, t.colorToken]
          ]);
          compareRows('categorizationRules', [
            for (final r in provider.rules)
              [
                r.id,
                r.merchantPattern,
                r.matchType.name,
                r.transactionType?.name,
                r.minimumAmount?.toString(),
                r.maximumAmount?.toString(),
                r.category,
                r.tagIds,
                r.priority,
                r.isEnabled,
              ]
          ]);
          void canonical(String section, List<Object?> ids,
              String Function(Map<String, dynamic>) toJson) {
            final rows = snapshot.sections[section] as List? ?? const [];
            for (final id in ids) {
              final row = rows.whereType<Map<String, dynamic>>()
                  .where((r) => r['id'] == id)
                  .toList();
              if (row.length != 1) {
                problems.add('$section: ${row.length} rows with Swift id $id');
              } else if (jsonEncode(row.single) != toJson(row.single)) {
                problems.add('$section: row $id is not toJson: '
                    '${jsonEncode(row.single)} vs ${toJson(row.single)}');
              }
            }
          }

          canonical('transactionTags', swift['newTagIds'] as List,
              (row) => jsonEncode(TransactionTag.fromJson(row).toJson()));
          canonical('categorizationRules', swift['newRuleIds'] as List,
              (row) => jsonEncode(CategorizationRule.fromJson(row).toJson()));
          final tagIds = {for (final t in provider.tags) t.id};
          final ruleIds = {for (final r in provider.rules) r.id};
          if (tagIds.length != provider.tags.length ||
              ruleIds.length != provider.rules.length) {
            problems.add('duplicate tag or rule ids (backup import refuses)');
          }
          for (final r in provider.rules) {
            for (final id in r.tagIds) {
              if (!tagIds.contains(id)) {
                problems.add('rule ${r.id} names unknown tag $id (backup import refuses)');
              }
            }
          }
        }
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

      // A backup Swift exported from this store (after a launch).
      final backupFile = File('${dir.path}/backup.json');
      if (summary != null && backupFile.existsSync()) {
        problems.addAll(await verifyBackup(
            dir, backupFile, swift['backup'] as Map<String, dynamic>, prefs));
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
