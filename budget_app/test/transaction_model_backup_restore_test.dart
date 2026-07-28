import 'package:budget_app/net_worth_entry.dart';
import 'package:budget_app/savings_goal.dart';
import 'package:budget_app/storage/atomic_financial_store.dart';
import 'package:budget_app/transaction.dart';
import 'package:budget_app/transaction_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void expectTransactionEquals(Transaction actual, Transaction expected) {
  expect(actual.id, expected.id);
  expect(actual.type, expected.type);
  expect(actual.description, expected.description);
  expect(actual.amount, expected.amount);
  expect(actual.category, expected.category);
  expect(actual.date, expected.date);
  expect(actual.recurringTemplateId, expected.recurringTemplateId);
  expect(actual.createdAt, expected.createdAt);
  expect(actual.updatedAt, expected.updatedAt);
}

void expectNetWorthEntryEquals(NetWorthEntry actual, NetWorthEntry expected) {
  expect(actual.id, expected.id);
  expect(actual.name, expected.name);
  expect(actual.type, expected.type);
  expect(actual.createdAt, expected.createdAt);
  expect(actual.snapshots.length, expected.snapshots.length);
  for (var i = 0; i < expected.snapshots.length; i++) {
    expect(actual.snapshots[i].recordedAt, expected.snapshots[i].recordedAt);
    expect(actual.snapshots[i].amount, expected.snapshots[i].amount);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  final restoredTransactions = <Transaction>[
    Transaction(
      type: TransactionTyp.income,
      description: 'New Salary',
      amount: 2500.0,
      category: 'Income',
      date: DateTime(2026, 3, 1),
    ),
    Transaction(
      type: TransactionTyp.expense,
      description: 'New Rent',
      amount: 1500.0,
      category: 'Housing',
      date: DateTime(2026, 3, 2),
      recurringTemplateId: 'rec-9',
    ),
  ];

  final restoredNetWorth = <NetWorthEntry>[
    NetWorthEntry(
      id: 'asset-new',
      name: 'Brokerage',
      type: NetWorthEntryType.asset,
      createdAt: DateTime(2026, 2, 1),
      snapshots: [
        NetWorthSnapshot(recordedAt: DateTime(2026, 2, 28), amount: 8000.0),
      ],
    ),
  ];

  final restoredLimits = <String, double>{
    'Groceries': 650.0,
    'Transport': 250.0,
    // A non-positive limit must be dropped on restore, mirroring load.
    'Dropped': 0.0,
  };

  final restoredGoals = <SavingsGoal>[
    SavingsGoal(
      id: 'goal-new',
      name: 'House',
      targetAmount: 50000.0,
      currentAmount: 12000.0,
      targetDate: DateTime(2028, 1, 1),
      createdAt: DateTime(2026, 1, 1),
    ),
  ];

  Future<void> seed(TransactionModel model) async {
    model.addTransaction(
      TransactionTyp.income,
      'Old Salary',
      1000.0,
      'Income',
      DateTime(2025, 1, 1),
    );
    await model.addNetWorthEntry(
      name: 'Old Asset',
      type: NetWorthEntryType.asset,
      amount: 100.0,
      recordedAt: DateTime(2025, 1, 15),
    );
    await model.setCategoryBudgetLimit('OldCat', 100.0);
    await model.addSavingsGoal(
      name: 'Old Goal',
      targetAmount: 500.0,
      targetDate: DateTime(2025, 12, 31),
    );
  }

  test('restore replaces all owned data and persists it', () async {
    final model = TransactionModel();
    await seed(model);
    final snapshotBeforeRestore = await AtomicFinancialStore.instance.read();

    await model.restoreFromBackup(
      transactions: restoredTransactions,
      netWorthEntries: restoredNetWorth,
      categoryBudgetLimits: restoredLimits,
      savingsGoals: restoredGoals,
    );
    final snapshotAfterRestore = await AtomicFinancialStore.instance.read();

    expect(
      snapshotAfterRestore.revision,
      snapshotBeforeRestore.revision + 1,
      reason: 'all TransactionModel-owned sections commit in one revision',
    );
    expect(
      snapshotAfterRestore.sections[FinancialSections.transactions],
      restoredTransactions.map((transaction) => transaction.toJson()).toList(),
    );
    expect(
      snapshotAfterRestore.sections[FinancialSections.netWorthEntries],
      restoredNetWorth.map((entry) => entry.toJson()).toList(),
    );
    expect(
      snapshotAfterRestore.sections[FinancialSections.categoryBudgetLimits],
      {'Groceries': 650.0, 'Transport': 250.0},
    );
    expect(
      snapshotAfterRestore.sections[FinancialSections.savingsGoals],
      restoredGoals.map((goal) => goal.toJson()).toList(),
    );

    // In-memory state is the restored set; the old data is gone.
    expect(model.transactions.length, restoredTransactions.length);
    expect(
      model.transactions.any((t) => t.description == 'Old Salary'),
      isFalse,
    );
    for (var i = 0; i < restoredTransactions.length; i++) {
      expectTransactionEquals(model.transactions[i], restoredTransactions[i]);
    }

    expect(model.netWorthEntries.length, restoredNetWorth.length);
    expectNetWorthEntryEquals(
        model.netWorthEntries.single, restoredNetWorth.single);

    expect(model.categoryBudgetLimits, <String, double>{
      'Groceries': 650.0,
      'Transport': 250.0,
    });

    expect(model.savingsGoals, restoredGoals);

    // A fresh model loads the restored data from persistence.
    final reloaded = TransactionModel();
    await reloaded.getTransactions();

    expect(reloaded.transactions.length, restoredTransactions.length);
    for (var i = 0; i < restoredTransactions.length; i++) {
      expectTransactionEquals(
          reloaded.transactions[i], restoredTransactions[i]);
    }
    expect(reloaded.netWorthEntries.length, restoredNetWorth.length);
    expectNetWorthEntryEquals(
      reloaded.netWorthEntries.single,
      restoredNetWorth.single,
    );
    expect(reloaded.categoryBudgetLimits, <String, double>{
      'Groceries': 650.0,
      'Transport': 250.0,
    });
    expect(reloaded.savingsGoals, restoredGoals);
  });

  test('restore with an empty backup wipes everything and persists empty',
      () async {
    final model = TransactionModel();
    await seed(model);

    await model.restoreFromBackup(
      transactions: const [],
      netWorthEntries: const [],
      categoryBudgetLimits: const {},
      savingsGoals: const [],
    );

    expect(model.transactions, isEmpty);
    expect(model.netWorthEntries, isEmpty);
    expect(model.categoryBudgetLimits, isEmpty);
    expect(model.savingsGoals, isEmpty);

    final reloaded = TransactionModel();
    await reloaded.getTransactions();

    expect(reloaded.transactions, isEmpty);
    expect(reloaded.netWorthEntries, isEmpty);
    expect(reloaded.categoryBudgetLimits, isEmpty);
    expect(reloaded.savingsGoals, isEmpty);
  });
}
