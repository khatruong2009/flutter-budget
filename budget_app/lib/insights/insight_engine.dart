import '../savings_goal.dart';
import '../transaction.dart';

enum InsightType {
  budgetPace,
  monthlySpendingChange,
  unusualTransaction,
  savingsRateTrend,
  recurringAmountChange,
  consistentlyUnderBudget,
  goalBehindSchedule,
  negativeCashFlow,
  possibleDuplicate,
}

enum InsightSeverity { info, positive, warning, urgent }

class LocalInsight {
  final String id;
  final InsightType type;
  final InsightSeverity severity;
  final String headline;
  final String explanation;
  final Map<String, double> supportingValues;
  final String suggestedAction;
  final DateTime generatedDate;

  const LocalInsight({
    required this.id,
    required this.type,
    required this.severity,
    required this.headline,
    required this.explanation,
    required this.supportingValues,
    required this.suggestedAction,
    required this.generatedDate,
  });
}

/// Produces explainable insights using only data already held on the device.
///
/// The engine has no I/O and no clock dependency, which keeps every result
/// reproducible in tests and makes it safe to run during a widget build.
class InsightEngine {
  const InsightEngine();

  List<LocalInsight> generate({
    required List<Transaction> transactions,
    required Map<String, double> categoryBudgetLimits,
    required List<SavingsGoal> savingsGoals,
    required DateTime selectedMonth,
    required DateTime now,
    Set<String> excludedIds = const {},
    int limit = 3,
  }) {
    if (limit <= 0) return const [];

    final normalizedMonth = DateTime(selectedMonth.year, selectedMonth.month);
    final generatedDate = DateTime(now.year, now.month, now.day);
    final candidates = <LocalInsight>[
      ..._possibleDuplicates(transactions, normalizedMonth, generatedDate),
      ..._budgetPace(
        transactions,
        categoryBudgetLimits,
        normalizedMonth,
        now,
        generatedDate,
      ),
      ..._goalProgress(savingsGoals, now, generatedDate),
      ..._recurringChanges(transactions, generatedDate),
      ..._negativeCashFlow(transactions, normalizedMonth, generatedDate),
      ..._monthlySpendingChange(
        transactions,
        normalizedMonth,
        generatedDate,
      ),
      ..._unusualTransactions(
        transactions,
        normalizedMonth,
        generatedDate,
      ),
      ..._savingsRateTrend(transactions, normalizedMonth, generatedDate),
      ..._consistentlyUnderBudget(
        transactions,
        categoryBudgetLimits,
        normalizedMonth,
        generatedDate,
      ),
    ]..removeWhere((insight) => excludedIds.contains(insight.id));

    const severityRank = {
      InsightSeverity.urgent: 0,
      InsightSeverity.warning: 1,
      InsightSeverity.positive: 2,
      InsightSeverity.info: 3,
    };
    candidates.sort((a, b) {
      final severity =
          severityRank[a.severity]!.compareTo(severityRank[b.severity]!);
      if (severity != 0) return severity;
      return a.id.compareTo(b.id);
    });
    return List.unmodifiable(candidates.take(limit));
  }

  Iterable<LocalInsight> _budgetPace(
    List<Transaction> transactions,
    Map<String, double> limits,
    DateTime month,
    DateTime now,
    DateTime generatedDate,
  ) sync* {
    if (limits.isEmpty || !_sameMonth(month, now)) return;

    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final elapsedRatio = now.day.clamp(1, daysInMonth) / daysInMonth;
    for (final entry in limits.entries) {
      if (entry.value <= 0) continue;
      final spent = _expenses(transactions, month)
          .where((item) => item.category == entry.key)
          .fold(0.0, (sum, item) => sum + item.amount);
      final usedRatio = spent / entry.value;
      if (spent < 25 || usedRatio < 0.65 || usedRatio <= elapsedRatio + 0.15) {
        continue;
      }
      final usedPercent = (usedRatio * 100).round();
      final monthPercent = (elapsedRatio * 100).round();
      yield LocalInsight(
        id: 'budget-pace:${_slug(entry.key)}:${month.year}-${month.month}',
        type: InsightType.budgetPace,
        severity:
            usedRatio >= 1 ? InsightSeverity.urgent : InsightSeverity.warning,
        headline: '${entry.key} is ahead of budget pace',
        explanation:
            'You have used $usedPercent% of this budget, while $monthPercent% of the month has passed.',
        supportingValues: {
          'spent': spent,
          'limit': entry.value,
          'usedRatio': usedRatio,
        },
        suggestedAction: 'Review ${entry.key.toLowerCase()} transactions',
        generatedDate: generatedDate,
      );
    }
  }

