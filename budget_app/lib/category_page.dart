import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'transaction_model.dart';
import 'transaction.dart';
import 'common.dart';
import 'design_system.dart';
import 'widgets/empty_state.dart';
import 'widgets/month_selector.dart';
import 'widgets/category_summary_header.dart';
import 'widgets/category_donut_chart.dart';
import 'widgets/category_spending_tile.dart';
import 'utils/platform_utils.dart';
import 'category_transactions_page.dart';

class CategoryPage extends StatefulWidget {
  const CategoryPage({Key? key}) : super(key: key);

  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  DateTime? selectedMonth;
  int _selectedSliceIndex = -1;

  @override
  Widget build(BuildContext context) {
    return Consumer<TransactionModel>(
      builder: (context, model, child) {
        final List<DateTime> availableMonths = model.getAvailableMonths();

        // Validate the selected month: reset to the most recent available
        // month when it is null or no longer present (fixes stale-month bug).
        final bool selectedStillAvailable = selectedMonth != null &&
            availableMonths.any((m) =>
                m.year == selectedMonth!.year &&
                m.month == selectedMonth!.month);
        if (!selectedStillAvailable && availableMonths.isNotEmpty) {
          selectedMonth = availableMonths.first;
        }

        final DateTime month = selectedMonth ?? model.selectedMonth;

        // Spending per category for the selected month.
        final Map<String, double> expensesPerCategory =
            model.getCategoryExpensesForMonth(month);
        final double totalAmount = expensesPerCategory.values
            .fold(0.0, (sum, value) => sum + value);

        // Transaction counts per expense category for the selected month.
        final Map<String, int> transactionCounts = {};
        for (final transaction in model
            .getTransactionsForMonth(month)
            .where((t) => t.type == TransactionTyp.expense)) {
          transactionCounts.update(
            transaction.category,
            (existing) => existing + 1,
            ifAbsent: () => 1,
          );
        }

        // Previous-month total (null when there is no data for that month, so
        // the header hides its delta chip — no data is not the same as $0).
        final DateTime previousMonth = DateTime(month.year, month.month - 1);
        final List<Transaction> previousMonthTransactions =
            model.getTransactionsForMonth(previousMonth);
        final double? previousMonthTotal = previousMonthTransactions.isEmpty
            ? null
            : previousMonthTransactions
                .where((t) => t.type == TransactionTyp.expense)
                .fold<double>(0.0, (sum, t) => sum + t.amount);

        // Stable color mapping keyed by declaration order in expenseCategories.
        final List<Color> chartColors = AppDesign.getChartColors(context);
        final Map<String, Color> categoryColorMap = {
          for (int i = 0; i < expenseCategories.length; i++)
            expenseCategories.keys.elementAt(i):
                chartColors[i % chartColors.length],
        };

        // Build per-category records sorted descending by amount.
        final List<_CategoryRecord> records = expensesPerCategory.entries
            .map((entry) {
              final color = categoryColorMap[entry.key] ??
                  chartColors[entry.key.hashCode.abs() % chartColors.length];
              return _CategoryRecord(
                category: entry.key,
                amount: entry.value,
                percentage:
                    totalAmount > 0 ? (entry.value / totalAmount) * 100 : 0.0,
                color: color,
                icon: expenseCategories[entry.key],
                count: transactionCounts[entry.key] ?? 0,
                budgetLimit: model.getCategoryBudgetLimit(entry.key),
              );
            })
            .toList()
          ..sort((a, b) => b.amount.compareTo(a.amount));

        final double largestAmount =
            records.isNotEmpty ? records.first.amount : 0.0;

        // Donut slices: top 6 categories individually; remainder aggregated
        // into a single "Other" slice.
        final List<CategorySlice> slices = [];
        for (int i = 0; i < records.length && i < 6; i++) {
          slices.add(CategorySlice(
            label: records[i].category,
            value: records[i].amount,
            color: records[i].color,
          ));
        }
        if (records.length > 6) {
          final double otherTotal = records
              .skip(6)
              .fold(0.0, (sum, record) => sum + record.amount);
          slices.add(CategorySlice(
            label: 'Other',
            value: otherTotal,
            color: AppColors.textTertiary,
          ));
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(
              'Categories',
              style: AppTypography.headingMedium.copyWith(
                color: AppDesign.getTextPrimary(context),
              ),
            ),
            centerTitle: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            foregroundColor: AppDesign.getTextPrimary(context),
          ),
          extendBodyBehindAppBar: true,
          body: Container(
            color: AppDesign.getBackgroundColor(context),
            child: SafeArea(
              child: Column(
                children: [
                  if (availableMonths.isNotEmpty)
                    MonthSelector(
                      selectedMonth: selectedMonth,
                      availableMonths: availableMonths,
                      onMonthChanged: (DateTime newMonth) {
                        setState(() {
                          selectedMonth = newMonth;
                          _selectedSliceIndex = -1;
                        });
                      },
                    ),
                  Expanded(
                    child: _buildBody(
                      context,
                      model,
                      availableMonths,
                      month,
                      records,
                      slices,
                      totalAmount,
                      previousMonthTotal,
                      largestAmount,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    TransactionModel model,
    List<DateTime> availableMonths,
    DateTime month,
    List<_CategoryRecord> records,
    List<CategorySlice> slices,
    double totalAmount,
    double? previousMonthTotal,
    double largestAmount,
  ) {
    if (availableMonths.isEmpty) {
      return EmptyState(
        type: EmptyStateType.noData,
        title: 'No Expenses Yet',
        message: 'Start tracking your expenses to see category breakdowns',
        icon: CupertinoIcons.chart_pie,
        iconGradient: AppDesign.getExpenseGradient(context),
      );
    }

    if (totalAmount == 0.0) {
      return EmptyState(
        type: EmptyStateType.noData,
        title: 'No Expenses',
        message: 'No expenses recorded for this month',
        icon: CupertinoIcons.chart_pie,
        iconGradient: AppDesign.getExpenseGradient(context),
      );
    }

    return ListView(
      physics: PlatformUtils.platformScrollPhysics,
      padding: const EdgeInsets.fromLTRB(
        AppDesign.spacingM,
        AppDesign.spacingS,
        AppDesign.spacingM,
        AppDesign.spacingL,
      ),
      children: [
        CategorySummaryHeader(
          totalSpent: totalAmount,
          previousMonthTotal: previousMonthTotal,
          monthLabel: DateFormat.yMMMM().format(month),
        ),
        const SizedBox(height: AppDesign.spacingM),
        CategoryDonutChart(
          slices: slices,
          totalAmount: totalAmount,
          selectedIndex: _selectedSliceIndex,
          month: month,
          onSliceSelected: (index) {
            setState(() => _selectedSliceIndex = index);
          },
        ),
        const SizedBox(height: AppDesign.spacingM),
        Row(
          children: [
            Text(
              'Breakdown',
              style: AppTypography.headingSmall.copyWith(
                color: AppDesign.getTextPrimary(context),
              ),
            ),
            const Spacer(),
            Text(
              '${records.length} categories',
              style: AppTypography.bodySmall.copyWith(
                color: AppDesign.getTextSecondary(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDesign.spacingS),
        for (int i = 0; i < records.length; i++) ...[
          if (i > 0) const SizedBox(height: AppDesign.spacingS),
          CategorySpendingTile(
            category: records[i].category,
            icon: records[i].icon,
            color: records[i].color,
            amount: records[i].amount,
            percentage: records[i].percentage,
            barFraction:
                largestAmount > 0 ? records[i].amount / largestAmount : 0.0,
            transactionCount: records[i].count,
            budgetLimit: records[i].budgetLimit,
            isSelected: i == _selectedSliceIndex && _selectedSliceIndex < 6,
            onTap: () {
              Navigator.push(
                context,
                CupertinoPageRoute(
                  builder: (context) => CategoryTransactionsPage(
                    category: records[i].category,
                    categoryColor: records[i].color,
                    categoryIcon: records[i].icon,
                    month: month,
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}

class _CategoryRecord {
  final String category;
  final double amount;
  final double percentage;
  final Color color;
  final IconData? icon;
  final int count;
  final double? budgetLimit;

  const _CategoryRecord({
    required this.category,
    required this.amount,
    required this.percentage,
    required this.color,
    required this.icon,
    required this.count,
    required this.budgetLimit,
  });
}
