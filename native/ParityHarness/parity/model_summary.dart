// What the Flutter app shows for a store, as plain JSON. The Swift parity
// tests compute the same summary from the same files and compare exactly
// (doubles are compared by value; Dart prints shortest round-trip digits).

import 'package:budget_app/net_worth_entry.dart';
import 'package:budget_app/safe_to_spend.dart';
import 'package:budget_app/transaction.dart';

import 'harness_support.dart';

Map<String, Object?> summarize(AppHarness app, {required DateTime asOf}) {
  final model = app.transactionModel;
  final months = model.getAvailableMonths();

  final monthly = <String, Object?>{};
  for (final month in months) {
    final summary = model.getMonthlySummary(month);
    model.selectMonth(month);
    monthly[netWorthMonthKey(month)] = {
      'summary': summary,
      'totalIncome': model.totalIncome,
      'totalExpenses': model.totalExpenses,
      'transactionIds':
          model.getTransactionsForMonth(month).map((t) => t.id).toList(),
      'categoryExpenses': model.getCategoryExpensesForMonth(month),
    };
  }

  final netWorth = <String, Object?>{};
  for (final month in model.getNetWorthAvailableMonths()) {
    netWorth[netWorthMonthKey(month)] = {
      'assets': model.getTotalAssetsForMonth(month),
      'liabilities': model.getTotalLiabilitiesForMonth(month),
      'netWorth': model.getNetWorthForMonth(month),
      'change': model.getNetWorthChangeForMonth(month),
      'hasData': model.hasNetWorthDataForMonth(month),
      'tracked': model.getTrackedNetWorthEntryCountForMonth(month),
      'updated': model.getUpdatedNetWorthEntryCountForMonth(month),
      'stale': model.getStaleNetWorthEntryCountForMonth(month),
      'entries': model
          .getNetWorthEntriesForMonth(month)
          .map((e) => {'id': e.id, 'amount': e.amountForMonth(month)})
          .toList(),
    };
  }

  List<Map<String, Object?>> history(int limit) => model
      .getNetWorthHistory(limit: limit)
      .map((p) => {
            'date': iso(p.date),
            'assets': p.assets,
            'liabilities': p.liabilities,
            'netWorth': p.netWorth,
            'assetCount': p.assetCount,
            'liabilityCount': p.liabilityCount,
            'granularity': p.granularity.name,
          })
      .toList();

  final safeToSpend = <String, Object?>{};
  for (final month in months) {
    final b = SafeToSpendCalculator.calculate(
      transactions: model.transactions,
      recurringTransactions: app.recurringModel.recurringTransactions,
      categoryBudgetLimits: model.categoryBudgetLimits,
      savingsGoals: model.savingsGoals,
      month: month,
      asOf: asOf,
    );
    safeToSpend[netWorthMonthKey(month)] = breakdownJson(b);
  }

  return {
    'asOf': iso(asOf),
    'transactionCount': model.transactions.length,
    'sortedIds': model.getAllTransactionsSorted().map((t) => t.id).toList(),
    'availableMonths': months.map(iso).toList(),
    'monthly': monthly,
    'selectedNetWorthMonth': iso(model.selectedNetWorthMonth),
    'netWorthAvailableMonths':
        model.getNetWorthAvailableMonths().map(iso).toList(),
    'netWorth': netWorth,
    'netWorthHistory24': history(24),
    'netWorthHistory4': history(4),
    'categoryBudgetLimits': model.categoryBudgetLimits,
    'savingsGoals': model.savingsGoals
        .map((g) => {
              'id': g.id,
              'isCompleted': g.isCompleted,
              'suggestedMonthlyContribution': g.suggestedMonthlyContribution,
            })
        .toList(),
    'recurring': app.recurringModel.recurringTransactions
        .map((r) => {
              'id': r.id,
              'nextOccurrence': iso(r.nextOccurrence),
              'isActive': r.isActive,
            })
        .toList(),
    'safeToSpend': safeToSpend,
    'appSettings': {
      'baseCurrencyCode': app.appSettings.baseCurrencyCode,
      'localeOverride': app.appSettings.localeOverride,
      'appLockEnabled': app.appSettings.appLockEnabled,
      'autoLockTimeoutSeconds': app.appSettings.autoLockTimeoutSeconds,
      'hideBalances': app.appSettings.hideBalances,
    },
    'widgetCashFlow': widgetCashFlow(model.transactions, asOf),
    'hasUnsavedChanges': model.hasUnsavedChanges,
  };
}

Map<String, Object?> breakdownJson(SafeToSpendBreakdown b) => {
      'month': iso(b.month),
      'asOf': iso(b.asOf),
      'actualIncome': b.actualIncome,
      'expectedIncome': b.expectedIncome,
      'actualExpenses': b.actualExpenses,
      'upcomingRecurringExpenses': b.upcomingRecurringExpenses,
      'flexibleBudgetReserve': b.flexibleBudgetReserve,
      'plannedGoalContributions': b.plannedGoalContributions,
      'daysRemaining': b.daysRemaining,
      'safeToSpend': b.safeToSpend,
      'isOverCommitted': b.isOverCommitted,
      'overCommitment': b.overCommitment,
      'dailyAllowance': b.dailyAllowance,
    };

/// Same loop as TransactionModel._syncWidgetCashFlow (which only runs on
/// iOS, so tests cannot observe it directly). Kept textually identical.
Map<String, Object> widgetCashFlow(List<Transaction> transactions, DateTime now) {
  var cashFlow = 0.0;
  for (final transaction in transactions) {
    if (transaction.date.year != now.year ||
        transaction.date.month != now.month) {
      continue;
    }
    cashFlow += transaction.type == TransactionTyp.income
        ? transaction.amount
        : -transaction.amount;
  }
  return {
    'amount': cashFlow,
    'month': '${now.year}-${now.month.toString().padLeft(2, '0')}',
  };
}
