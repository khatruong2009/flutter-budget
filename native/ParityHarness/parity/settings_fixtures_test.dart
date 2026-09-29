// Emits native/Fixtures/settings/ : the Settings page's labels and choice
// lists as the real page renders them, and the AppSettingsProvider
// setters' writes.
//
// labels.json: for stored `appSettings` sections (lock delays, currencies
// and locales inside and outside the page's lists), the subtitles the real
// SettingsPage shows (Currency, Number format, App lock, Lock delay).
//
// sheets.json: the three choice sheets (title, rows in order, which row is
// ticked) for a listed and an unlisted current value, and the value each
// row stores when tapped (read back from the provider).
//
// setters.json: a sequence of real setter calls through a real store and
// SharedPreferences; after each, whether the store was written, the stored
// `appSettings` section, the preferences and the provider's fields.

import 'dart:convert';
import 'dart:io';

import 'package:budget_app/app_settings_provider.dart';
import 'package:budget_app/categorization_provider.dart';
import 'package:budget_app/category_provider.dart';
import 'package:budget_app/recurring_transaction_model.dart';
import 'package:budget_app/settings_page.dart';
import 'package:budget_app/storage/atomic_financial_store.dart';
import 'package:budget_app/theme_provider.dart';
import 'package:budget_app/transaction_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'harness_support.dart';

Map<String, Object?> settingsSection({
  String currency = 'USD',
  String? locale,
  bool lock = true,
  int timeout = 60,
}) =>
    {
      'baseCurrencyCode': currency,
      'localeOverride': locale,
      'appLockEnabled': lock,
      'autoLockTimeoutSeconds': timeout,
      'hideBalances': false,
    };

Map<String, Object?> fields(AppSettingsProvider s) => {
      'baseCurrencyCode': s.baseCurrencyCode,
      'localeOverride': s.localeOverride,
      'appLockEnabled': s.appLockEnabled,
      'autoLockTimeoutSeconds': s.autoLockTimeoutSeconds,
      'hideBalances': s.hideBalances,
    };

Future<AppHarness> loadApp(
    WidgetTester tester, Map<String, Object?> section) async {
  final app = AppHarness();
  await tester.runAsync(() async {
    SharedPreferences.setMockInitialValues({});
    final dir = await Directory.systemTemp.createTemp('settings_fixture');
    await AtomicFinancialStore.instance.resetForTesting(directory: dir);
    await AtomicFinancialStore.instance
        .updateSections({'appSettings': section});
    await app.initialize(generate: false);
  });
  return app;
}

Future<void> pumpPage(WidgetTester tester, AppHarness app) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
        ChangeNotifierProvider<TransactionModel>.value(
            value: app.transactionModel),
        ChangeNotifierProvider<RecurringTransactionModel>.value(
            value: app.recurringModel),
        ChangeNotifierProvider<AppSettingsProvider>.value(
            value: app.appSettings),
        ChangeNotifierProvider<CategoryProvider>.value(
            value: app.categoryProvider),
        ChangeNotifierProvider<CategorizationProvider>.value(
            value: app.categorizationProvider),
      ],
      child: const MaterialApp(home: SettingsPage()),
    ),
  );
  await tester.pumpAndSettle();
}

/// The subtitle under a row title (the second Text of the row's column),
/// or null when the row is not on the page.
String? subtitleOf(WidgetTester tester, String title) {
  final titleFinder = find.text(title);
  if (titleFinder.evaluate().isEmpty) return null;
  final column = find
      .ancestor(of: titleFinder.first, matching: find.byType(Column))
      .first;
  final texts = tester
      .widgetList<Text>(
          find.descendant(of: column, matching: find.byType(Text)))
      .map((t) => t.data)
      .toList();
  return texts.length > 1 ? texts[1] : null;
}

/// Lets the real store and preferences finish a write started by a tap.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

/// Opens the sheet behind [row] and reads its title and rows.
Future<Map<String, Object?>> readSheet(
    WidgetTester tester, String row, String title) async {
  await tester.tap(find.text(row));
  await tester.pumpAndSettle();
  // The sheet's title (Number format and Lock delay repeat the row title).
  expect(find.text(title), findsWidgets);
  final tiles = tester.widgetList<ListTile>(find.byType(ListTile)).toList();
  final rows = [
    for (final tile in tiles)
      {
        'label': (tile.title as Text).data,
        'checked': tile.trailing != null,
      }
  ];
  return {'title': title, 'rows': rows};
}

Future<void> closeSheet(WidgetTester tester) async {
  await tester.tapAt(const Offset(10, 10));
  await tester.pumpAndSettle();
}

