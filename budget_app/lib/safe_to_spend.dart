import 'recurring_transaction.dart';
import 'savings_goal.dart';
import 'transaction.dart';

/// An explainable, forward-looking view of what remains available in [month].
class SafeToSpendBreakdown {
  final DateTime month;
  final DateTime asOf;
  final double actualIncome;
  final double expectedIncome;
  final double actualExpenses;
  final double upcomingRecurringExpenses;
  final double flexibleBudgetReserve;
  final double plannedGoalContributions;
  final int daysRemaining;

  const SafeToSpendBreakdown({
    required this.month,
    required this.asOf,
    required this.actualIncome,
    required this.expectedIncome,
    required this.actualExpenses,
    required this.upcomingRecurringExpenses,
    required this.flexibleBudgetReserve,
    required this.plannedGoalContributions,
    required this.daysRemaining,
  });

  double get projectedIncome => actualIncome + expectedIncome;

  double get totalReserved =>
      upcomingRecurringExpenses +
      flexibleBudgetReserve +
      plannedGoalContributions;

  double get safeToSpend => projectedIncome - actualExpenses - totalReserved;

  double get dailyAllowance =>
      daysRemaining <= 0 ? 0 : safeToSpend / daysRemaining;
}

/// Calculates "safe to spend" without IO so the app, widget, and tests can
/// share one definition.
class SafeToSpendCalculator {
  const SafeToSpendCalculator();

  SafeToSpendBreakdown calculate({
    required List<Transaction> transactions,
    required List<RecurringTransaction> recurringTransactions,
    required Map<String, double> categoryBudgetLimits,
    required List<SavingsGoal> savingsGoals,
    required DateTime month,
    required DateTime asOf,
    bool includeExpectedIncome = true,
    bool reserveSuggestedGoalContributions = true,
  }) {
    final normalizedMonth = DateTime(month.year, month.month);
    final monthEnd = DateTime(month.year, month.month + 1, 0);
    final effectiveAsOf = _clampDate(asOf, normalizedMonth, monthEnd);

    var actualIncome = 0.0;
    var actualExpenses = 0.0;
    final actualCategoryExpenses = <String, double>{};

    for (final transaction in transactions) {
      if (!_isInMonth(transaction.date, normalizedMonth) ||
          transaction.date.isAfter(effectiveAsOf)) {
        continue;
      }
      if (transaction.type == TransactionTyp.income) {
        actualIncome += transaction.amount;
      } else {
        actualExpenses += transaction.amount;
        actualCategoryExpenses.update(
          transaction.category,
          (value) => value + transaction.amount,
          ifAbsent: () => transaction.amount,
        );
      }
    }

    var expectedIncome = 0.0;
    var upcomingRecurringExpenses = 0.0;
    final upcomingByCategory = <String, double>{};
    for (final recurring in recurringTransactions) {
      if (!recurring.isActive) continue;
      for (final occurrence
          in _remainingOccurrences(recurring, effectiveAsOf, monthEnd)) {
        if (!_isInMonth(occurrence, normalizedMonth)) continue;
        if (recurring.type == TransactionTyp.income) {
          if (includeExpectedIncome) expectedIncome += recurring.amount;
        } else {
          upcomingRecurringExpenses += recurring.amount;
          upcomingByCategory.update(
            recurring.category,
            (value) => value + recurring.amount,
            ifAbsent: () => recurring.amount,
          );
        }
      }
    }

    var flexibleBudgetReserve = 0.0;
    for (final entry in categoryBudgetLimits.entries) {
      if (entry.value <= 0) continue;
      final alreadySpent = actualCategoryExpenses[entry.key] ?? 0;
      final upcoming = upcomingByCategory[entry.key] ?? 0;
      final remaining = entry.value - alreadySpent - upcoming;
      if (remaining > 0) flexibleBudgetReserve += remaining;
    }

    var plannedGoalContributions = 0.0;
    if (reserveSuggestedGoalContributions &&
        !_isBeforeMonth(normalizedMonth, DateTime(asOf.year, asOf.month))) {
      for (final goal in savingsGoals) {
        if (!goal.isCompleted) {
          plannedGoalContributions += goal.suggestedMonthlyContribution;
        }
      }
    }

    final daysRemaining = _isInMonth(asOf, normalizedMonth)
        ? monthEnd
                .difference(DateTime(asOf.year, asOf.month, asOf.day))
                .inDays +
            1
        : asOf.isBefore(normalizedMonth)
            ? monthEnd.day
            : 0;

    return SafeToSpendBreakdown(
      month: normalizedMonth,
      asOf: effectiveAsOf,
      actualIncome: actualIncome,
      expectedIncome: expectedIncome,
      actualExpenses: actualExpenses,
      upcomingRecurringExpenses: upcomingRecurringExpenses,
      flexibleBudgetReserve: flexibleBudgetReserve,
      plannedGoalContributions: plannedGoalContributions,
      daysRemaining: daysRemaining,
    );
  }

  Iterable<DateTime> _remainingOccurrences(
    RecurringTransaction recurring,
    DateTime asOf,
    DateTime monthEnd,
  ) sync* {
    var occurrence = recurring.nextOccurrence;
    var guard = 0;
    while (!occurrence.isAfter(monthEnd) && guard < 400) {
      if (occurrence.isAfter(asOf)) yield occurrence;
      occurrence = _nextOccurrence(recurring, occurrence);
      guard++;
    }
  }

  DateTime _nextOccurrence(
    RecurringTransaction recurring,
    DateTime occurrence,
  ) {
    switch (recurring.pattern) {
      case RecurrencePattern.weekly:
        return occurrence.add(const Duration(days: 7));
      case RecurrencePattern.biweekly:
        return occurrence.add(const Duration(days: 14));
      case RecurrencePattern.monthly:
        final desiredDay = recurring.dayOfMonth ?? occurrence.day;
        final nextMonth = DateTime(occurrence.year, occurrence.month + 1);
        final lastDay = DateTime(nextMonth.year, nextMonth.month + 1, 0).day;
        return DateTime(
          nextMonth.year,
          nextMonth.month,
          desiredDay.clamp(1, lastDay),
        );
    }
  }

  DateTime _clampDate(DateTime value, DateTime start, DateTime end) {
    final date = DateTime(value.year, value.month, value.day);
    if (date.isBefore(start)) return start.subtract(const Duration(days: 1));
    if (date.isAfter(end)) return end;
    return date;
  }

  bool _isInMonth(DateTime value, DateTime month) =>
      value.year == month.year && value.month == month.month;

  bool _isBeforeMonth(DateTime a, DateTime b) =>
      a.year < b.year || (a.year == b.year && a.month < b.month);
}
