// Emits native/Fixtures/legacy/<scenario>/ : devices that still hold data in
// the pre-file SharedPreferences formats (v1 envelope, its backup, bare
// per-feature keys), alone or mixed, plus the real preferences.
//
// The v1 envelope is produced with the exact encoder the previous store used
// (git show c473af9:budget_app/lib/storage/atomic_financial_store.dart,
// `_encode`), which is also what test/atomic_financial_store_test.dart uses.

import 'dart:convert';
import 'dart:io';

import 'package:budget_app/storage/atomic_financial_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixture_runner.dart';
import 'harness_support.dart';
import 'store_scenarios.dart';

String v1Envelope({
  required int revision,
  required Map<String, dynamic> sections,
  int schemaVersion = 1,
}) {
  final payload = <String, dynamic>{
    'schemaVersion': schemaVersion,
    'revision': revision,
    'sections': sections,
  };
  return jsonEncode({
    ...payload,
    'checksum': fnv(utf8.encode(jsonEncode(payload))),
  });
}

/// Every section key the v1 store wrote, filled from [sections].
Map<String, dynamic> v1Sections(Map<String, dynamic> sections) => {
      for (final key in [
        'transactions',
        'netWorthEntries',
        'selectedNetWorthMonth',
        'categoryBudgetLimits',
        'savingsGoals',
        'recurringTransactions',
        'categories',
        'transactionTags',
        'categorizationRules',
        'appSettings',
      ])
        if (sections.containsKey(key)) key: sections[key],
    };