  Iterable<LocalInsight> _monthlySpendingChange(
    List<Transaction> transactions,
    DateTime month,
    DateTime generatedDate,
  ) sync* {
    final previous = DateTime(month.year, month.month - 1);
    final currentExpenses = _expenses(transactions, month).toList();
    final previousExpenses = _expenses(transactions, previous).toList();
    if (currentExpenses.length < 3 || previousExpenses.length < 3) return;

    final currentTotal = _sum(currentExpenses);
    final previousTotal = _sum(previousExpenses);
    if (previousTotal < 50) return;
    final change = (currentTotal - previousTotal) / previousTotal;
    if (change.abs() < 0.2) return;

    final percent = (change.abs() * 100).round();
    final increased = change > 0;
    yield LocalInsight(
      id: 'monthly-change:${month.year}-${month.month}',
      type: InsightType.monthlySpendingChange,
      severity: increased ? InsightSeverity.warning : InsightSeverity.positive,
      headline: 'Spending is $percent% ${increased ? 'higher' : 'lower'}',
      explanation:
          'This compares expenses in the selected month with the previous month.',
      supportingValues: {
        'currentExpenses': currentTotal,
        'previousExpenses': previousTotal,
        'change': change,
      },
      suggestedAction: increased ? 'See what changed' : 'Keep the momentum',
      generatedDate: generatedDate,
    );
  }

  Iterable<LocalInsight> _unusualTransactions(
    List<Transaction> transactions,
    DateTime month,
    DateTime generatedDate,
  ) sync* {
    final current = _expenses(transactions, month).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    for (final candidate in current) {
      final history = transactions
          .where((item) =>
              item.type == TransactionTyp.expense &&
              item.category == candidate.category &&
              item.date.isBefore(candidate.date) &&
              !_sameMonth(item.date, month))
          .map((item) => item.amount)
          .where((amount) => amount > 0)
          .toList()
        ..sort();
      if (history.length < 4) continue;
      final median = _median(history);
      if (candidate.amount < 50 || candidate.amount < median * 2.5) continue;
      final multiple = candidate.amount / median;
      yield LocalInsight(
        id: 'unusual:${_slug(candidate.category)}:${candidate.date.toIso8601String().split('T').first}:${candidate.amount.toStringAsFixed(2)}',
        type: InsightType.unusualTransaction,
        severity: InsightSeverity.warning,
        headline: 'Unusual ${candidate.category.toLowerCase()} expense',
        explanation:
            '${candidate.description} was ${multiple.toStringAsFixed(1)}× your typical expense in this category.',
        supportingValues: {
          'amount': candidate.amount,
          'categoryMedian': median,
          'multiple': multiple,
        },
        suggestedAction: 'Check this transaction',
        generatedDate: generatedDate,
      );
      return;
    }
  }

