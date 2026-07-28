import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'transaction_model.dart';
import 'categorization_provider.dart';
import 'transaction_tag.dart';
import 'transaction.dart';
import 'common.dart';
import 'design_system.dart';
import 'utils/platform_utils.dart';
import 'widgets/local_insights_section.dart';
import 'money_formatter.dart';

enum _HistoryTransactionTypeFilter { all, income, expense }

/// Cash Flow tab. Overview of net cash flow, savings metrics, year-over-year
/// comparison and a 12-month trend. The full filterable transaction list lives
/// behind a "SEE ALL" drill-in ([_TransactionsDetailPage]).
class HistoryPage extends StatefulWidget {
  const HistoryPage({Key? key}) : super(key: key);

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  // Selected chart range in months (3 / 6 / 12) — UI-only state driving the
  // net cash flow chart and savings metrics.
  int _rangeMonths = 6;

  @override
  Widget build(BuildContext context) {
    return Consumer<TransactionModel>(
      builder: (context, model, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final allChartData = model.getNetCashFlowHistory();
        final selectedMonth = model.selectedMonth;

        final chartData =
            _getChartDisplayData(allChartData, selectedMonth, _rangeMonths);
        final metrics = _computeMetrics(chartData);
        final currentReport =
            _buildMonthReport(model.transactions, selectedMonth);
        final previousYearMonth =
            DateTime(selectedMonth.year - 1, selectedMonth.month);
        final previousReport =
            _buildMonthReport(model.transactions, previousYearMonth);
        final rollingTrendData =
            _getRollingTrendData(model.transactions, selectedMonth);

        return BudgiePageScaffold(
          body: SingleChildScrollView(
            physics: PlatformUtils.platformScrollPhysics,
            padding: EdgeInsets.only(
              bottom: DockMetrics.contentBottomPadding(context),
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  BudgieHeader(
                    title: 'Cash flow',
                    trailing: MonthPill(
                      label: _rangeLabel(_rangeMonths),
                      onTap: () => _showRangePicker(context),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _buildMetricStrip(context, metrics, isDark),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: LocalInsightsSection(model: model),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _buildNetCashFlowCard(
                        context, chartData, selectedMonth, isDark),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _buildYearOverYearCard(
                        context, currentReport, previousReport, isDark),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _buildTrendCard(context, rollingTrendData, isDark),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: SectionHeader(
                      title: 'Transactions',
                      linkLabel: 'SEE ALL',
                      onLinkTap: () => _openTransactions(context),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _buildTransactionsPreview(context, model, isDark),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ===== Data helpers =====

  String _rangeLabel(int months) => '$months months';

  List<MonthCashFlow> _getChartDisplayData(
    List<MonthCashFlow> allData,
    DateTime selectedMonth,
    int months,
  ) {
    final filtered = allData
        .where((d) =>
            d.month.year < selectedMonth.year ||
            (d.month.year == selectedMonth.year &&
                d.month.month <= selectedMonth.month))
        .toList();
    if (filtered.length > months) {
      return filtered.sublist(filtered.length - months);
    }
    return filtered;
  }

  Map<String, double> _computeMetrics(List<MonthCashFlow> chartData) {
    if (chartData.isEmpty) return {'avgSavings': 0.0, 'savingsRate': 0.0};
    final totalIncome = chartData.fold(0.0, (sum, d) => sum + d.income);
    final totalExpenses = chartData.fold(0.0, (sum, d) => sum + d.expenses);
    final totalSavings = totalIncome - totalExpenses;
    final avgSavings = totalSavings / chartData.length;
    final savingsRate =
        totalIncome > 0 ? (totalSavings / totalIncome) * 100 : 0.0;
    return {'avgSavings': avgSavings, 'savingsRate': savingsRate};
  }

  _MonthlyCashFlowReport _buildMonthReport(
    List<Transaction> transactions,
    DateTime month,
  ) {
    final monthTransactions = transactions
        .where((transaction) => _isSameMonth(transaction.date, month))
        .toList();
    final income = monthTransactions
        .where((transaction) => transaction.type == TransactionTyp.income)
        .fold(0.0, (sum, transaction) => sum + transaction.amount);
    final expenses = monthTransactions
        .where((transaction) => transaction.type == TransactionTyp.expense)
        .fold(0.0, (sum, transaction) => sum + transaction.amount);
    return _MonthlyCashFlowReport(
      month: DateTime(month.year, month.month),
      income: income,
      expenses: expenses,
    );
  }

  List<MonthCashFlow> _getRollingTrendData(
    List<Transaction> transactions,
    DateTime selectedMonth,
  ) {
    return List.generate(12, (index) {
      final month =
          DateTime(selectedMonth.year, selectedMonth.month - 11 + index);
      final report = _buildMonthReport(transactions, month);
      return MonthCashFlow(
        month: report.month,
        netCashFlow: report.netCashFlow,
        income: report.income,
        expenses: report.expenses,
      );
    });
  }

  bool _isSameMonth(DateTime date, DateTime month) {
    return date.year == month.year && date.month == month.month;
  }

  /// Full grouped amount like the design's `$1,376`; compacts only at
  /// 6+ digits where the chip would otherwise overflow.
  String _formatMetricCurrency(double value) {
    return MoneyFormatter.formatSigned(value, decimalDigits: 0);
  }

  /// Percentage delta of [current] vs [previous]; null when there is no prior
  /// figure to compare against (division by zero).
  double? _percentDelta(double current, double previous) {
    if (previous == 0) return null;
    return ((current - previous) / previous) * 100;
  }

  String _formatPercentDelta(double? delta) {
    if (delta == null) return 'new';
    final sign = delta > 0
        ? '+'
        : delta < 0
            ? '-'
            : '';
    return '$sign${delta.abs().toStringAsFixed(1)}%';
  }

  // ===== Sections =====

  Widget _buildMetricStrip(
    BuildContext context,
    Map<String, double> metrics,
    bool isDark,
  ) {
    final avgSavings = metrics['avgSavings'] ?? 0.0;
    final savingsRate = metrics['savingsRate'] ?? 0.0;
    final income = AppColors.getIncome(isDark);
    final danger = AppColors.getDanger(isDark);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _MetricChip(
              label: 'AVG SAVED / MO',
              value: _formatMetricCurrency(avgSavings),
              color: avgSavings >= 0 ? income : danger,
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _MetricChip(
              label: 'SAVINGS RATE',
              value: '${savingsRate.toStringAsFixed(0)}%',
              color: savingsRate >= 0 ? income : danger,
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNetCashFlowCard(
    BuildContext context,
    List<MonthCashFlow> chartData,
    DateTime selectedMonth,
    bool isDark,
  ) {
    return GlowCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Net cash flow',
            style: AppTypography.cardTitle
                .copyWith(color: AppColors.getTextColor(isDark)),
          ),
          const SizedBox(height: 20),
          if (chartData.isEmpty)
            _EmptyChartMessage(
              message: 'No cash flow data yet.',
              isDark: isDark,
            )
          else
            _NetCashFlowBars(
              data: chartData,
              currentMonth: selectedMonth,
              isDark: isDark,
              onBarTap: (entry) =>
                  _showMonthDetailsBottomSheet(context, entry, isDark),
            ),
        ],
      ),
    );
  }

  Widget _buildYearOverYearCard(
    BuildContext context,
    _MonthlyCashFlowReport current,
    _MonthlyCashFlowReport previous,
    bool isDark,
  ) {
    final accent = AppColors.getAccent(isDark);
    final income = AppColors.getIncome(isDark);
    final danger = AppColors.getDanger(isDark);
    final incomeDelta = _percentDelta(current.income, previous.income);
    final expenseDelta = _percentDelta(current.expenses, previous.expenses);

    final incomeMax = max(current.income, previous.income);
    final expenseMax = max(current.expenses, previous.expenses);

    return GlowCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  'Year over year',
                  style: AppTypography.cardTitle
                      .copyWith(color: AppColors.getTextColor(isDark)),
                ),
              ),
              Text(
                '${DateFormat("MMM ''yy").format(current.month).toUpperCase()} VS '
                '${DateFormat("MMM ''yy").format(previous.month).toUpperCase()}',
                style: AppTypography.monoMonth
                    .copyWith(color: AppColors.getTextTertiaryColor(isDark)),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _YoyRow(
            label: 'Income',
            deltaLabel: _formatPercentDelta(incomeDelta),
            // Rising income is good (green); falling is rose.
            deltaColor: (incomeDelta ?? 0) >= 0 ? income : danger,
            thisYearFraction: incomeMax > 0 ? current.income / incomeMax : 0.0,
            lastYearFraction: incomeMax > 0 ? previous.income / incomeMax : 0.0,
            accent: accent,
            isDark: isDark,
          ),
          const SizedBox(height: 16),
          _YoyRow(
            label: 'Expenses',
            deltaLabel: _formatPercentDelta(expenseDelta),
            // Rising expenses is bad (rose); falling is green.
            deltaColor: (expenseDelta ?? 0) > 0 ? danger : income,
            thisYearFraction:
                expenseMax > 0 ? current.expenses / expenseMax : 0.0,
            lastYearFraction:
                expenseMax > 0 ? previous.expenses / expenseMax : 0.0,
            accent: accent,
            isDark: isDark,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _LegendDot(color: accent, label: 'This year', isDark: isDark),
              const SizedBox(width: 14),
              _LegendDot(
                color: AppColors.getTrackSecondary(isDark),
                label: 'Last year',
                isDark: isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrendCard(
    BuildContext context,
    List<MonthCashFlow> trendData,
    bool isDark,
  ) {
    return GlowCard(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Text(
                    '12-month trend',
                    style: AppTypography.cardTitle
                        .copyWith(color: AppColors.getTextColor(isDark)),
                  ),
                ),
                Text(
                  'NET / MO',
                  style: AppTypography.monoMonth
                      .copyWith(color: AppColors.getTextTertiaryColor(isDark)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: _TrendSparkline(data: trendData, isDark: isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsPreview(
    BuildContext context,
    TransactionModel model,
    bool isDark,
  ) {
    final recent = List<Transaction>.from(model.transactions)
      ..sort(Transaction.compareNewestFirst);
    final preview = recent.take(3).toList();

    if (preview.isEmpty) {
      return GlowCard(
        onTap: () => _openTransactions(context),
        child: _EmptyChartMessage(
          message: 'No transactions recorded yet.',
          isDark: isDark,
        ),
      );
    }

    return GlowListCard(
      children: [
        for (final transaction in preview)
          _TransactionRow(
            transaction: transaction,
            isDark: isDark,
            onTap: () => _openTransactions(context),
          ),
      ],
    );
  }

  // ===== Interactions =====

  void _openTransactions(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const _TransactionsDetailPage(),
      ),
    );
  }

  void _showRangePicker(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: AppColors.getCard(isDark),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: AppColors.getCardBorder(isDark)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.getTextTertiaryColor(isDark)
                        .withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'CHART RANGE',
                  style: AppTypography.eyebrow
                      .copyWith(color: AppColors.getTextTertiaryColor(isDark)),
                ),
              ),
              const SizedBox(height: 8),
              for (final months in const [3, 6, 12])
                _RangeOptionTile(
                  months: months,
                  label: _rangeLabel(months),
                  selected: months == _rangeMonths,
                  isDark: isDark,
                  onTap: () {
                    MicroInteractions.selectionClick();
                    setState(() => _rangeMonths = months);
                    Navigator.pop(ctx);
                  },
                ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  void _showMonthDetailsBottomSheet(
    BuildContext context,
    MonthCashFlow data,
    bool isDark,
  ) {
    final incomeColor = AppColors.getIncome(isDark);
    final expenseColor = AppColors.getDanger(isDark);
    final net = data.income - data.expenses;
    final netColor = net >= 0 ? incomeColor : expenseColor;

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: AppColors.getCard(isDark),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: AppColors.getCardBorder(isDark)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppColors.getTextTertiaryColor(isDark)
                        .withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Row(
                  children: [
                    IconTile(
                      icon: Symbols.bar_chart_rounded,
                      color: netColor,
                      size: 44,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      DateFormat.yMMMM().format(data.month),
                      style: AppTypography.sectionHeader
                          .copyWith(color: AppColors.getTextColor(isDark)),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _MonthDetailTile(
                        label: 'Income',
                        amount: MoneyFormatter.format(data.income),
                        color: incomeColor,
                        icon: Symbols.south_west_rounded,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MonthDetailTile(
                        label: 'Expenses',
                        amount: MoneyFormatter.format(data.expenses),
                        color: expenseColor,
                        icon: Symbols.north_east_rounded,
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: netColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: netColor.withValues(alpha: 0.3), width: 1),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            net >= 0
                                ? Symbols.check_rounded
                                : Symbols.trending_up_rounded,
                            color: netColor,
                            size: 20,
                            weight: 500,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Net cash flow',
                            style: AppTypography.rowTitle.copyWith(
                              color: AppColors.getTextColor(isDark),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        MoneyFormatter.formatSigned(net),
                        style: AppTypography.chipAmount.copyWith(
                          color: netColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ===== Overview widgets =====

class _MetricChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool isDark;

  const _MetricChip({
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GlowCard(
      radius: 22,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.monoMetricLabel
                .copyWith(color: AppColors.getTextSecondaryColor(isDark)),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTypography.metricAmount.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

/// Hand-rolled net cash flow bar chart around a zero baseline: positive months
/// float above the line, negatives below. The current month is fully saturated
/// green with glow and a floating value badge. Bars scale to the max |net|.
class _NetCashFlowBars extends StatelessWidget {
  final List<MonthCashFlow> data;
  final DateTime currentMonth;
  final bool isDark;
  final ValueChanged<MonthCashFlow> onBarTap;

  const _NetCashFlowBars({
    required this.data,
    required this.currentMonth,
    required this.isDark,
    required this.onBarTap,
  });

  @override
  Widget build(BuildContext context) {
    const chartHeight = 190.0;
    const baselineY = 116.0; // distance from top of the chart to the zero line
    const maxPositiveBar = 76.0; // room above for the current-month badge
    const maxNegativeBar = 40.0; // keep negatives clear of the label band

    final income = AppColors.getIncome(isDark);
    final danger = AppColors.getDanger(isDark);

    final maxMagnitude = data
        .map((d) => d.netCashFlow.abs())
        .fold(0.0, (previous, value) => max(previous, value));

    double barHeightFor(double net) {
      if (maxMagnitude <= 0) return 0;
      final maxBar = net >= 0 ? maxPositiveBar : maxNegativeBar;
      return (net.abs() / maxMagnitude) * maxBar;
    }

    return SizedBox(
      height: chartHeight,
      child: Stack(
        children: [
          // Zero baseline hairline.
          Positioned(
            left: 0,
            right: 0,
            top: baselineY,
            child: Container(
              height: 1,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.12),
            ),
          ),
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Design uses 34px bars for 6 months; longer ranges shrink the
                // bars so the row never overflows the card.
                final barWidth = data.isEmpty
                    ? 34.0
                    : min(34.0, constraints.maxWidth / data.length - 4);
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final entry in data)
                      _NetCashFlowBar(
                        entry: entry,
                        isCurrent: _isSameMonth(entry.month, currentMonth),
                        isPositive: entry.netCashFlow >= 0,
                        barWidth: barWidth,
                        barHeight: barHeightFor(entry.netCashFlow),
                        baselineY: baselineY,
                        chartHeight: chartHeight,
                        income: income,
                        danger: danger,
                        isDark: isDark,
                        onTap: () {
                          MicroInteractions.lightImpact();
                          onBarTap(entry);
                        },
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  bool _isSameMonth(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month;
}

class _NetCashFlowBar extends StatelessWidget {
  final MonthCashFlow entry;
  final bool isCurrent;
  final bool isPositive;
  final double barWidth;
  final double barHeight;
  final double baselineY;
  final double chartHeight;
  final Color income;
  final Color danger;
  final bool isDark;
  final VoidCallback onTap;

  const _NetCashFlowBar({
    required this.entry,
    required this.isCurrent,
    required this.isPositive,
    required this.barWidth,
    required this.barHeight,
    required this.baselineY,
    required this.chartHeight,
    required this.income,
    required this.danger,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color barColor;
    if (isCurrent) {
      // Current month is fully saturated (green when positive, rose when not).
      barColor = isPositive ? income : danger;
    } else if (isPositive) {
      barColor = income.withValues(alpha: 0.45);
    } else {
      barColor = danger.withValues(alpha: 0.6);
    }

    // Positive bars sit above the baseline; negatives hang below it.
    final double barTop = isPositive ? baselineY - barHeight : baselineY;

    final label = DateFormat.MMM().format(entry.month).toUpperCase();
    // Full grouped amount like the design's "+$2,322"; the pill sizes to fit.
    final net = entry.netCashFlow;
    final signedValue = MoneyFormatter.formatSigned(
      net,
      decimalDigits: 0,
      plusForPositive: true,
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: barWidth,
        height: chartHeight,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: barTop,
              child: Container(
                width: barWidth,
                height: barHeight,
                decoration: BoxDecoration(
                  color: barColor,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: isCurrent
                      ? AppColors.glow(barColor,
                          blurRadius: 20, alpha: 0.6, isDark: isDark)
                      : null,
                ),
              ),
            ),
            // Floating value badge above the current month bar; sized to its
            // content and kept centered over the bar.
            if (isCurrent)
              Positioned(
                top: barTop - 30,
                left: -barWidth * 1.5,
                width: barWidth * 4,
                child: Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: barColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      signedValue,
                      maxLines: 1,
                      softWrap: false,
                      style: AppTypography.badgeSmall.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.getOnAccent(isDark),
                      ),
                    ),
                  ),
                ),
              ),
            // Month labels sit in a fixed band at the bottom so negative bars
            // never overlap them.
            Positioned(
              bottom: 0,
              width: barWidth,
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: AppTypography.monoMonth.copyWith(
                  color: isCurrent
                      ? AppColors.getTextColor(isDark)
                      : AppColors.getTextTertiaryColor(isDark),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _YoyRow extends StatelessWidget {
  final String label;
  final String deltaLabel;
  final Color deltaColor;
  final double thisYearFraction;
  final double lastYearFraction;
  final Color accent;
  final bool isDark;

  const _YoyRow({
    required this.label,
    required this.deltaLabel,
    required this.deltaColor,
    required this.thisYearFraction,
    required this.lastYearFraction,
    required this.accent,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: AppTypography.rowSubtitle.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.getTextSecondaryColor(isDark),
              ),
            ),
            Text(
              deltaLabel,
              style: AppTypography.badge.copyWith(
                fontSize: 13,
                color: deltaColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        GlowProgressBar(
          value: thisYearFraction,
          color: accent,
          height: 12,
        ),
        const SizedBox(height: 4),
        GlowProgressBar(
          value: lastYearFraction,
          color: AppColors.getTrackSecondary(isDark),
          trackColor: AppColors.getTrack(isDark),
          height: 12,
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  final bool isDark;

  const _LegendDot({
    required this.color,
    required this.label,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppTypography.rowSubtitle.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.getTextSecondaryColor(isDark),
          ),
        ),
      ],
    );
  }
}

/// Accent glowing sparkline of monthly net for the trailing 12 months with a
/// dashed zero line and a white endpoint dot.
class _TrendSparkline extends StatelessWidget {
  final List<MonthCashFlow> data;
  final bool isDark;

  const _TrendSparkline({required this.data, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.getAccent(isDark);
    final values = data.map((d) => d.netCashFlow).toList();
    final spots = data
        .asMap()
        .entries
        .map((entry) => FlSpot(entry.key.toDouble(), entry.value.netCashFlow))
        .toList();

    final maxMagnitude =
        values.fold(0.0, (previous, value) => max(previous, value.abs()));
    final bound = maxMagnitude <= 0 ? 100.0 : maxMagnitude * 1.15;

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (data.length - 1).toDouble(),
        minY: -bound,
        maxY: bound,
        lineTouchData: const LineTouchData(enabled: false),
        titlesData: const FlTitlesData(show: false),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        // Dashed zero line.
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            HorizontalLine(
              y: 0,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.12),
              strokeWidth: 1,
              dashArray: [3, 4],
            ),
          ],
        ),
        lineBarsData: [
          // Glow underlay: thicker, low-opacity line beneath the main stroke.
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: accent.withValues(alpha: 0.4),
            barWidth: 9,
            dotData: const FlDotData(show: false),
          ),
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: accent,
            barWidth: 3,
            dotData: FlDotData(
              show: true,
              checkToShowDot: (spot, barData) =>
                  spot.x == (data.length - 1).toDouble(),
              getDotPainter: (spot, percent, barData, index) =>
                  FlDotCirclePainter(
                radius: 5,
                color: const Color(0xFFF2F2FA),
                strokeWidth: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  final Transaction transaction;
  final bool isDark;
  final VoidCallback? onTap;

  const _TransactionRow({
    required this.transaction,
    required this.isDark,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.type == TransactionTyp.income;
    final income = AppColors.getIncome(isDark);
    final tileColor = isIncome ? income : AppColors.getAccent(isDark);
    final icon = _categoryIcon(transaction.category, isIncome);

    // Only income is colored; expenses use primary text (per design).
    final amountColor = isIncome ? income : AppColors.getTextColor(isDark);
    final amount = MoneyFormatter.formatSigned(
      isIncome ? transaction.amount : -transaction.amount,
      plusForPositive: true,
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap == null
          ? null
          : () {
              MicroInteractions.lightImpact();
              onTap!();
            },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        child: Row(
          children: [
            IconTile(icon: icon, color: tileColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.rowTitle
                        .copyWith(color: AppColors.getTextColor(isDark)),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${transaction.category} · ${DateFormat.MMMd().format(transaction.date)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.rowSubtitle.copyWith(
                      color: AppColors.getTextSecondaryColor(isDark),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              amount,
              style: AppTypography.amountSmall.copyWith(color: amountColor),
            ),
          ],
        ),
      ),
    );
  }
}

IconData _categoryIcon(String category, bool isIncome) {
  final map = isIncome ? incomeCategories : expenseCategories;
  return map[category] ??
      (isIncome ? CupertinoIcons.money_dollar : CupertinoIcons.square_grid_2x2);
}

class _MonthDetailTile extends StatelessWidget {
  final String label;
  final String amount;
  final Color color;
  final IconData icon;
  final bool isDark;

  const _MonthDetailTile({
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16, weight: 500),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTypography.rowSubtitle.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.getTextSecondaryColor(isDark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            amount,
            style: AppTypography.amount.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _RangeOptionTile extends StatelessWidget {
  final int months;
  final String label;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  const _RangeOptionTile({
    required this.months,
    required this.label,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.getAccent(isDark);
    return ListTile(
      onTap: onTap,
      title: Text(
        label,
        style: AppTypography.rowTitle.copyWith(
          color: selected ? accent : AppColors.getTextColor(isDark),
          fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
        ),
      ),
      trailing: selected
          ? Icon(Symbols.check_rounded, color: accent, size: 20, weight: 500)
          : null,
    );
  }
}

class _EmptyChartMessage extends StatelessWidget {
  final String message;
  final bool isDark;

  const _EmptyChartMessage({required this.message, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      child: Text(
        message,
        style: AppTypography.rowSubtitle.copyWith(
          fontSize: 13,
          color: AppColors.getTextSecondaryColor(isDark),
        ),
      ),
    );
  }
}

// ===== Transactions drill-in (all existing filter behavior preserved) =====

/// Full filterable transaction list, reached from the Cash Flow "SEE ALL"
/// link. Preserves every filter, the month picker, the category picker and the
/// filtered summary from the original History page.
class _TransactionsDetailPage extends StatefulWidget {
  const _TransactionsDetailPage();

  @override
  State<_TransactionsDetailPage> createState() =>
      _TransactionsDetailPageState();
}

class _TransactionsDetailPageState extends State<_TransactionsDetailPage> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _minAmountController = TextEditingController();
  final TextEditingController _maxAmountController = TextEditingController();

  String _searchQuery = '';
  _HistoryTransactionTypeFilter _typeFilter = _HistoryTransactionTypeFilter.all;
  String? _selectedCategory;
  String? _selectedTagId;
  DateTime? _startDate;
  DateTime? _endDate;
  double? _minAmount;
  double? _maxAmount;

  @override
  void dispose() {
    _searchController.dispose();
    _minAmountController.dispose();
    _maxAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TransactionModel>(
      builder: (context, model, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final availableMonths = model.getAvailableMonths();
        final selectedMonth = model.selectedMonth;
        final filteredTransactions = _getFilteredTransactions(model);
        final categoryOptions = _getCategoryOptions(model.transactions);
        final tags = context.watch<CategorizationProvider>().tags;

        return Scaffold(
          body: SingleChildScrollView(
            physics: PlatformUtils.platformScrollPhysics,
            padding: EdgeInsets.only(
              bottom: DockMetrics.contentBottomPadding(context),
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildDetailHeader(
                      context, model, availableMonths, selectedMonth, isDark),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _buildFiltersCard(
                      context,
                      model,
                      categoryOptions,
                      tags,
                      isDark,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _buildFilteredTransactionsCard(
                      context,
                      filteredTransactions,
                      model.transactions.length,
                      isDark,
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

  // ===== Filtering =====

  List<Transaction> _getFilteredTransactions(TransactionModel model) {
    final query = _searchQuery.toLowerCase();
    final transactions = List<Transaction>.from(model.transactions)
      ..sort(Transaction.compareNewestFirst);

    return transactions.where((transaction) {
      if (query.isNotEmpty &&
          !transaction.description.toLowerCase().contains(query)) {
        return false;
      }
      if (_typeFilter == _HistoryTransactionTypeFilter.income &&
          transaction.type != TransactionTyp.income) {
        return false;
      }
      if (_typeFilter == _HistoryTransactionTypeFilter.expense &&
          transaction.type != TransactionTyp.expense) {
        return false;
      }
      if (_selectedCategory != null &&
          transaction.category != _selectedCategory) {
        return false;
      }
      if (_selectedTagId != null &&
          !transaction.tagIds.contains(_selectedTagId)) {
        return false;
      }
      if (_startDate != null &&
          _dateOnly(transaction.date).isBefore(_dateOnly(_startDate!))) {
        return false;
      }
      if (_endDate != null &&
          _dateOnly(transaction.date).isAfter(_dateOnly(_endDate!))) {
        return false;
      }
      if (_minAmount != null && transaction.amount < _minAmount!) {
        return false;
      }
      if (_maxAmount != null && transaction.amount > _maxAmount!) {
        return false;
      }
      return true;
    }).toList();
  }

  List<String> _getCategoryOptions(List<Transaction> transactions) {
    final categories = transactions
        .map((transaction) => transaction.category)
        .where((category) => category.trim().isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return categories;
  }

  _FilteredTransactionSummary _buildFilteredSummary(
    List<Transaction> transactions,
  ) {
    final income = transactions
        .where((transaction) => transaction.type == TransactionTyp.income)
        .fold(0.0, (sum, transaction) => sum + transaction.amount);
    final expenses = transactions
        .where((transaction) => transaction.type == TransactionTyp.expense)
        .fold(0.0, (sum, transaction) => sum + transaction.amount);
    return _FilteredTransactionSummary(
      income: income,
      expenses: expenses,
      count: transactions.length,
    );
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  bool get _hasActiveFilters {
    return _searchQuery.isNotEmpty ||
        _typeFilter != _HistoryTransactionTypeFilter.all ||
        _selectedCategory != null ||
        _selectedTagId != null ||
        _startDate != null ||
        _endDate != null ||
        _minAmount != null ||
        _maxAmount != null;
  }

  void _resetFilters() {
    setState(() {
      _searchController.clear();
      _minAmountController.clear();
      _maxAmountController.clear();
      _searchQuery = '';
      _typeFilter = _HistoryTransactionTypeFilter.all;
      _selectedCategory = null;
      _selectedTagId = null;
      _startDate = null;
      _endDate = null;
      _minAmount = null;
      _maxAmount = null;
    });
  }

  String _formatCurrency(double value) {
    return MoneyFormatter.format(value);
  }

  String _formatSignedCurrency(double value) {
    return MoneyFormatter.formatSigned(value, plusForPositive: true);
  }

  double? _parseAmount(String value) {
    final normalized = value.replaceAll(',', '').trim();
    if (normalized.isEmpty) return null;
    return double.tryParse(normalized);
  }

  // ===== Header =====

  Widget _buildDetailHeader(
    BuildContext context,
    TransactionModel model,
    List<DateTime> availableMonths,
    DateTime selectedMonth,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              MicroInteractions.lightImpact();
              Navigator.of(context).maybePop();
            },
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.getChipSurface(isDark),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.getCardBorder(isDark)),
              ),
              alignment: Alignment.center,
              child: Icon(
                Symbols.chevron_left_rounded,
                size: 20,
                weight: 500,
                color: AppColors.getTextColor(isDark),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Transactions',
              style: AppTypography.pageTitle
                  .copyWith(color: AppColors.getTextColor(isDark)),
            ),
          ),
          if (availableMonths.isNotEmpty)
            MonthPill(
              label: DateFormat.MMMM().format(selectedMonth),
              onTap: () => _showMonthPicker(
                  context, model, availableMonths, selectedMonth),
            ),
        ],
      ),
    );
  }

  // ===== Filters card =====

  Widget _buildFiltersCard(
    BuildContext context,
    TransactionModel model,
    List<String> categoryOptions,
    List<TransactionTag> tags,
    bool isDark,
  ) {
    return GlowCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Filters',
                  style: AppTypography.cardTitle
                      .copyWith(color: AppColors.getTextColor(isDark)),
                ),
              ),
              if (_hasActiveFilters)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    MicroInteractions.lightImpact();
                    _resetFilters();
                  },
                  child: Text(
                    'RESET',
                    style: AppTypography.monoLink
                        .copyWith(color: AppColors.getAccent(isDark)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          _buildSearchField(context, isDark),
          const SizedBox(height: 12),
          _buildTypeFilter(context, isDark),
          const SizedBox(height: 12),
          _buildFilterButton(
            context,
            label: 'Category',
            value: _selectedCategory ?? 'All categories',
            icon: Symbols.grid_view_rounded,
            isDark: isDark,
            onTap: () => _showCategoryPicker(context, categoryOptions, isDark),
          ),
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('All tags'),
                  selected: _selectedTagId == null,
                  onSelected: (_) => setState(() => _selectedTagId = null),
                ),
                for (final tag in tags)
                  ChoiceChip(
                    label: Text(tag.name),
                    selected: _selectedTagId == tag.id,
                    onSelected: (selected) => setState(() {
                      _selectedTagId = selected ? tag.id : null;
                    }),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildFilterButton(
                  context,
                  label: 'From',
                  value: _startDate == null
                      ? 'Any date'
                      : DateFormat.MMMd().format(_startDate!),
                  icon: Symbols.expand_more_rounded,
                  isDark: isDark,
                  onTap: () => _pickDateRangeEndpoint(context, isStart: true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildFilterButton(
                  context,
                  label: 'To',
                  value: _endDate == null
                      ? 'Any date'
                      : DateFormat.MMMd().format(_endDate!),
                  icon: Symbols.expand_more_rounded,
                  isDark: isDark,
                  onTap: () => _pickDateRangeEndpoint(context, isStart: false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildAmountField(
                  context,
                  controller: _minAmountController,
                  label: 'Min amount',
                  isDark: isDark,
                  onChanged: (value) => setState(() {
                    _minAmount = _parseAmount(value);
                  }),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildAmountField(
                  context,
                  controller: _maxAmountController,
                  label: 'Max amount',
                  isDark: isDark,
                  onChanged: (value) => setState(() {
                    _maxAmount = _parseAmount(value);
                  }),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField(BuildContext context, bool isDark) {
    return TextField(
      controller: _searchController,
      onChanged: (value) => setState(() => _searchQuery = value.trim()),
      style: AppTypography.rowTitle
          .copyWith(color: AppColors.getTextColor(isDark)),
      decoration: InputDecoration(
        prefixIcon: Icon(
          Symbols.grid_view_rounded,
          color: AppColors.getTextSecondaryColor(isDark),
          size: 20,
          weight: 500,
        ),
        suffixIcon: _searchQuery.isEmpty
            ? null
            : IconButton(
                icon: Icon(
                  Symbols.remove_rounded,
                  color: AppColors.getTextSecondaryColor(isDark),
                  size: 18,
                  weight: 500,
                ),
                onPressed: () {
                  setState(() {
                    _searchController.clear();
                    _searchQuery = '';
                  });
                },
              ),
        hintText: 'Search descriptions',
        hintStyle: AppTypography.rowTitle.copyWith(
          fontWeight: FontWeight.w400,
          color: AppColors.getTextSecondaryColor(isDark),
        ),
        filled: true,
        fillColor: AppColors.getChipSurface(isDark),
        border: _fieldBorder(isDark),
        enabledBorder: _fieldBorder(isDark),
        focusedBorder: _fieldBorder(isDark, focused: true),
      ),
    );
  }

  OutlineInputBorder _fieldBorder(bool isDark, {bool focused = false}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(
        color: focused
            ? AppColors.getAccent(isDark)
            : AppColors.getCardBorder(isDark),
        width: focused ? 1.5 : 1,
      ),
    );
  }

  Widget _buildTypeFilter(BuildContext context, bool isDark) {
    return SegmentedPillControl(
      segments: const ['All', 'Income', 'Expense'],
      selectedIndex: _typeFilter.index,
      onChanged: (index) {
        setState(
            () => _typeFilter = _HistoryTransactionTypeFilter.values[index]);
      },
    );
  }

  Widget _buildAmountField(
    BuildContext context, {
    required TextEditingController controller,
    required String label,
    required bool isDark,
    required ValueChanged<String> onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: onChanged,
      style: AppTypography.rowTitle
          .copyWith(color: AppColors.getTextColor(isDark)),
      decoration: InputDecoration(
        labelText: label,
        prefixText: '\$ ',
        prefixStyle: AppTypography.rowTitle
            .copyWith(color: AppColors.getTextSecondaryColor(isDark)),
        labelStyle: AppTypography.rowSubtitle
            .copyWith(color: AppColors.getTextSecondaryColor(isDark)),
        filled: true,
        fillColor: AppColors.getChipSurface(isDark),
        border: _fieldBorder(isDark),
        enabledBorder: _fieldBorder(isDark),
        focusedBorder: _fieldBorder(isDark, focused: true),
      ),
    );
  }

  Widget _buildFilterButton(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        MicroInteractions.lightImpact();
        onTap();
      },
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.getChipSurface(isDark),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.getCardBorder(isDark)),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: AppColors.getTextSecondaryColor(isDark),
                size: 18,
                weight: 500),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: AppTypography.rowSubtitle.copyWith(
                      fontSize: 11,
                      color: AppColors.getTextSecondaryColor(isDark),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.rowTitle
                        .copyWith(color: AppColors.getTextColor(isDark)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Symbols.expand_more_rounded,
              color: AppColors.getTextSecondaryColor(isDark),
              size: 16,
              weight: 500,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDateRangeEndpoint(
    BuildContext context, {
    required bool isStart,
  }) async {
    final now = DateTime.now();
    final initialDate =
        isStart ? _startDate ?? _endDate ?? now : _endDate ?? _startDate ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 10, 12, 31),
    );

    if (picked == null) return;

    setState(() {
      if (isStart) {
        _startDate = picked;
        if (_endDate != null &&
            _dateOnly(_endDate!).isBefore(_dateOnly(picked))) {
          _endDate = picked;
        }
      } else {
        _endDate = picked;
        if (_startDate != null &&
            _dateOnly(_startDate!).isAfter(_dateOnly(picked))) {
          _startDate = picked;
        }
      }
    });
  }

  void _showCategoryPicker(
    BuildContext context,
    List<String> categories,
    bool isDark,
  ) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: AppColors.getCard(isDark),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: AppColors.getCardBorder(isDark)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.getTextTertiaryColor(isDark)
                      .withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'SELECT CATEGORY',
                    style: AppTypography.eyebrow.copyWith(
                        color: AppColors.getTextTertiaryColor(isDark)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    _buildCategoryOptionTile(ctx, null, isDark),
                    ...categories.map(
                      (category) =>
                          _buildCategoryOptionTile(ctx, category, isDark),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryOptionTile(
    BuildContext context,
    String? category,
    bool isDark,
  ) {
    final isSelected = _selectedCategory == category;
    final accent = AppColors.getAccent(isDark);
    return ListTile(
      title: Text(
        category ?? 'All categories',
        style: AppTypography.rowTitle.copyWith(
          color: isSelected ? accent : AppColors.getTextColor(isDark),
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
        ),
      ),
      trailing: isSelected
          ? Icon(Symbols.check_rounded, color: accent, size: 20, weight: 500)
          : null,
      onTap: () {
        MicroInteractions.selectionClick();
        setState(() => _selectedCategory = category);
        Navigator.pop(context);
      },
    );
  }

  void _showMonthPicker(
    BuildContext context,
    TransactionModel model,
    List<DateTime> availableMonths,
    DateTime selectedMonth,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = AppColors.getAccent(isDark);
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: AppColors.getCard(isDark),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: AppColors.getCardBorder(isDark)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.getTextTertiaryColor(isDark)
                      .withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'SELECT MONTH',
                    style: AppTypography.eyebrow.copyWith(
                        color: AppColors.getTextTertiaryColor(isDark)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: ListView(
                  shrinkWrap: true,
                  children: availableMonths.map((month) {
                    final isSelected = month.year == selectedMonth.year &&
                        month.month == selectedMonth.month;
                    return ListTile(
                      title: Text(
                        DateFormat.yMMMM().format(month),
                        style: AppTypography.rowTitle.copyWith(
                          color: isSelected
                              ? accent
                              : AppColors.getTextColor(isDark),
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w600,
                        ),
                      ),
                      trailing: isSelected
                          ? Icon(Symbols.check_rounded,
                              color: accent, size: 20, weight: 500)
                          : null,
                      onTap: () {
                        MicroInteractions.selectionClick();
                        model.selectMonth(month);
                        Navigator.pop(ctx);
                      },
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // ===== Filtered transactions card =====

  Widget _buildFilteredTransactionsCard(
    BuildContext context,
    List<Transaction> transactions,
    int totalTransactionCount,
    bool isDark,
  ) {
    final summary = _buildFilteredSummary(transactions);
    final visibleTransactions = transactions.take(50).toList();
    final income = AppColors.getIncome(isDark);
    final danger = AppColors.getDanger(isDark);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  'Results',
                  style: AppTypography.sectionHeader
                      .copyWith(color: AppColors.getTextColor(isDark)),
                ),
              ),
              Text(
                '${transactions.length} of $totalTransactionCount',
                style: AppTypography.monoLabel
                    .copyWith(color: AppColors.getTextSecondaryColor(isDark)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            PillChip(
              label: 'Income ${_formatCurrency(summary.income)}',
              color: income,
            ),
            PillChip(
              label: 'Expenses ${_formatCurrency(summary.expenses)}',
              color: danger,
            ),
            PillChip(
              label: 'Net ${_formatSignedCurrency(summary.netCashFlow)}',
              color: summary.netCashFlow >= 0 ? income : danger,
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (transactions.isEmpty)
          GlowCard(
            child: _EmptyChartMessage(
              message: _hasActiveFilters
                  ? 'No transactions match these filters.'
                  : 'No transactions have been recorded yet.',
              isDark: isDark,
            ),
          )
        else ...[
          GlowListCard(
            children: [
              for (final transaction in visibleTransactions)
                _TransactionRow(transaction: transaction, isDark: isDark),
            ],
          ),
          if (transactions.length > visibleTransactions.length) ...[
            const SizedBox(height: 12),
            Center(
              child: Text(
                'Showing latest ${visibleTransactions.length} matches',
                style: AppTypography.rowSubtitle.copyWith(
                  fontSize: 13,
                  color: AppColors.getTextSecondaryColor(isDark),
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }
}

// ===== Data classes =====

class _MonthlyCashFlowReport {
  final DateTime month;
  final double income;
  final double expenses;

  const _MonthlyCashFlowReport({
    required this.month,
    required this.income,
    required this.expenses,
  });

  double get netCashFlow => income - expenses;
}

class _FilteredTransactionSummary {
  final double income;
  final double expenses;
  final int count;

  const _FilteredTransactionSummary({
    required this.income,
    required this.expenses,
    required this.count,
  });

  double get netCashFlow => income - expenses;
}