/// Values whose checksum only verifies if the verifier re-encodes exactly
/// like Dart: shortest doubles with `.0`, exponent forms, raw non-ASCII,
/// escaped controls and lone surrogates, unescaped `/`.
Map<String, dynamic> encodingTortureSections() => {
      'transactions': [
        {
          'id': 'enc-1',
          'type': 'expense',
          'description': 'a/b é 😀 \u0001 \u007f   "q" \\ \t \uD83D end',
          'amount': 1.0,
          'category': 'General',
          'date': '2023-01-02T03:04:05.006007',
          'recurringTemplateId': null,
          'tagIds': [],
          'createdAt': '2023-01-02T03:04:05.006',
          'updatedAt': '2023-01-02T03:04:05.006',
        },
        for (final (i, amount) in [
          0.30000000000000004,
          1e-7,
          1e21,
          1e20,
          123456789012345680000.0,
          5e-324,
          1.7976931348623157e308,
          0.000001,
          0.00001,
          -0.0,
          100.0,
          12.5,
        ].indexed)
          {
            'id': 'enc-num-$i',
            'type': 'expense',
            'description': 'n$i',
            'amount': amount,
            'category': 'General',
            'date': '2023-01-03T00:00:00.000',
            'recurringTemplateId': null,
            'tagIds': [],
            'createdAt': '2023-01-03T00:00:00.000',
            'updatedAt': '2023-01-03T00:00:00.000',
          },
      ],
      'categoryBudgetLimits': {'General': 12, 'Große Ausgaben': 3.5},
      'appSettings': {
        'baseCurrencyCode': 'JPY',
        'localeOverride': 'ja_JP',
        'appLockEnabled': false,
        'autoLockTimeoutSeconds': 0,
        'hideBalances': true,
      },
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, dynamic> typicalSections;
  late Directory typicalFiles;

  setUpAll(() async {
    final work = await Directory.systemTemp.createTemp('parity_legacy_typ');
    typicalFiles = Directory('${work.path}/financial_store');
    SharedPreferences.setMockInitialValues({});
    await AtomicFinancialStore.instance.resetForTesting(directory: typicalFiles);
    await buildTypicalStore(AppHarness());
    typicalSections = Map<String, dynamic>.from(
        jsonDecode(jsonEncode((await AtomicFinancialStore.instance.read()).sections))
            as Map);
    await AtomicFinancialStore.instance.resetForTesting();
  });

  final none = Directory('${Directory.systemTemp.path}/parity_legacy_none');

  Future<void> scenario(String name, Map<String, Object> prefs,
      {required String description, Directory? files}) async {
    if (none.existsSync()) none.deleteSync(recursive: true);
    final input = files ?? none;
    emit(name, input, prefs, await expectFor(input, prefs),
        description: description, group: 'legacy');
  }

  List<Map<String, dynamic>> olderLedger() => [
        for (final row in (typicalSections['transactions'] as List).take(20))
          Map<String, dynamic>.from(row as Map),
      ];

  Map<String, Object> realPreferences() => {
        'themeMode': 'dark',
        'onboarding_completed': true,
        'local_insights_dismissed_v1': ['monthly-change:2026-8', 'savings-rate:2026-8'],
        'local_insights_snoozed_v1':
            jsonEncode({'negative-flow:2026-9': '2026-10-01T09:00:00.000'}),
      };

  test('v1 envelope only', () async {
    await scenario('v1_only', {
      'financial_store_v1':
          v1Envelope(revision: 41, sections: v1Sections(typicalSections)),
      ...realPreferences(),
    }, description: 'Only the v1 envelope (all sections) plus real prefs.');
  });

  test('v1 primary newer than backup', () async {
    await scenario('v1_primary_newer', {
      'financial_store_v1':
          v1Envelope(revision: 41, sections: v1Sections(typicalSections)),
      'financial_store_v1_backup': v1Envelope(revision: 40, sections: {
        ...v1Sections(typicalSections),
        'transactions': olderLedger(),
      }),
    }, description: 'Primary rev 41 wins over backup rev 40.');
  });

  test('v1 backup newer, bare transactions override', () async {
    await scenario('v1_backup_newer_bare_override', {
      'financial_store_v1': v1Envelope(revision: 40, sections: {
        ...v1Sections(typicalSections),
        'transactions': olderLedger(),
      }),
      'financial_store_v1_backup':
          v1Envelope(revision: 41, sections: v1Sections(typicalSections)),
      'transactions': jsonEncode(olderLedger().take(5).toList()),
    }, description: 'Backup newer so primary not chosen; the bare '
        'transactions key replaces the chosen envelope transactions.');
  });

  test('v1 primary tampered, backup ok, bare transactions', () async {
    final good = v1Envelope(revision: 12, sections: v1Sections(typicalSections));
    await scenario('v1_primary_tampered_bare_override', {
      'financial_store_v1': good.replaceFirst('"revision":12', '"revision":13'),
      'financial_store_v1_backup': good,
      'transactions': jsonEncode(olderLedger()),
    }, description: 'Primary fails its checksum; backup used; bare '
        'transactions override.');
  });

  test('v1 primary tampered, backup ok, no bare keys', () async {
    final good = v1Envelope(revision: 12, sections: v1Sections(typicalSections));
    await scenario('v1_primary_tampered', {
      'financial_store_v1': good.substring(0, good.length - 5),
      'financial_store_v1_backup': good,
    }, description: 'Primary truncated; backup used as is.');
  });

  test('v1 empty bare transactions list overrides backup', () async {
    await scenario('v1_backup_empty_bare_list', {
      'financial_store_v1_backup':
          v1Envelope(revision: 9, sections: v1Sections(typicalSections)),
      'transactions': '[]',
    }, description: 'An empty bare list still replaces the backup ledger.');
  });

  test('v1 schemaVersion 2 is rejected', () async {
    await scenario('v1_schema2_rejected', {
      'financial_store_v1': v1Envelope(
          revision: 5, sections: v1Sections(typicalSections), schemaVersion: 2),
      'net_worth_entries': jsonEncode(typicalSections['netWorthEntries']),
    }, description: 'Envelope claims schemaVersion 2: ignored; bare keys only.');
  });

  test('v1 partial envelope filled from bare keys', () async {
    await scenario('v1_partial_plus_bare', {
      'financial_store_v1': v1Envelope(revision: 3, sections: {
        'transactions': typicalSections['transactions'],
      }),
      'net_worth_entries': jsonEncode(typicalSections['netWorthEntries']),
      'recurring_transactions':
          jsonEncode(typicalSections['recurringTransactions']),
      'transactions': jsonEncode(olderLedger()),
      'base_currency_code': 'CAD',
      'hide_balances': true,
    }, description: 'Envelope has only transactions (kept; primary chosen); '
        'bare keys fill the rest; appSettings synthesised from prefs.');
  });

  test('v1 encoding torture', () async {
    await scenario('v1_encoding_torture', {
      'financial_store_v1':
          v1Envelope(revision: 77, sections: encodingTortureSections()),
    }, description: 'Checksum verifies only with Dart-identical re-encoding.');
  });

  test('bare keys only', () async {
    await scenario('bare_only', {
      'transactions': jsonEncode(typicalSections['transactions']),
      'net_worth_entries': jsonEncode(typicalSections['netWorthEntries']),
      'net_worth_selected_month': '2026-02-01T00:00:00.000',
      'category_budget_limits':
          jsonEncode(typicalSections['categoryBudgetLimits']),
      'savings_goals': jsonEncode(typicalSections['savingsGoals']),
      'recurring_transactions':
          jsonEncode(typicalSections['recurringTransactions']),
      'categories_v1': jsonEncode(typicalSections['categories']),
      'transaction_tags_v1': jsonEncode(typicalSections['transactionTags']),
      'categorization_rules_v1':
          jsonEncode(typicalSections['categorizationRules']),
      'base_currency_code': 'EUR',
      'locale_override': 'fr_FR',
      'app_lock_enabled': true,
      'auto_lock_timeout_seconds': 900,
      'hide_balances': false,
      'starting_assets': 3200.0,
      'starting_liabilities': 900.0,
      ...realPreferences(),
    }, description: 'Every bare per-feature key, every setting key, starting '
        'balances, theme, onboarding and insight prefs; no envelope.');
  });

  test('bare keys malformed or empty', () async {
    await scenario('bare_malformed', {
      'transactions': '[{"id":"ok-1","type":"income","description":"kept",'
          '"amount":5,"category":"Salary","date":"2024-01-01T00:00:00.000"}]',
      'net_worth_entries': '{not json',
      'savings_goals': '',
      'category_budget_limits': '{"Groceries": 100}',
      'net_worth_selected_month': 'not a date',
    }, description: 'Malformed JSON and empty strings count as absent.');
  });

  test('settings keys only', () async {
    await scenario('settings_only', {
      'base_currency_code': 'GBP',
      'auto_lock_timeout_seconds': 30,
    }, description: 'Only settings keys: a store with just appSettings is '
        'created; defaults fill the other settings.');
  });

  test('starting balances only', () async {
    await scenario('starting_balances_only', {
      'starting_assets': 3200.0,
      'starting_liabilities': 900.0,
    }, description: 'Not store data: migration finds nothing, the net worth '
        'model then creates Starting Assets/Liabilities entries.');
  });

  test('v2 present, legacy keys ignored', () async {
    await scenario('v2_plus_legacy_ignored', {
      'financial_store_v1':
          v1Envelope(revision: 999, sections: {'transactions': olderLedger()}),
      'transactions': jsonEncode(olderLedger()),
      'base_currency_code': 'MXN',
    },
        files: typicalFiles,
        description: 'A readable v2 file wins; legacy keys are neither read '
            'nor removed (settings fallback still applies per field).');
  });

  test('preferences only, no financial data', () async {
    await scenario('real_prefs_only', realPreferences(),
        description: 'Only theme, onboarding and insight prefs.');
  });
}
