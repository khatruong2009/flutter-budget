import 'dart:convert';

import 'package:budget_app/storage/atomic_financial_store.dart';
import 'package:budget_app/storage/storage_keys.dart';
import 'package:budget_app/transaction.dart';
import 'package:budget_app/transaction_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('new transactions receive stable identity and timestamps', () {
    final first = Transaction(
      type: TransactionTyp.expense,
      description: 'Coffee',
      amount: 4.5,
      category: 'Dining',
      date: DateTime(2026, 7, 1),
    );
    final second = Transaction(
      type: TransactionTyp.expense,
      description: 'Coffee',
      amount: 4.5,
      category: 'Dining',
      date: DateTime(2026, 7, 1),
    );

    expect(first.id, isNotEmpty);
    expect(second.id, isNot(first.id));
    expect(first.createdAt, first.updatedAt);

    final restored = Transaction.fromJson(first.toJson());
    expect(restored.id, first.id);
    expect(restored.createdAt, first.createdAt);
    expect(restored.updatedAt, first.updatedAt);
  });

  test('legacy JSON gains identity with deterministic timestamp fallback', () {
    final legacy = <String, dynamic>{
      'type': 'expense',
      'description': 'Legacy',
      'amount': 12.0,
      'category': 'Other',
      'date': '2024-03-02T00:00:00.000',
      'recurringTemplateId': 'rec-legacy',
    };

    final transaction = Transaction.fromJson(legacy);

    expect(transaction.id, isNotEmpty);
    expect(transaction.createdAt, transaction.date);
    expect(transaction.updatedAt, transaction.date);
    expect(transaction.recurringTemplateId, 'rec-legacy');
  });

  test('loading legacy and duplicate IDs backfills and persists unique IDs',
      () async {
    final stored = [
      {
        'type': 'expense',
        'description': 'Legacy',
        'amount': 10.0,
        'category': 'Other',
        'date': '2026-01-01T00:00:00.000',
        'recurringTemplateId': null,
      },
      {
        'id': 'duplicate',
        'type': 'expense',
        'description': 'First duplicate',
        'amount': 20.0,
        'category': 'Other',
        'date': '2026-01-02T00:00:00.000',
        'recurringTemplateId': null,
      },
      {
        'id': 'duplicate',
        'type': 'expense',
        'description': 'Second duplicate',
        'amount': 30.0,
        'category': 'Other',
        'date': '2026-01-03T00:00:00.000',
        'recurringTemplateId': null,
      },
    ];
    SharedPreferences.setMockInitialValues({
      StorageKeys.transactions: jsonEncode(stored),
    });

    final model = TransactionModel();
    await model.getTransactions();

    final ids = model.transactions.map((transaction) => transaction.id).toSet();
    expect(ids, hasLength(3));

    final prefs = await SharedPreferences.getInstance();
    final persisted = jsonDecode(
      prefs.getString(StorageKeys.transactions)!,
    ) as List<dynamic>;
    expect(
      persisted.every(
        (item) =>
            (item as Map<String, dynamic>)['id'] is String &&
            item['createdAt'] is String &&
            item['updatedAt'] is String,
      ),
      isTrue,
    );

    final reloaded = TransactionModel();
    await reloaded.getTransactions();
    expect(
      reloaded.transactions.map((transaction) => transaction.id),
      orderedEquals(model.transactions.map((transaction) => transaction.id)),
    );
  });

  test('update is atomic and preserves identity and recurring metadata', () {
    final model = TransactionModel();
    model.addTransaction(
      TransactionTyp.expense,
      'Rent',
      1000,
      'Housing',
      DateTime(2026, 7, 1),
      recurringTemplateId: 'rent-template',
    );
    final original = model.transactions.single;

    final changed = model.updateTransaction(
      original.id,
      original.copyWith(
        description: 'Updated rent',
        amount: 1100,
      ),
    );

    expect(changed, isTrue);
    expect(model.transactions, hasLength(1));
    final updated = model.transactions.single;
    expect(updated.id, original.id);
    expect(updated.createdAt, original.createdAt);
    expect(updated.updatedAt.isAfter(original.updatedAt), isTrue);
    expect(updated.recurringTemplateId, 'rent-template');
    expect(updated.description, 'Updated rent');
    expect(updated.amount, 1100);
  });

  test('identical transactions can be deleted independently by ID', () {
    final model = TransactionModel();
    for (var i = 0; i < 2; i++) {
      model.addTransaction(
        TransactionTyp.expense,
        'Coffee',
        4.5,
        'Dining',
        DateTime(2026, 7, 1),
      );
    }
    final firstId = model.transactions.first.id;
    final secondId = model.transactions.last.id;

    expect(model.deleteTransactionById(firstId), isTrue);

    expect(model.transactions, hasLength(1));
    expect(model.transactions.single.id, secondId);
    expect(model.deleteTransactionById('missing'), isFalse);
    expect(model.transactions, hasLength(1));
  });

  test('an unreadable stored row is skipped without dropping readable rows',
      () async {
    final first = Transaction(
      id: 'first',
      type: TransactionTyp.expense,
      description: 'Groceries',
      amount: 42,
      category: 'Groceries',
      date: DateTime(2026, 8, 1),
    );
    final newest = Transaction(
      id: 'newest',
      type: TransactionTyp.expense,
      description: 'Hotel',
      amount: 280,
      category: 'Travel',
      date: DateTime(2026, 8, 10),
    );
    SharedPreferences.setMockInitialValues({
      StorageKeys.transactions: jsonEncode([
        first.toJson(),
        {'type': 'expense', 'description': 'no date or amount'},
        newest.toJson(),
      ]),
    });

    final model = TransactionModel();
    await model.getTransactions();

    // The bad row is skipped; every readable row survives, including the
    // newest one after it.
    expect(
      model.transactions.map((transaction) => transaction.id),
      orderedEquals(['first', 'newest']),
    );

    // Loading must not rewrite storage while a row was unreadable — the raw
    // rows stay on disk untouched.
    final snapshot = await AtomicFinancialStore.instance.read();
    expect(
      snapshot.sections[FinancialSections.transactions] as List,
      hasLength(3),
    );
  });

  test('model loads recovered atomic backup instead of stale legacy keys',
      () async {
    final original = Transaction(
      id: 'original',
      type: TransactionTyp.expense,
      description: 'Last known good',
      amount: 10,
      category: 'Other',
      date: DateTime(2026, 1, 1),
    );
    SharedPreferences.setMockInitialValues({
      StorageKeys.transactions: jsonEncode([original.toJson()]),
    });

    final model = TransactionModel();
    await model.getTransactions();
    await model.importTransactions([
      Transaction(
        id: 'newest',
        type: TransactionTyp.expense,
        description: 'Newest',
        amount: 20,
        category: 'Other',
        date: DateTime(2026, 1, 2),
      ),
    ]);

    final prefs = await SharedPreferences.getInstance();
    final primaryKey = prefs.getKeys().singleWhere(
          (key) =>
              key.startsWith('financial_store_v1') && !key.endsWith('_backup'),
        );
    await prefs.setString(primaryKey, 'malformed');

    final recovered = TransactionModel();
    await recovered.getTransactions();

    expect(recovered.transactions, hasLength(1));
    expect(recovered.transactions.single.id, original.id);
    final snapshot = await AtomicFinancialStore.instance.read();
    expect(
      (snapshot.sections[FinancialSections.transactions] as List),
      hasLength(1),
    );
  });
}