const sheetSpecs = [
  ('Currency', 'Base currency', 'baseCurrencyCode'),
  ('Number format', 'Number format', 'localeOverride'),
  ('Lock delay', 'Lock delay', 'autoLockTimeoutSeconds'),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final dir = fixtureDir('settings').path;
  final labels = <Map<String, Object?>>[];
  final sheets = <Map<String, Object?>>[];

  void quietErrors() {
    // The test font is wider than Gabarito, so some rows overflow, and the
    // sheets trip ListTile's debug-only ink check. Neither touches a value
    // read here; anything else still fails the test.
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      final text = details.exceptionAsString();
      if (text.contains('overflowed') ||
          text.contains('ListTile background color')) {
        return;
      }
      previous?.call(details);
    };
    addTearDown(() => FlutterError.onError = previous);
  }

  final labelSections = [
    settingsSection(lock: false),
    for (final t in [
      0, 1, 2, 29, 30, 45, 59, 60, 61, 90, 119, 120, 121, 299, 300, 900, //
      3599, 3600, 86400, -5,
    ])
      settingsSection(timeout: t),
    for (final c in [
      'USD', 'CAD', 'EUR', 'GBP', 'AUD', 'JPY', 'CNY', 'INR', 'KRW', 'MXN', //
      'BRL', 'CHF', 'usd',
    ])
      settingsSection(currency: c),
    for (final l in [
      'en_US', 'en_CA', 'en_GB', 'en_AU', 'de_DE', 'fr_FR', 'es_ES', //
      'ja_JP', 'pt_BR', 'de-DE', '',
    ])
      settingsSection(locale: l),
  ];

  testWidgets('labels', (tester) async {
    quietErrors();
    tester.view.physicalSize = const Size(1000, 8000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    for (final section in labelSections) {
      final app = await loadApp(tester, section);
      await pumpPage(tester, app);
      labels.add({
        'section': section,
        'currency': subtitleOf(tester, 'Currency'),
        'numberFormat': subtitleOf(tester, 'Number format'),
        'appLock': subtitleOf(tester, 'App lock'),
        'lockDelay': subtitleOf(tester, 'Lock delay'),
        'hideBalances': subtitleOf(tester, 'Hide balances'),
      });
    }
  });

  for (final (name, section) in [
    ('listed', settingsSection()),
    ('unlisted', settingsSection(currency: 'CHF', locale: 'pt_BR', timeout: 45)),
  ]) {
    testWidgets('sheets: $name', (tester) async {
      quietErrors();
      tester.view.physicalSize = const Size(1000, 8000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final app = await loadApp(tester, section);
      await pumpPage(tester, app);
      final out = <String, Object?>{'name': name, 'section': section};
      for (final (row, title, _) in sheetSpecs) {
        out[row] = await readSheet(tester, row, title);
        await closeSheet(tester);
      }
      // Tap every row in turn; the value it stored is what the row means.
      if (name == 'listed') {
        for (final (row, title, field) in sheetSpecs) {
          final picks = <Map<String, Object?>>[];
          final count =
              ((out[row] as Map)['rows'] as List).length;
          for (var i = 0; i < count; i++) {
            await tester.tap(find.text(row));
            await tester.pumpAndSettle();
            final tile = find.byType(ListTile).at(i);
            final label = (tester.widget<ListTile>(tile).title as Text).data;
            await tester.tap(tile);
            await settle(tester);
            expect(find.byType(ListTile), findsNothing, reason: title);
            picks.add({'label': label, 'stored': fields(app.appSettings)[field]});
          }
          out['$row picks'] = picks;
        }
      }
      sheets.add(out);
    });
  }

  test('write labels.json and sheets.json', () {
    writeJson('$dir/labels.json', {'cases': labels});
    writeJson('$dir/sheets.json', {'cases': sheets});
  });

  test('setters', () async {
    SharedPreferences.setMockInitialValues({});
    final temp = await Directory.systemTemp.createTemp('settings_setters');
    await AtomicFinancialStore.instance.resetForTesting(directory: temp);
    final store = AtomicFinancialStore.instance;
    final settings = AppSettingsProvider();
    await settings.load();
    final loaded = fields(settings);

    final ops = <List<Object?>>[
      ['currency', ' eur '],
      ['currency', 'EUR'],
      ['currency', 'euro'],
      ['currency', ''],
      ['currency', '\tgbp\u{FEFF}'],
      ['currency', 'usd'],
      ['locale', ' de_DE '],
      ['locale', 'de_DE'],
      ['locale', '   '],
      ['locale', null],
      ['locale', 'fr_FR'],
      ['lock', true],
      ['lock', true],
      ['lock', false],
      ['timeout', -1],
      ['timeout', 60],
      ['timeout', 0],
      ['timeout', 900],
      ['timeout', 0],
      ['hide', true],
      ['hide', true],
      ['hide', false],
    ];
    final steps = <Map<String, Object?>>[];
    for (final op in ops) {
      final before = (await store.read()).revision;
      switch (op[0]) {
        case 'currency':
          await settings.setBaseCurrencyCode(op[1] as String);
        case 'locale':
          await settings.setLocaleOverride(op[1] as String?);
        case 'lock':
          await settings.setAppLockEnabled(op[1] as bool);
        case 'timeout':
          await settings.setAutoLockTimeoutSeconds(op[1] as int);
        case 'hide':
          await settings.setHideBalances(op[1] as bool);
      }
      final snapshot = await store.read();
      final section = snapshot.sections[FinancialSections.appSettings];
      steps.add({
        'op': op[0],
        'arg': op[1],
        'wrote': snapshot.revision != before,
        'section': section == null ? null : jsonEncode(section),
        'prefs': await dumpPrefs(),
        'memory': fields(settings),
      });
    }
    writeJson('$dir/setters.json', {'loaded': loaded, 'steps': steps});
  });
}