  Iterable<LocalInsight> _savingsRateTrend(
    List<Transaction> transactions,
    DateTime month,
    DateTime generatedDate,
  ) sync* {
    final previous = DateTime(month.year, month.month - 1);
    final current = _cashFlow(transactions, month);
    final prior = _cashFlow(transactions, previous);
    if (current.income <= 0 || prior.income <= 0) return;
    final currentRate = current.net / current.income;
    final priorRate = prior.net / prior.income;
    final delta = currentRate - priorRate;
    if (delta.abs() < 0.08) return;

    final points = (delta.abs() * 100).round();
    final improving = delta > 0;
    yield LocalInsight(
      id: 'savings-rate:${month.year}-${month.month}',
      type: InsightType.savingsRateTrend,
      severity: improving ? InsightSeverity.positive : InsightSeverity.warning,
      headline: 'Savings rate is ${improving ? 'up' : 'down'} $points points',
      explanation:
          'This is the share of income left after expenses compared with last month.',
      supportingValues: {
        'currentRate': currentRate,
        'previousRate': priorRate,
        'delta': delta,
      },
      suggestedAction:
          improving ? 'Keep the momentum' : 'Review flexible spending',
      generatedDate: generatedDate,
    );
  }

  Iterable<LocalInsight> _recurringChanges(
    List<Transaction> transactions,
    DateTime generatedDate,
  ) sync* {
    final byTemplate = <String, List<Transaction>>{};
    for (final item in transactions) {
      final templateId = item.recurringTemplateId;
      if (templateId == null) continue;
      byTemplate.putIfAbsent(templateId, () => []).add(item);
    }
    for (final entry in byTemplate.entries) {
      final items = entry.value..sort((a, b) => b.date.compareTo(a.date));
      if (items.length < 2) continue;
      final latest = items[0];
      final previous = items[1];
      if (previous.amount <= 0) continue;
      final change = (latest.amount - previous.amount) / previous.amount;
      if (change.abs() < 0.05 && (latest.amount - previous.amount).abs() < 5) {
        continue;
      }
      final percent = (change.abs() * 100).round();
      yield LocalInsight(
        id: 'recurring-change:${_slug(entry.key)}:${latest.date.year}-${latest.date.month}',
        type: InsightType.recurringAmountChange,
        severity:
            change > 0 ? InsightSeverity.warning : InsightSeverity.positive,
        headline: '${latest.description} changed by $percent%',
        explanation:
            'The latest recurring amount is ${change > 0 ? 'higher' : 'lower'} than the previous occurrence.',
        supportingValues: {
          'latestAmount': latest.amount,
          'previousAmount': previous.amount,
          'change': change,
        },
        suggestedAction: 'Review the recurring transaction',
        generatedDate: generatedDate,
      );
    }
  }

  Iterable<LocalInsight> _consistentlyUnderBudget(
    List<Transaction> transactions,
    Map<String, double> limits,
    DateTime month,
    DateTime generatedDate,
  ) sync* {
    for (final entry in limits.entries) {
      if (entry.value <= 0) continue;
      final ratios = <double>[];
      for (var offset = 1; offset <= 3; offset++) {
        final prior = DateTime(month.year, month.month - offset);
        final spent = _expenses(transactions, prior)
            .where((item) => item.category == entry.key)
            .fold(0.0, (sum, item) => sum + item.amount);
        if (spent <= 0) {
          ratios.clear();
          break;
        }
        ratios.add(spent / entry.value);
      }
      if (ratios.length != 3 || ratios.any((ratio) => ratio >= 0.7)) continue;
      final average = ratios.reduce((a, b) => a + b) / ratios.length;
      yield LocalInsight(
        id: 'under-budget:${_slug(entry.key)}:${month.year}-${month.month}',
        type: InsightType.consistentlyUnderBudget,
        severity: InsightSeverity.positive,
        headline: '${entry.key} has stayed under budget',
        explanation:
            'You used an average of ${(average * 100).round()}% of this budget over the last three full months.',
        supportingValues: {'averageUsedRatio': average, 'limit': entry.value},
        suggestedAction: 'Consider adjusting this budget',
        generatedDate: generatedDate,
      );
    }
  }

