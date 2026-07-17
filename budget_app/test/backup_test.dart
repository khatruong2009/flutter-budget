import 'dart:convert';

import 'package:budget_app/backup.dart';
import 'package:budget_app/net_worth_entry.dart';
import 'package:budget_app/recurring_transaction.dart';
import 'package:budget_app/savings_goal.dart';
import 'package:budget_app/transaction.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void expectTransactionEquals(Transaction actual, Transaction expected) {
  expect(actual.type, expected.type);
  expect(actual.description, expected.description);
  expect(actual.amount, expected.amount);
  expect(actual.category, expected.category);
  expect(actual.date, expected.date);
  expect(actual.recurringTemplateId, expected.recurringTemplateId);
}

void expectSnapshotEquals(NetWorthSnapshot actual, NetWorthSnapshot expected) {
  expect(actual.recordedAt, expected.recordedAt);
  expect(actual.amount, expected.amount);
}

void expectNetWorthEntryEquals(NetWorthEntry actual, NetWorthEntry expected) {
  expect(actual.id, expected.id);
  expect(actual.name, expected.name);
  expect(actual.type, expected.type);
  expect(actual.createdAt, expected.createdAt);
  expect(actual.snapshots.length, expected.snapshots.length);
  for (var i = 0; i < expected.snapshots.length; i++) {
    expectSnapshotEquals(actual.snapshots[i], expected.snapshots[i]);
  }
}

