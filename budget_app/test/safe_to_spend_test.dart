import 'package:budget_app/recurring_transaction.dart';
import 'package:budget_app/safe_to_spend.dart';
import 'package:budget_app/savings_goal.dart';
import 'package:budget_app/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const calculator = SafeToSpendCalculator();
  final month = DateTime(2026, 7);
  final asOf = DateTime(2026, 7, 15);

  test('reserves upcoming bills and the unspent part of category budgets', () {
    final result = calculator.calculate(
      transactions: [
        Transaction(
          type: TransactionTyp.income,
          description: 'Paycheck',
          amount: 3000,
          category: 'Salary',
          date: DateTime(2026, 7, 1),
        ),
        Transaction(
          type: TransactionTyp.expense,
          description: 'Market',
          amount: 200,
          category: 'Groceries',
          date: DateTime(2026, 7, 4),
        ),
      ],
      recurringTransactions: [
        RecurringTransaction(
          type: TransactionTyp.expense,
          description: 'Grocery delivery',
          amount: 100,
          category: 'Groceries',
          pattern: RecurrencePattern.monthly,
          startDate: DateTime(2026, 7, 20),
          nextOccurrence: DateTime(2026, 7, 20),
          dayOfMonth: 20,
        ),
        RecurringTransaction(
          type: TransactionTyp.expense,
          description: 'Phone',
          amount: 80,
          category: 'General',
          pattern: RecurrencePattern.monthly,
          startDate: DateTime(2026, 7, 22),
          nextOccurrence: DateTime(2026, 7, 22),
          dayOfMonth: 22,
        ),
      ],
      categoryBudgetLimits: const {'Groceries': 500},
      savingsGoals: const [],
      month: month,
      asOf: asOf,
    );

    expect(result.actualIncome, 3000);
    expect(result.actualExpenses, 200);
    expect(result.upcomingRecurringExpenses, 180);
    expect(result.flexibleBudgetReserve, 200);
    expect(result.safeToSpend, 2420);
    expect(result.daysRemaining, 17);
  });

  test('expected recurring income can be included or excluded', () {
    final recurringIncome = RecurringTransaction(
      type: TransactionTyp.income,
      description: 'Paycheck',
      amount: 1500,
      category: 'Salary',
      pattern: RecurrencePattern.biweekly,
      startDate: DateTime(2026, 7, 20),
      nextOccurrence: DateTime(2026, 7, 20),
      dayOfWeek: DateTime.monday,
    );

    final included = calculator.calculate(
      transactions: const [],
      recurringTransactions: [recurringIncome],
      categoryBudgetLimits: const {},
      savingsGoals: const [],
      month: month,
      asOf: asOf,
    );
    final excluded = calculator.calculate(
      transactions: const [],
      recurringTransactions: [recurringIncome],
      categoryBudgetLimits: const {},
      savingsGoals: const [],
      month: month,
      asOf: asOf,
      includeExpectedIncome: false,
    );

    expect(included.expectedIncome, 1500);
    expect(excluded.expectedIncome, 0);
  });

  test('reserves suggested contributions for active savings goals', () {
    final result = calculator.calculate(
      transactions: [
        Transaction(
          type: TransactionTyp.income,
          description: 'Pay',
          amount: 1000,
          category: 'Salary',
          date: DateTime(2026, 7, 1),
        ),
      ],
      recurringTransactions: const [],
      categoryBudgetLimits: const {},
      savingsGoals: [
        SavingsGoal(
          name: 'Emergency fund',
          targetAmount: 600,
          currentAmount: 0,
          targetDate: DateTime(2026, 12, 1),
          createdAt: DateTime(2026, 7, 1),
        ),
      ],
      month: month,
      asOf: asOf,
    );

    expect(result.plannedGoalContributions, greaterThan(0));
    expect(result.safeToSpend, lessThan(1000));
  });

  test('does not count future-dated transactions as actual', () {
    final result = calculator.calculate(
      transactions: [
        Transaction(
          type: TransactionTyp.expense,
          description: 'Future',
          amount: 250,
          category: 'General',
          date: DateTime(2026, 7, 25),
        ),
      ],
      recurringTransactions: const [],
      categoryBudgetLimits: const {},
      savingsGoals: const [],
      month: month,
      asOf: asOf,
    );

    expect(result.actualExpenses, 0);
  });
}