  Iterable<LocalInsight> _goalProgress(
    List<SavingsGoal> goals,
    DateTime now,
    DateTime generatedDate,
  ) sync* {
    final today = DateTime(now.year, now.month, now.day);
    for (final goal in goals.where((item) => !item.isCompleted)) {
      final duration = goal.targetDate.difference(goal.createdAt).inDays;
      final elapsed = today.difference(goal.createdAt).inDays;
      if (duration <= 0 || elapsed < 14) continue;
      final expected = (elapsed / duration).clamp(0.0, 1.0);
      if (goal.progress + 0.1 >= expected) continue;
      yield LocalInsight(
        id: 'goal-behind:${_slug(goal.id)}',
        type: InsightType.goalBehindSchedule,
        severity: goal.targetDate.isBefore(today)
            ? InsightSeverity.urgent
            : InsightSeverity.warning,
        headline: '${goal.name} is behind schedule',
        explanation:
            'Progress is ${goal.progressPercent}%; about ${(expected * 100).round()}% would keep this goal on pace.',
        supportingValues: {
          'progress': goal.progress,
          'expectedProgress': expected,
        },
        suggestedAction: 'Review this savings goal',
        generatedDate: generatedDate,
      );
    }
  }

  Iterable<LocalInsight> _negativeCashFlow(
    List<Transaction> transactions,
    DateTime month,
    DateTime generatedDate,
  ) sync* {
    final flows = List.generate(
      3,
      (offset) =>
          _cashFlow(transactions, DateTime(month.year, month.month - offset)),
    );
    if (flows.any((flow) => flow.income <= 0 || flow.net >= 0)) return;
    yield LocalInsight(
      id: 'negative-flow:${month.year}-${month.month}',
      type: InsightType.negativeCashFlow,
      severity: InsightSeverity.urgent,
      headline: 'Cash flow has been negative for 3 months',
      explanation:
          'Expenses exceeded recorded income in each of the last three months.',
      supportingValues: {
        for (var i = 0; i < flows.length; i++) 'month${i + 1}': flows[i].net,
      },
      suggestedAction: 'Review income and recurring expenses',
      generatedDate: generatedDate,
    );
  }

  Iterable<LocalInsight> _possibleDuplicates(
    List<Transaction> transactions,
    DateTime month,
    DateTime generatedDate,
  ) sync* {
    final seen = <String, Transaction>{};
    for (final item
        in transactions.where((item) => _sameMonth(item.date, month))) {
      final day = DateTime(item.date.year, item.date.month, item.date.day);
      final key = [
        item.type.name,
        _slug(item.description),
        item.amount.toStringAsFixed(2),
        day.toIso8601String(),
      ].join(':');
      final previous = seen[key];
      if (previous == null) {
        seen[key] = item;
        continue;
      }
      yield LocalInsight(
        id: 'duplicate:$key',
        type: InsightType.possibleDuplicate,
        severity: InsightSeverity.warning,
        headline: 'Possible duplicate transaction',
        explanation:
            '${item.description} appears more than once with the same amount and date.',
        supportingValues: {'amount': item.amount},
        suggestedAction: 'Review matching transactions',
        generatedDate: generatedDate,
      );
    }
  }

  Iterable<Transaction> _expenses(
    List<Transaction> transactions,
    DateTime month,
  ) =>
      transactions.where((item) =>
          item.type == TransactionTyp.expense && _sameMonth(item.date, month));

  _CashFlow _cashFlow(List<Transaction> transactions, DateTime month) {
    var income = 0.0;
    var expenses = 0.0;
    for (final item
        in transactions.where((item) => _sameMonth(item.date, month))) {
      if (item.type == TransactionTyp.income) {
        income += item.amount;
      } else {
        expenses += item.amount;
      }
    }
    return _CashFlow(income, expenses);
  }

  double _sum(Iterable<Transaction> transactions) =>
      transactions.fold(0.0, (sum, item) => sum + item.amount);

  double _median(List<double> sorted) {
    final middle = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[middle];
    return (sorted[middle - 1] + sorted[middle]) / 2;
  }

  bool _sameMonth(DateTime date, DateTime month) =>
      date.year == month.year && date.month == month.month;

  String _slug(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
}

class _CashFlow {
  final double income;
  final double expenses;

  const _CashFlow(this.income, this.expenses);

  double get net => income - expenses;
}
