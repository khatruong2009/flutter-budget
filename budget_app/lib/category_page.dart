import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'transaction_model.dart';
import 'transaction.dart';
import 'common.dart';
import 'design_system.dart';
import 'widgets/empty_state.dart';
import 'widgets/category_donut_chart.dart';
import 'utils/platform_utils.dart';
import 'category_transactions_page.dart';

/// Categories tab: donut hero of the month's spend by category, followed by
/// a ranked breakdown list. The first six categories (by amount) get their
/// own donut slice and list row; anything beyond that is aggregated into a
/// single gray "N more categories" slice/row that expands in place on tap.
class CategoryPage extends StatefulWidget {
  const CategoryPage({Key? key}) : super(key: key);

  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  DateTime? selectedMonth;
  int _selectedSliceIndex = -1;
  bool _tailExpanded = false;

  static const int _maxVisibleCategories = 6;

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
          // Substituting a different month must drop selection state carried
          // over from the vanished month (same reset as the month picker) —
          // otherwise a stale slice index highlights whatever category now
          // occupies that rank.
          _selectedSliceIndex = -1;
          _tailExpanded = false;
        }

        final DateTime month = selectedMonth ?? model.selectedMonth;

        // Spending per category for the selected month.
        final Map<String, double> expensesPerCategory =
            model.getCategoryExpensesForMonth(month);
        final double totalAmount =
            expensesPerCategory.values.fold(0.0, (sum, value) => sum + value);

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
        // the delta pill hides — no data is not the same as $0).
        final DateTime previousMonth = DateTime(month.year, month.month - 1);
        final List<Transaction> previousMonthTransactions =
            model.getTransactionsForMonth(previousMonth);
        final double? previousMonthTotal = previousMonthTransactions.isEmpty
            ? null
            : previousMonthTransactions
                .where((t) => t.type == TransactionTyp.expense)
                .fold<double>(0.0, (sum, t) => sum + t.amount);

        // Stable color mapping keyed by declaration order in expenseCategories,
        // overridden by the design's fixed segment palette for the first six
        // ranked categories once records are sorted (below).
        final List<Color> chartColors = AppDesign.getChartColors(context);
        final Map<String, Color> categoryColorMap = {
          for (int i = 0; i < expenseCategories.length; i++)
            expenseCategories.keys.elementAt(i):
                chartColors[i % chartColors.length],
        };

        // Build per-category records sorted descending by amount.
        final List<_CategoryRecord> records =
            expensesPerCategory.entries.map((entry) {
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
        }).toList()
              ..sort((a, b) => b.amount.compareTo(a.amount));

        // Design's fixed segment palette, applied in spend-rank order to the
        // top slices; the aggregated tail uses the neutral remainder color.
        final List<Color> segmentPalette = [
          AppColors.getAccent(context.isDarkFromTheme),
          AppColors.getIncome(context.isDarkFromTheme),
          AppColors.getDanger(context.isDarkFromTheme),
          AppColors.getWarning(context.isDarkFromTheme),
          AppColors.getInfo(context.isDarkFromTheme),
          AppColors.pink,
        ];
        for (int i = 0; i < records.length && i < segmentPalette.length; i++) {
          records[i] = records[i].withColor(segmentPalette[i]);
        }

        final double largestAmount =
            records.isNotEmpty ? records.first.amount : 0.0;

        // Donut slices: top N categories individually; remainder aggregated
        // into a single tail slice using the neutral remainder color.
        final bool hasTail = records.length > _maxVisibleCategories;
        final List<CategorySlice> slices = [];
        for (int i = 0; i < records.length && i < _maxVisibleCategories; i++) {
          slices.add(CategorySlice(
            label: records[i].category,
            value: records[i].amount,
            color: records[i].color,
          ));
        }
        if (hasTail) {
          final double tailTotal = records
              .skip(_maxVisibleCategories)
              .fold(0.0, (sum, record) => sum + record.amount);
          slices.add(CategorySlice(
            label: 'Other',
            value: tailTotal,
            color: AppColors.getDonutRemainder(context.isDarkFromTheme),
          ));
        }

        return BudgiePageScaffold(
          body: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                BudgieHeader(
                  title: 'Categories',
                  trailing: availableMonths.isEmpty
                      ? null
                      : MonthPill(
                          label: DateFormat.MMMM().format(month),
                          onTap: () => _showMonthPicker(
                            context,
                            availableMonths,
                            month,
                          ),
                        ),
                ),
                Expanded(
                  child: _buildBody(
                    context,
                    availableMonths,
                    month,
                    previousMonth,
                    records,
                    slices,
                    totalAmount,
                    previousMonthTotal,
                    largestAmount,
                    hasTail,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    List<DateTime> availableMonths,
    DateTime month,
    DateTime previousMonth,
    List<_CategoryRecord> records,
    List<CategorySlice> slices,
    double totalAmount,
    double? previousMonthTotal,
    double largestAmount,
    bool hasTail,
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

    final visibleCount =
        _tailExpanded ? records.length : _visibleRowCount(records.length);

    return ListView(
      physics: PlatformUtils.platformScrollPhysics,
      padding: EdgeInsets.fromLTRB(
        20,
        32,
        20,
        DockMetrics.contentBottomPadding(context),
      ),
      children: [
        Center(
          child: CategoryDonutChart(
            slices: slices,
            totalAmount: totalAmount,
            selectedIndex: _selectedSliceIndex,
            month: month,
            previousMonthTotal: previousMonthTotal,
            previousMonthLabel: DateFormat.MMMM().format(previousMonth),
            onSliceSelected: (index) {
              setState(() => _selectedSliceIndex = index);
            },
          ),
        ),
        const SizedBox(height: 20),
        GlowListCard(
          children: [
            for (int i = 0; i < visibleCount && i < records.length; i++)
              _buildCategoryRow(
                context,
                records[i],
                index: i,
                largestAmount: largestAmount,
                month: month,
              ),
            if (hasTail && !_tailExpanded)
              _buildTailRow(
                context,
                records.skip(_maxVisibleCategories).toList(),
                largestAmount: largestAmount,
              ),
            if (hasTail && _tailExpanded) _buildCollapseRow(context),
          ],
        ),
      ],
    );
  }

  /// Rows shown before expansion: the ranked categories up to the aggregation
  /// threshold (the tail itself renders as its own summary row).
  int _visibleRowCount(int totalRecords) {
    return totalRecords > _maxVisibleCategories
        ? _maxVisibleCategories
        : totalRecords;
  }

  Widget _buildCategoryRow(
    BuildContext context,
    _CategoryRecord record, {
    required int index,
    required double largestAmount,
    required DateTime month,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final moneyFmt =
        NumberFormat.currency(locale: 'en_US', symbol: '\$', decimalDigits: 0);
    final limitFmt = NumberFormat('#,##0', 'en_US');
    final isSelected =
        index == _selectedSliceIndex && index < _maxVisibleCategories;

    String subtitle =
        '${record.count} transaction${record.count == 1 ? '' : 's'}'
        ' · ${record.percentage.toStringAsFixed(0)}%';
    final limit = record.budgetLimit;
    if (limit != null && limit > 0) {
      subtitle += record.amount > limit
          ? ' · over limit'
          : ' · ${limitFmt.format(limit)} limit';
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        MicroInteractions.lightImpact();
        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (context) => CategoryTransactionsPage(
              category: record.category,
              categoryColor: record.color,
              categoryIcon: record.icon,
              month: month,
            ),
          ),
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? record.color.withValues(alpha: isDark ? 0.14 : 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconTile(
                  icon: record.icon ?? CupertinoIcons.square_grid_2x2,
                  color: record.color,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.category,
                        style: AppTypography.rowTitle.copyWith(
                          color: AppColors.getTextColor(isDark),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: AppTypography.rowSubtitle.copyWith(
                          color: AppColors.getTextSecondaryColor(isDark),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  moneyFmt.format(record.amount),
                  style: AppTypography.amount.copyWith(
                    color: AppColors.getTextColor(isDark),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            GlowProgressBar(
              value: largestAmount > 0 ? record.amount / largestAmount : 0.0,
              color: record.color,
              height: 6,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTailRow(
    BuildContext context,
    List<_CategoryRecord> tail, {
    required double largestAmount,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final moneyFmt =
        NumberFormat.currency(locale: 'en_US', symbol: '\$', decimalDigits: 0);
    final tailTotal = tail.fold(0.0, (sum, r) => sum + r.amount);
    final names = tail.map((r) => r.category).join(', ');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          MicroInteractions.lightImpact();
          setState(() => _tailExpanded = true);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconTile(
                  icon: Symbols.more_horiz_rounded,
                  color: AppColors.getTextSecondaryColor(isDark),
                  background: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.05),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${tail.length} more '
                        'categor${tail.length == 1 ? 'y' : 'ies'}',
                        style: AppTypography.rowTitle.copyWith(
                          color: AppColors.getTextColor(isDark),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        names,
                        style: AppTypography.rowSubtitle.copyWith(
                          color: AppColors.getTextSecondaryColor(isDark),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  moneyFmt.format(tailTotal),
                  style: AppTypography.amount.copyWith(
                    color: AppColors.getTextColor(isDark),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            GlowProgressBar(
              value: largestAmount > 0 ? tailTotal / largestAmount : 0.0,
              color: AppColors.getDonutRemainder(isDark),
              height: 6,
            ),
          ],
        ),
      ),
    );
  }

  /// Shown in place of the tail row once expanded, letting the user collapse
  /// the breakdown back down to the top categories.
  Widget _buildCollapseRow(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = AppColors.getAccent(isDark);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          MicroInteractions.lightImpact();
          setState(() => _tailExpanded = false);
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Show less',
              style: AppTypography.monoLink.copyWith(color: accent),
            ),
            const SizedBox(width: 4),
            Icon(
              Symbols.expand_less_rounded,
              size: 16,
              weight: 500,
              color: accent,
            ),
          ],
        ),
      ),
    );
  }

  void _showMonthPicker(
    BuildContext context,
    List<DateTime> availableMonths,
    DateTime currentMonth,
  ) {
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final isDark = Theme.of(sheetContext).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: AppColors.getCard(isDark),
            border: Border(
              top: BorderSide(color: AppColors.getCardBorder(isDark)),
            ),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(26),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.getTextTertiaryColor(isDark),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Select month',
                      style: AppTypography.sectionHeader.copyWith(
                        color: AppColors.getTextColor(isDark),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: availableMonths.map((m) {
                      final isSelected = m.year == currentMonth.year &&
                          m.month == currentMonth.month;
                      final accent = AppColors.getAccent(isDark);
                      return ListTile(
                        title: Text(
                          DateFormat.yMMMM().format(m),
                          style: AppTypography.rowTitle.copyWith(
                            fontSize: 16,
                            color: isSelected
                                ? accent
                                : AppColors.getTextColor(isDark),
                          ),
                        ),
                        trailing: isSelected
                            ? Icon(Symbols.check_rounded,
                                color: accent, size: 20, weight: 500)
                            : null,
                        onTap: () {
                          MicroInteractions.selectionClick();
                          setState(() {
                            selectedMonth = m;
                            _selectedSliceIndex = -1;
                            _tailExpanded = false;
                          });
                          Navigator.pop(sheetContext);
                        },
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
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

  _CategoryRecord withColor(Color newColor) => _CategoryRecord(
        category: category,
        amount: amount,
        percentage: percentage,
        color: newColor,
        icon: icon,
        count: count,
        budgetLimit: budgetLimit,
      );
}

extension _ThemeBrightness on BuildContext {
  bool get isDarkFromTheme => Theme.of(this).brightness == Brightness.dark;
}
