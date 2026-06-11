import 'dart:convert';

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

  test('category budget limits persist and compute monthly progress', () async {
    final model = TransactionModel();

    await model.setCategoryBudgetLimit('Eating Out', 400);
    model.addTransaction(
      TransactionTyp.expense,
      'Dinner',
      125,
      'Eating Out',
      DateTime(2026, 6, 8),
    );
    model.addTransaction(
      TransactionTyp.expense,
      'Taxi',
      40,
      'Transportation',
      DateTime(2026, 6, 8),
    );

    final progress = model.getCategoryBudgetProgressForMonth(
      DateTime(2026, 6),
    );

    expect(progress.single.category, 'Eating Out');
    expect(progress.single.spent, 125);
    expect(progress.single.limit, 400);
    expect(progress.single.remaining, 275);

    final prefs = await SharedPreferences.getInstance();
    expect(
      jsonDecode(prefs.getString(StorageKeys.categoryBudgetLimits)!),
      {'Eating Out': 400.0},
    );
  });

  test('category budget limits load from preferences', () async {
    SharedPreferences.setMockInitialValues({
      StorageKeys.categoryBudgetLimits: jsonEncode({
        'Groceries': 600,
        'Ignored': 0,
      }),
    });

    final model = TransactionModel();
    await model.getTransactions();

    expect(model.getCategoryBudgetLimit('Groceries'), 600);
    expect(model.getCategoryBudgetLimit('Ignored'), isNull);
  });

  test('year-over-year comparison summarizes totals and categories', () {
    final model = TransactionModel();

    model.addTransaction(
      TransactionTyp.expense,
      'Rent',
      1200,
      'Housing',
      DateTime(2025, 1, 5),
    );
    model.addTransaction(
      TransactionTyp.expense,
      'Groceries',
      200,
      'Groceries',
      DateTime(2025, 1, 10),
    );
    model.addTransaction(
      TransactionTyp.expense,
      'Rent',
      1300,
      'Housing',
      DateTime(2026, 1, 5),
    );
    model.addTransaction(
      TransactionTyp.expense,
      'Dinner',
      300,
      'Eating Out',
      DateTime(2026, 1, 15),
    );

    final comparison = model.getYearOverYearComparison(DateTime(2026, 1));

    expect(comparison.currentExpenses, 1600);
    expect(comparison.previousYearExpenses, 1400);
    expect(comparison.difference, 200);
    expect(comparison.percentChange, closeTo(14.285, 0.001));
    expect(comparison.currentCategoryExpenses['Housing'], 1300);
    expect(comparison.previousYearCategoryExpenses['Groceries'], 200);
    expect(comparison.categories.first, 'Housing');
  });

  test('savings goals persist and track allocation progress', () async {
    final model = TransactionModel();

    await model.addSavingsGoal(
      name: 'Vacation',
      targetAmount: 5000,
      targetDate: DateTime(2026, 12, 1),
    );

    final goal = model.savingsGoals.single;
    await model.allocateToSavingsGoal(goal.id, 1250);

    expect(model.savingsGoals.single.currentAmount, 1250);
    expect(model.savingsGoals.single.progress, 0.25);
    expect(model.savingsGoals.single.isCompleted, isFalse);

    await model.allocateToSavingsGoal(goal.id, 3750);

    expect(model.savingsGoals.single.isCompleted, isTrue);
    expect(model.savingsGoals.single.completedAt, isNotNull);

    final restored = TransactionModel();
    await restored.getTransactions();

    expect(restored.savingsGoals.single.name, 'Vacation');
    expect(restored.savingsGoals.single.currentAmount, 5000);
    expect(restored.savingsGoals.single.isCompleted, isTrue);
  });
}
