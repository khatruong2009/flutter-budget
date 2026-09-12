import 'dart:convert';
import 'dart:io';

import 'package:budget_app/storage/atomic_financial_store.dart';
import 'package:budget_app/storage/storage_keys.dart';
import 'package:budget_app/transaction.dart';
import 'package:budget_app/transaction_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await AtomicFinancialStore.instance.resetForTesting();
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

    final persisted = (await AtomicFinancialStore.instance.read())
        .sections[FinancialSections.transactions] as List<dynamic>;
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

  test('update is atomic and preserves identity and recurring metadata',
      () async {
    final model = TransactionModel();
    await model.addTransaction(
      TransactionTyp.expense,
      'Rent',
      1000,
      'Housing',
      DateTime(2026, 7, 1),
      recurringTemplateId: 'rent-template',
    );
    final original = model.transactions.single;

    final changed = await model.updateTransaction(
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

  test('identical transactions can be deleted independently by ID', () async {
    final model = TransactionModel();
    for (var i = 0; i < 2; i++) {
      await model.addTransaction(
        TransactionTyp.expense,
        'Coffee',
        4.5,
        'Dining',
        DateTime(2026, 7, 1),
      );
    }
    final firstId = model.transactions.first.id;
    final secondId = model.transactions.last.id;

    expect(await model.deleteTransactionById(firstId), isTrue);

    expect(model.transactions, hasLength(1));
    expect(model.transactions.single.id, secondId);
    expect(await model.deleteTransactionById('missing'), isFalse);
    expect(model.transactions, hasLength(1));
  });

  test('a failed write keeps the row, flags it unsaved, and retry heals it',
      () async {
    final directory = await Directory.systemTemp.createTemp('budgie_identity');
    await AtomicFinancialStore.instance.resetForTesting(directory: directory);
    final model = TransactionModel();
    await model.addTransaction(
      TransactionTyp.expense,
      'Groceries',
      42,
      'Groceries',
      DateTime(2026, 7, 1),
    );
    expect(model.hasUnsavedChanges, isFalse);

    // Make the store directory unwritable, then add a row.
    await directory.delete(recursive: true);
    await File(directory.path).writeAsString('blocks the directory');
    var notifications = 0;
    model.addListener(() => notifications++);

    final saved = await model.addTransaction(
      TransactionTyp.expense,
      'Coffee',
      4.5,
      'Dining',
      DateTime(2026, 7, 2),
    );

    expect(saved, isFalse);
    expect(model.transactions, hasLength(2));
    expect(model.hasUnsavedChanges, isTrue);
    expect(model.unsavedSections, contains(FinancialSections.transactions));
    expect(model.lastSaveError, isNotNull);
    expect(notifications, greaterThanOrEqualTo(2));

    // Storage comes back: a retry lands the pending change and clears it.
    await File(directory.path).delete();
    expect(await model.retryPendingSaves(), isTrue);
    expect(model.hasUnsavedChanges, isFalse);
    expect(model.lastSaveError, isNull);

    await AtomicFinancialStore.instance.resetForTesting(directory: directory);
    final reloaded = TransactionModel();
    await reloaded.getTransactions();
    expect(
      reloaded.transactions.map((transaction) => transaction.description),
      orderedEquals(['Groceries', 'Coffee']),
    );
  });

  test('a later successful save also carries earlier unsaved sections',
      () async {
    final directory = await Directory.systemTemp.createTemp('budgie_identity');
    await AtomicFinancialStore.instance.resetForTesting(directory: directory);
    final model = TransactionModel();
    await directory.delete(recursive: true);
    await File(directory.path).writeAsString('blocks the directory');

    await model.setCategoryBudgetLimit('Groceries', 300);
    expect(model.unsavedSections,
        contains(FinancialSections.categoryBudgetLimits));

    await File(directory.path).delete();
    final saved = await model.addTransaction(
      TransactionTyp.expense,
      'Coffee',
      4.5,
      'Dining',
      DateTime(2026, 7, 2),
    );

    expect(saved, isTrue);
    expect(model.hasUnsavedChanges, isFalse);
    await AtomicFinancialStore.instance.resetForTesting(directory: directory);
    final reloaded = TransactionModel();
    await reloaded.getTransactions();
    expect(reloaded.getCategoryBudgetLimit('Groceries'), 300);
    expect(reloaded.transactions.single.description, 'Coffee');
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
    final directory = await Directory.systemTemp.createTemp('budgie_identity');
    await AtomicFinancialStore.instance.resetForTesting(directory: directory);

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

    await File('${directory.path}/${AtomicFinancialStore.primaryFileName}')
        .writeAsString('malformed');
    // Relaunch: memory is gone, only the files remain.
    await AtomicFinancialStore.instance.resetForTesting(directory: directory);

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