BackupData emptyBackup({ThemeMode? themeMode}) {
  return BackupData(
    transactions: const [],
    netWorthEntries: const [],
    categoryBudgetLimits: const {},
    savingsGoals: const [],
    recurringTransactions: const [],
    themeMode: themeMode,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  final transactions = <Transaction>[
    Transaction(
      type: TransactionTyp.income,
      description: 'Salary',
      amount: 1234.56,
      category: 'Income',
      date: DateTime(2026, 1, 5),
      recurringTemplateId: 'rec-2',
    ),
    Transaction(
      type: TransactionTyp.expense,
      description: 'Book "Dart", 2nd ed',
      amount: 19.99,
      category: 'Education',
      date: DateTime(2026, 2, 10),
    ),
  ];

  final netWorthEntries = <NetWorthEntry>[
    NetWorthEntry(
      id: 'asset-1',
      name: 'Checking',
      type: NetWorthEntryType.asset,
      createdAt: DateTime(2026, 1, 1),
      snapshots: [
        NetWorthSnapshot(recordedAt: DateTime(2026, 1, 15), amount: 5000.0),
        NetWorthSnapshot(recordedAt: DateTime(2026, 2, 15), amount: 5250.5),
      ],
    ),
    NetWorthEntry(
      id: 'liability-1',
      name: 'Credit Card',
      type: NetWorthEntryType.liability,
      createdAt: DateTime(2026, 1, 1),
      snapshots: [
        NetWorthSnapshot(recordedAt: DateTime(2026, 1, 20), amount: 1200.0),
      ],
    ),
  ];

  final categoryBudgetLimits = <String, double>{
    'Groceries': 650.0,
    'Transport': 250.0,
  };

  final savingsGoals = <SavingsGoal>[
    SavingsGoal(
      id: 'goal-1',
      name: 'Emergency Fund',
      targetAmount: 10000.0,
      currentAmount: 10000.0,
      targetDate: DateTime(2026, 12, 31),
      createdAt: DateTime(2026, 1, 1),
      completedAt: DateTime(2026, 6, 1),
    ),
    SavingsGoal(
      id: 'goal-2',
      name: 'Vacation',
      targetAmount: 3000.0,
      currentAmount: 500.0,
      targetDate: DateTime(2027, 6, 1),
      createdAt: DateTime(2026, 2, 1),
    ),
  ];

  final recurringTransactions = <RecurringTransaction>[
    RecurringTransaction(
      id: 'rec-1',
      type: TransactionTyp.expense,
      description: 'Gym',
      amount: 40.0,
      category: 'Health',
      pattern: RecurrencePattern.weekly,
      startDate: DateTime(2026, 1, 1),
      nextOccurrence: DateTime(2026, 1, 8),
      dayOfWeek: 4,
    ),
    RecurringTransaction(
      id: 'rec-2',
      type: TransactionTyp.income,
      description: 'Paycheck',
      amount: 2000.0,
      category: 'Income',
      pattern: RecurrencePattern.biweekly,
      startDate: DateTime(2026, 1, 1),
      nextOccurrence: DateTime(2026, 1, 15),
      dayOfWeek: 5,
    ),
    RecurringTransaction(
      id: 'rec-3',
      type: TransactionTyp.expense,
      description: 'Rent',
      amount: 1500.0,
      category: 'Housing',
      pattern: RecurrencePattern.monthly,
      startDate: DateTime(2026, 1, 1),
      nextOccurrence: DateTime(2026, 2, 1),
      dayOfMonth: 1,
    ),
  ];

  final backup = BackupData(
    transactions: transactions,
    netWorthEntries: netWorthEntries,
    categoryBudgetLimits: categoryBudgetLimits,
    savingsGoals: savingsGoals,
    recurringTransactions: recurringTransactions,
    themeMode: ThemeMode.dark,
  );

  const appVersion = '1.2.3';
  final exportedAt = DateTime(2026, 7, 17, 12, 30, 45);

  test('round-trips every field of every section through encode/decode', () {
    final encoded = encodeBackup(
      backup,
      appVersion: appVersion,
      exportedAt: exportedAt,
    );
    final decoded = decodeBackup(encoded);

    expect(decoded.transactions.length, transactions.length);
    for (var i = 0; i < transactions.length; i++) {
      expectTransactionEquals(decoded.transactions[i], transactions[i]);
    }

    expect(decoded.netWorthEntries.length, netWorthEntries.length);
    for (var i = 0; i < netWorthEntries.length; i++) {
      expectNetWorthEntryEquals(decoded.netWorthEntries[i], netWorthEntries[i]);
    }

    expect(decoded.categoryBudgetLimits, categoryBudgetLimits);

    expect(decoded.savingsGoals, savingsGoals);

    expect(decoded.recurringTransactions, recurringTransactions);

    expect(decoded.themeMode, ThemeMode.dark);

    // Envelope shape.
    final json = jsonDecode(encoded) as Map<String, dynamic>;
    expect(json['schemaVersion'], 1);
    expect(json['app'], 'budgie');
    expect(json['appVersion'], appVersion);
    expect(json['exportedAt'], exportedAt.toIso8601String());
    final data = json['data'] as Map<String, dynamic>;
    expect(data.length, 6);
    expect(
      data.keys,
      containsAll(<String>[
        'transactions',
        'netWorthEntries',
        'categoryBudgetLimits',
        'savingsGoals',
        'recurringTransactions',
        'themeMode',
      ]),
    );
  });

  test('themeMode round-trips for light, dark, system, and null', () {
    for (final mode in <ThemeMode?>[
      ThemeMode.light,
      ThemeMode.dark,
      ThemeMode.system,
      null,
    ]) {
      final encoded = encodeBackup(
        emptyBackup(themeMode: mode),
        appVersion: appVersion,
        exportedAt: exportedAt,
      );
      expect(decodeBackup(encoded).themeMode, mode);
    }
  });

  test('decode rejects invalid content with a FormatException', () {
    const rejected = <String>[
      '',
      'not json',
      '[]',
      '{}',
      '{"schemaVersion":"1","data":{}}',
      '{"schemaVersion":999,"data":{}}',
      '{"schemaVersion":1}',
      '{"schemaVersion":1,"data":{"transactions":"oops"}}',
      '{"schemaVersion":1,"data":{"transactions":[{"amount":"NaN-ish"}]}}',
    ];
    for (final content in rejected) {
      expect(
        () => decodeBackup(content),
        throwsFormatException,
        reason: 'should reject: $content',
      );
    }
  });

  test('decode rejects non-finite numbers in every section', () {
    // jsonDecode('1e999') yields infinity, which jsonEncode cannot
    // re-serialize; accepting it would fail midway through the
    // store-by-store restore persistence.
    const rejected = <String>[
      '{"schemaVersion":1,"data":{"categoryBudgetLimits":{"Food":1e999}}}',
      '{"schemaVersion":1,"data":{"transactions":[{"type":"expense",'
          '"description":"x","amount":1e999,"category":"Food",'
          '"date":"2026-07-01T00:00:00.000"}]}}',
      '{"schemaVersion":1,"data":{"savingsGoals":[{"id":"g1","name":"Goal",'
          '"targetAmount":1e999,"currentAmount":0.0,'
          '"targetDate":"2026-12-31T00:00:00.000",'
          '"createdAt":"2026-07-01T00:00:00.000"}]}}',
      '{"schemaVersion":1,"data":{"netWorthEntries":[{"id":"a1","name":"X",'
          '"type":"asset","createdAt":"2026-07-01T00:00:00.000",'
          '"snapshots":[{"recordedAt":"2026-07-01T00:00:00.000",'
          '"amount":-1e999}]}]}}',
      '{"schemaVersion":1,"data":{"recurringTransactions":[{"id":"r1",'
          '"type":"expense","description":"Rent","amount":1e999,'
          '"category":"Housing","pattern":"weekly",'
          '"startDate":"2026-07-01T00:00:00.000",'
          '"nextOccurrence":"2026-07-08T00:00:00.000","isActive":true}]}}',
    ];
    for (final content in rejected) {
      expect(
        () => decodeBackup(content),
        throwsFormatException,
        reason: 'should reject: $content',
      );
    }
  });

  test('decode rejects unrecognized type strings instead of coercing', () {
    // The model fromJson factories coerce anything != 'expense' to income
    // (and != 'liability' to asset), which would silently flip data.
    const rejected = <String>[
      '{"schemaVersion":1,"data":{"transactions":[{"type":"Expense",'
          '"description":"x","amount":5.0,"category":"Food",'
          '"date":"2026-07-01T00:00:00.000"}]}}',
      '{"schemaVersion":1,"data":{"transactions":[{"type":"transfer",'
          '"description":"x","amount":5.0,"category":"Food",'
          '"date":"2026-07-01T00:00:00.000"}]}}',
      '{"schemaVersion":1,"data":{"netWorthEntries":[{"id":"a1","name":"X",'
          '"type":"Asset","createdAt":"2026-07-01T00:00:00.000",'
          '"snapshots":[]}]}}',
      '{"schemaVersion":1,"data":{"recurringTransactions":[{"id":"r1",'
          '"type":"EXPENSE","description":"Rent","amount":900.0,'
          '"category":"Housing","pattern":"weekly",'
          '"startDate":"2026-07-01T00:00:00.000",'
          '"nextOccurrence":"2026-07-08T00:00:00.000","isActive":true}]}}',
    ];
    for (final content in rejected) {
      expect(
        () => decodeBackup(content),
        throwsFormatException,
        reason: 'should reject: $content',
      );
    }
  });

  test('decode validates dayOfMonth for monthly recurring templates', () {
    String monthly(String dayOfMonth) =>
        '{"schemaVersion":1,"data":{"recurringTransactions":[{"id":"r1",'
        '"type":"expense","description":"Rent","amount":900.0,'
        '"category":"Housing","pattern":"monthly",'
        '"startDate":"2026-07-01T00:00:00.000",'
        '"nextOccurrence":"2026-08-01T00:00:00.000",'
        '"dayOfMonth":$dayOfMonth,"isActive":true}]}}';

    // TransactionGenerator dereferences dayOfMonth for monthly templates and
    // loops on the computed next occurrence; a bad day crashes or hangs
    // every launch after restore.
    for (final bad in ['null', '0', '-30', '32']) {
      expect(
        () => decodeBackup(monthly(bad)),
        throwsFormatException,
        reason: 'should reject monthly dayOfMonth $bad',
      );
    }

    final decoded = decodeBackup(monthly('31'));
    expect(decoded.recurringTransactions.single.dayOfMonth, 31);

    // Weekly templates do not use dayOfMonth; null stays valid there.
    const weekly =
        '{"schemaVersion":1,"data":{"recurringTransactions":[{"id":"r1",'
        '"type":"expense","description":"Gym","amount":20.0,'
        '"category":"Health","pattern":"weekly",'
        '"startDate":"2026-07-01T00:00:00.000",'
        '"nextOccurrence":"2026-07-08T00:00:00.000","isActive":true}]}}';
    expect(decodeBackup(weekly).recurringTransactions.single.dayOfMonth, isNull);
  });

  test('absent sections decode to empty collections and null theme', () {
    final decoded = decodeBackup('{"schemaVersion":1,"data":{}}');
    expect(decoded.transactions, isEmpty);
    expect(decoded.netWorthEntries, isEmpty);
    expect(decoded.categoryBudgetLimits, isEmpty);
    expect(decoded.savingsGoals, isEmpty);
    expect(decoded.recurringTransactions, isEmpty);
    expect(decoded.themeMode, isNull);
  });

  test('null sections decode to empty collections and null theme', () {
    const content = '{"schemaVersion":1,"data":{'
        '"transactions":null,'
        '"netWorthEntries":null,'
        '"categoryBudgetLimits":null,'
        '"savingsGoals":null,'
        '"recurringTransactions":null,'
        '"themeMode":null}}';
    final decoded = decodeBackup(content);
    expect(decoded.transactions, isEmpty);
    expect(decoded.netWorthEntries, isEmpty);
    expect(decoded.categoryBudgetLimits, isEmpty);
    expect(decoded.savingsGoals, isEmpty);
    expect(decoded.recurringTransactions, isEmpty);
    expect(decoded.themeMode, isNull);
  });

  test('unknown extra keys at top level and inside data are ignored', () {
    const content = '{"schemaVersion":1,"extra":"x",'
        '"data":{"unknownKey":123,"themeMode":"light"}}';
    final decoded = decodeBackup(content);
    expect(decoded.transactions, isEmpty);
    expect(decoded.themeMode, ThemeMode.light);
  });

  test('strips a leading UTF-8 BOM before decoding', () {
    final encoded = encodeBackup(
      emptyBackup(themeMode: ThemeMode.system),
      appVersion: appVersion,
      exportedAt: exportedAt,
    );
    final decoded = decodeBackup('﻿$encoded');
    expect(decoded.themeMode, ThemeMode.system);
  });

  test('unknown themeMode string decodes to null without throwing', () {
    const content = '{"schemaVersion":1,"data":{"themeMode":"neon"}}';
    expect(decodeBackup(content).themeMode, isNull);
  });
}
