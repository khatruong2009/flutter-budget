import 'package:budget_app/storage/storage_keys.dart';
import 'package:budget_app/transaction.dart';
import 'package:budget_app/transaction_model.dart';
import 'package:csv/csv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Build a CSV string exactly the way exportTransactionsToCSV does.
String buildExportCsv(List<Transaction> transactions) {
  final rows = <List<dynamic>>[
    ['Date', 'Type', 'Category', 'Description', 'Amount'],
  ];
  final sorted = List<Transaction>.from(transactions)
    ..sort((a, b) => a.date.compareTo(b.date));
  for (final transaction in sorted) {
    rows.add([
      DateFormat('yyyy-MM-dd').format(transaction.date),
      transaction.type == TransactionTyp.income ? 'Income' : 'Expense',
      transaction.category,
      transaction.description,
      transaction.amount.toStringAsFixed(2),
    ]);
  }
  return const ListToCsvConverter().convert(rows);
}

void expectTransactionEquals(Transaction actual, Transaction expected) {
  expect(actual.type, expected.type);
  expect(actual.description, expected.description);
  expect(actual.amount, expected.amount);
  expect(actual.category, expected.category);
  expect(actual.date, expected.date);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  final sampleTransactions = <Transaction>[
    Transaction(
      type: TransactionTyp.income,
      description: 'Salary, bonus',
      amount: 1234.56,
      category: 'Income',
      date: DateTime(2026, 1, 5),
    ),
    Transaction(
      type: TransactionTyp.expense,
      description: 'Book "Dart"',
      amount: 19.99,
      category: 'Education',
      date: DateTime(2026, 2, 10),
    ),
    Transaction(
      type: TransactionTyp.expense,
      description: 'line1\nline2',
      amount: 5.00,
      category: 'Misc',
      date: DateTime(2026, 3, 15),
    ),
    Transaction(
      type: TransactionTyp.expense,
      description: 'Milk',
      amount: 3.49,
      category: 'Groceries',
      date: DateTime(2026, 3, 20),
    ),
  ];

  test('round-trips every field through export and parse', () {
    final csv = buildExportCsv(sampleTransactions);

    final model = TransactionModel();
    final summary = model.parseTransactionsCsv(csv);

    expect(summary.duplicateCount, 0);
    expect(summary.rowErrors, isEmpty);
    expect(summary.transactions.length, sampleTransactions.length);
    for (var i = 0; i < sampleTransactions.length; i++) {
      expectTransactionEquals(summary.transactions[i], sampleTransactions[i]);
    }
  });

  test('re-importing an export of current data yields no new transactions', () {
    final model = TransactionModel();
    for (final transaction in sampleTransactions) {
      model.addTransaction(
        transaction.type,
        transaction.description,
        transaction.amount,
        transaction.category,
        transaction.date,
      );
    }

    final csv = buildExportCsv(model.transactions);
    final summary = model.parseTransactionsCsv(csv);

    expect(summary.transactions, isEmpty);
    expect(summary.duplicateCount, sampleTransactions.length);
    expect(summary.rowErrors, isEmpty);
  });

  test('multiset dedupe imports the surplus copy of an existing row', () {
    final existing = Transaction(
      type: TransactionTyp.expense,
      description: 'Coffee',
      amount: 4.25,
      category: 'Eating Out',
      date: DateTime(2026, 4, 1),
    );

    final model = TransactionModel();
    model.addTransaction(
      existing.type,
      existing.description,
      existing.amount,
      existing.category,
      existing.date,
    );

    // File contains two identical copies of the existing row.
    final csv = buildExportCsv([existing, existing]);
    final summary = model.parseTransactionsCsv(csv);

    expect(summary.duplicateCount, 1);
    expect(summary.transactions.length, 1);
    expectTransactionEquals(summary.transactions.single, existing);
  });

  test('re-importing a three-decimal amount still detects the duplicate', () {
    // (3.005 * 100).round() and toStringAsFixed(2) round differently; the
    // dedupe key must use the export's rounding so re-import stays idempotent.
    final model = TransactionModel();
    model.addTransaction(
      TransactionTyp.expense,
      'Fuel',
      3.005,
      'Transport',
      DateTime(2026, 5, 1),
    );

    final csv = buildExportCsv(model.transactions);
    final summary = model.parseTransactionsCsv(csv);

    expect(summary.transactions, isEmpty);
    expect(summary.duplicateCount, 1);
  });

  test('dedupe ignores surrounding whitespace in text fields', () {
    // The parser trims fields; an existing description with a stray trailing
    // space must still match its own exported row.
    final model = TransactionModel();
    model.addTransaction(
      TransactionTyp.expense,
      'Lunch ',
      12.00,
      'Eating Out',
      DateTime(2026, 5, 2),
    );

    final csv = buildExportCsv(model.transactions);
    final summary = model.parseTransactionsCsv(csv);

    expect(summary.transactions, isEmpty);
    expect(summary.duplicateCount, 1);
  });

  test('parses an LF-only file the same as CRLF', () {
    final crlfCsv = buildExportCsv(sampleTransactions);
    final lfCsv = crlfCsv.replaceAll('\r\n', '\n');
    expect(lfCsv.contains('\r\n'), isFalse);

    final model = TransactionModel();
    final summary = model.parseTransactionsCsv(lfCsv);

    expect(summary.rowErrors, isEmpty);
    expect(summary.duplicateCount, 0);
    expect(summary.transactions.length, sampleTransactions.length);
    for (var i = 0; i < sampleTransactions.length; i++) {
      expectTransactionEquals(summary.transactions[i], sampleTransactions[i]);
    }
  });

  test('strips a leading UTF-8 BOM', () {
    final csv = '﻿${buildExportCsv(sampleTransactions)}';

    final model = TransactionModel();
    final summary = model.parseTransactionsCsv(csv);

    expect(summary.rowErrors, isEmpty);
    expect(summary.transactions.length, sampleTransactions.length);
  });

  test('accepts a lowercase header', () {
    final csv = const ListToCsvConverter().convert([
      ['date', 'type', 'category', 'description', 'amount'],
      ['2026-01-01', 'income', 'Salary', 'Paycheck', '1000.00'],
    ]);

    final model = TransactionModel();
    final summary = model.parseTransactionsCsv(csv);

    expect(summary.rowErrors, isEmpty);
    expect(summary.transactions.single.amount, 1000.00);
    expect(summary.transactions.single.type, TransactionTyp.income);
  });

  test('throws FormatException on empty content and a wrong header', () {
    final model = TransactionModel();

    expect(() => model.parseTransactionsCsv(''), throwsFormatException);

    final wrongHeader = const ListToCsvConverter().convert([
      ['When', 'Kind', 'Bucket', 'Note', 'Value'],
      ['2026-01-01', 'Income', 'Salary', 'Paycheck', '1000.00'],
    ]);
    expect(
      () => model.parseTransactionsCsv(wrongHeader),
      throwsFormatException,
    );
  });

  test('reports row errors while still importing valid rows', () {
    const csv = 'Date,Type,Category,Description,Amount\r\n'
        '2026-01-02,Income,Salary,Paycheck,1000.00\r\n'
        '"abc",Expense,Food,Bad date,5.00\r\n'
        '2026-01-03,Transfer,Food,Bad type,5.00\r\n'
        '2026-01-04,Expense,Food,Bad amount,xyz\r\n'
        '2026-01-05,Expense,Food,Only four columns\r\n'
        '2026-01-06,Expense,Groceries,Milk,3.50';

    final model = TransactionModel();
    final summary = model.parseTransactionsCsv(csv);

    expect(summary.transactions.length, 2);
    expect(summary.transactions[0].amount, 1000.00);
    expect(summary.transactions[1].amount, 3.50);

    expect(summary.rowErrors.length, 4);
    expect(summary.rowErrors[0], contains('Row 3'));
    expect(summary.rowErrors[0], contains('date'));
    expect(summary.rowErrors[1], contains('Row 4'));
    expect(summary.rowErrors[1], contains('type'));
    expect(summary.rowErrors[2], contains('Row 5'));
    expect(summary.rowErrors[2], contains('amount'));
    expect(summary.rowErrors[3], contains('Row 6'));
    expect(summary.rowErrors[3], contains('column'));
  });

  test('rejects impossible dates instead of rolling them over', () {
    // DateTime.tryParse normalizes '2026-02-30' to 2026-03-02; such rows must
    // become row errors, not import on a shifted date.
    const csv = 'Date,Type,Category,Description,Amount\r\n'
        '2026-02-30,Expense,Food,Bad day,5.00\r\n'
        '2026-13-05,Expense,Food,Bad month,5.00\r\n'
        '2026-01-15,Expense,Food,Valid,5.00';

    final model = TransactionModel();
    final summary = model.parseTransactionsCsv(csv);

    expect(summary.transactions.length, 1);
    expect(summary.transactions.single.description, 'Valid');
    expect(summary.rowErrors.length, 2);
    expect(summary.rowErrors[0], contains('Row 2'));
    expect(summary.rowErrors[1], contains('Row 3'));
  });

  test('rejects European decimal-comma amounts instead of mangling them', () {
    // Stripping the comma from '1.234,56' would import 1.23456 — wrong by
    // three orders of magnitude — so misplaced commas are row errors.
    final csv = const ListToCsvConverter().convert([
      ['Date', 'Type', 'Category', 'Description', 'Amount'],
      ['2026-01-01', 'Expense', 'Food', 'European format', '1.234,56'],
      ['2026-01-02', 'Expense', 'Food', 'Misplaced group', '12,34'],
      ['2026-01-03', 'Expense', 'Food', 'Valid grouped', '1,234.56'],
    ]);

    final model = TransactionModel();
    final summary = model.parseTransactionsCsv(csv);

    expect(summary.transactions.length, 1);
    expect(summary.transactions.single.amount, 1234.56);
    expect(summary.rowErrors.length, 2);
    expect(summary.rowErrors[0], contains('Row 2'));
    expect(summary.rowErrors[1], contains('Row 3'));
  });

  test('parses a currency-formatted amount like \$1,234.56', () {
    final csv = const ListToCsvConverter().convert([
      ['Date', 'Type', 'Category', 'Description', 'Amount'],
      ['2026-01-01', 'Income', 'Bonus', 'Year end', '\$1,234.56'],
    ]);

    final model = TransactionModel();
    final summary = model.parseTransactionsCsv(csv);

    expect(summary.rowErrors, isEmpty);
    expect(summary.transactions.single.amount, 1234.56);
  });

  test('importTransactions persists rows for a fresh model to load', () async {
    final model = TransactionModel();
    final summary = model.parseTransactionsCsv(buildExportCsv(sampleTransactions));

    await model.importTransactions(summary.transactions);
    expect(model.transactions.length, sampleTransactions.length);

    final restored = TransactionModel();
    await restored.getTransactions();

    expect(restored.transactions.length, sampleTransactions.length);
    final sorted = List<Transaction>.from(sampleTransactions)
      ..sort((a, b) => a.date.compareTo(b.date));
    final restoredSorted = List<Transaction>.from(restored.transactions)
      ..sort((a, b) => a.date.compareTo(b.date));
    for (var i = 0; i < sorted.length; i++) {
      expectTransactionEquals(restoredSorted[i], sorted[i]);
    }
  });

  test('importTransactions is a no-op on an empty list', () async {
    final model = TransactionModel();
    await model.importTransactions([]);

    expect(model.transactions, isEmpty);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(StorageKeys.transactions), isNull);
  });
}
