import 'package:budget_app/insights/insight_engine.dart';
import 'package:budget_app/savings_goal.dart';
import 'package:budget_app/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const engine = InsightEngine();
  final now = DateTime(2026, 7, 10);

  Transaction expense(
    double amount,
    DateTime date, {
    String description = 'Purchase',
    String category = 'General',
    String? recurringTemplateId,
  }) =>
      Transaction(
        type: TransactionTyp.expense,
        description: description,
        amount: amount,
        category: category,
        date: date,
        recurringTemplateId: recurringTemplateId,
      );

  Transaction income(double amount, DateTime date) => Transaction(
        type: TransactionTyp.income,
        description: 'Paycheck',
        amount: amount,
        category: 'Salary',
        date: date,
      );

  List<LocalInsight> generate(
    List<Transaction> transactions, {
    Map<String, double> budgets = const {},
    List<SavingsGoal> goals = const [],
    Set<String> excludedIds = const {},
    int limit = 3,
  }) =>
      engine.generate(
        transactions: transactions,
        categoryBudgetLimits: budgets,
        savingsGoals: goals,
        selectedMonth: DateTime(2026, 7),
        now: now,
        excludedIds: excludedIds,
        limit: limit,
      );

  test('flags category spending that is well ahead of calendar pace', () {
    final insights = generate(
      [expense(80, DateTime(2026, 7, 5), category: 'Groceries')],
      budgets: const {'Groceries': 100},
    );

    final insight =
        insights.singleWhere((item) => item.type == InsightType.budgetPace);
    expect(insight.severity, InsightSeverity.warning);
    expect(insight.explanation, contains('80%'));
    expect(insight.supportingValues['usedRatio'], 0.8);
  });

  test('detects duplicate transactions with an explainable stable id', () {
    final transactions = [
      expense(
        24.5,
        DateTime(2026, 7, 4, 9),
        description: 'Corner Cafe',
        category: 'Eating Out',
      ),
      expense(
        24.5,
        DateTime(2026, 7, 4, 18),
        description: 'Corner Cafe',
        category: 'Eating Out',
      ),
    ];

    final first = generate(transactions).single;
    final second = generate(transactions).single;

    expect(first.type, InsightType.possibleDuplicate);
    expect(first.id, second.id);
    expect(first.explanation, contains('same amount and date'));
  });

  test('detects a changed recurring amount', () {
    final insights = generate([
      expense(
        100,
        DateTime(2026, 6, 2),
        description: 'Internet',
        recurringTemplateId: 'internet',
      ),
      expense(
        120,
        DateTime(2026, 7, 2),
        description: 'Internet',
        recurringTemplateId: 'internet',
      ),
    ]);

    expect(
      insights.any((item) => item.type == InsightType.recurringAmountChange),
      isTrue,
    );
  });

  test('flags three consecutive negative cash-flow months', () {
    final transactions = <Transaction>[
      for (final month in [5, 6, 7]) ...[
        income(1000, DateTime(2026, month, 1)),
        expense(1200, DateTime(2026, month, 2)),
      ],
    ];

    final insight = generate(transactions).first;
    expect(insight.type, InsightType.negativeCashFlow);
    expect(insight.severity, InsightSeverity.urgent);
  });

  test('flags a goal materially behind its elapsed schedule', () {
    final goal = SavingsGoal(
      id: 'emergency',
      name: 'Emergency fund',
      targetAmount: 1000,
      currentAmount: 100,
      createdAt: DateTime(2026, 1, 1),
      targetDate: DateTime(2026, 10, 1),
    );

    final insight = generate(const [], goals: [goal]).single;
    expect(insight.type, InsightType.goalBehindSchedule);
    expect(insight.headline, contains('Emergency fund'));
  });

  test('honors exclusions and requested result limit', () {
    final transactions = [
      expense(40, DateTime(2026, 7, 3), description: 'Cafe'),
      expense(40, DateTime(2026, 7, 3), description: 'Cafe'),
      expense(90, DateTime(2026, 7, 5), category: 'Groceries'),
    ];
    final all = generate(
      transactions,
      budgets: const {'Groceries': 100},
      limit: 10,
    );
    expect(all.length, 2);

    final filtered = generate(
      transactions,
      budgets: const {'Groceries': 100},
      excludedIds: {all.first.id},
      limit: 1,
    );
    expect(filtered, hasLength(1));
    expect(filtered.single.id, isNot(all.first.id));
  });

  test('does not create change insights from sparse data', () {
    final insights = generate([
      expense(100, DateTime(2026, 6, 2)),
      expense(200, DateTime(2026, 7, 2)),
    ]);

    expect(
      insights.any(
        (item) => item.type == InsightType.monthlySpendingChange,
      ),
      isFalse,
    );
  });
}
