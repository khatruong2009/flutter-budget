import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'transaction_model.dart';
import 'design_system.dart';
import 'utils/platform_utils.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({Key? key}) : super(key: key);

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  @override
  Widget build(BuildContext context) {
    return Consumer<TransactionModel>(
      builder: (context, model, child) {
        final allChartData = model.getNetCashFlowHistory();
        final availableMonths = model.getAvailableMonths();
        final selectedMonth = model.selectedMonth;

        final chartData = _getChartDisplayData(allChartData, selectedMonth);
        final metrics = _computeMetrics(chartData);

        return Scaffold(
          appBar: AppBar(
            title: Text(
              'Cash Flow Analysis',
              style: AppTypography.headingMedium.copyWith(
                color: AppDesign.getTextPrimary(context),
                fontWeight: FontWeight.bold,
              ),
            ),
            centerTitle: true,
            backgroundColor: AppDesign.getBackgroundColor(context),
            elevation: 0,
            surfaceTintColor: Colors.transparent,
          ),
          backgroundColor: AppDesign.getBackgroundColor(context),
          body: SingleChildScrollView(
            physics: PlatformUtils.platformScrollPhysics,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMonthDropdown(
                    context, model, availableMonths, selectedMonth),
                const SizedBox(height: 16),
                if (chartData.isNotEmpty) _buildChartCard(context, chartData),
                const SizedBox(height: 16),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _buildMetricCard(
                          context,
                          label: 'Average Monthly Savings',
                          value:
                              '\$${NumberFormat("#,##0.00", "en_US").format(metrics['avgSavings'] ?? 0.0)}',
                          isPositive: (metrics['avgSavings'] ?? 0.0) >= 0,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMetricCard(
                          context,
                          label: 'Savings Rate %',
                          value:
                              '${(metrics['savingsRate'] ?? 0.0).toStringAsFixed(0)}%',
                          isPositive: (metrics['savingsRate'] ?? 0.0) >= 0,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<MonthCashFlow> _getChartDisplayData(
      List<MonthCashFlow> allData, DateTime selectedMonth) {
    final filtered = allData
        .where((d) =>
            d.month.year < selectedMonth.year ||
            (d.month.year == selectedMonth.year &&
                d.month.month <= selectedMonth.month))
        .toList();
    if (filtered.length > 6) {
      return filtered.sublist(filtered.length - 6);
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

  Widget _buildMonthDropdown(BuildContext context, TransactionModel model,
      List<DateTime> availableMonths, DateTime selectedMonth) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: availableMonths.isEmpty
          ? null
          : () =>
              _showMonthPicker(context, model, availableMonths, selectedMonth),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : AppColors.cardLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              DateFormat.MMMM().format(selectedMonth),
              style: AppTypography.bodyLarge.copyWith(
                color: AppDesign.getTextPrimary(context),
                fontWeight: FontWeight.w500,
              ),
            ),
            Icon(
              CupertinoIcons.chevron_down,
              color: AppDesign.getTextSecondary(context),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  void _showMonthPicker(BuildContext context, TransactionModel model,
      List<DateTime> availableMonths, DateTime selectedMonth) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : AppColors.cardLight,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color:
                      AppDesign.getTextTertiary(context).withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Select Month',
                    style: AppTypography.headingSmall.copyWith(
                      color: AppDesign.getTextPrimary(context),
                      fontWeight: FontWeight.bold,
                    ),
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
                        style: AppTypography.bodyLarge.copyWith(
                          color: isSelected
                              ? AppColors.primary
                              : AppDesign.getTextPrimary(context),
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(CupertinoIcons.checkmark,
                              color: AppColors.primary, size: 18)
                          : null,
                      onTap: () {
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

  Widget _buildChartCard(BuildContext context, List<MonthCashFlow> chartData) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Monthly Trends: Income vs. Expenses',
            style: AppTypography.bodyLarge.copyWith(
              color: AppDesign.getTextPrimary(context),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: _buildStackedBarChart(context, chartData, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildStackedBarChart(
      BuildContext context, List<MonthCashFlow> chartData, bool isDark) {
    final incomeColor = AppColors.getIncome(isDark);
    final expenseColor = AppColors.getExpense(isDark);

    // Bar height = income; red portion = expenses, green portion = savings
    final maxIncome =
        chartData.map((d) => d.income).fold(0.0, (a, b) => a > b ? a : b);
    final maxY = _roundUpNice(maxIncome * 1.15);
    final interval = maxY / 2;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        minY: 0,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => Colors.transparent,
            getTooltipItem: (_, __, ___, ____) => null,
          ),
          touchCallback: (FlTouchEvent event, BarTouchResponse? response) {
            if (event is! FlTapUpEvent) return;
            final index = response?.spot?.touchedBarGroupIndex;
            if (index == null || index < 0 || index >= chartData.length) return;
            _showMonthDetailsBottomSheet(chartData[index], isDark);
          },
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= chartData.length) {
                  return const SizedBox.shrink();
                }
                return SideTitleWidget(
                  meta: meta,
                  child: Text(
                    DateFormat.MMM().format(chartData[index].month),
                    style: AppTypography.bodySmall.copyWith(
                      color: AppDesign.getTextSecondary(context),
                      fontSize: 12,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 48,
              interval: interval,
              getTitlesWidget: (value, meta) {
                final label = value >= 1000
                    ? '\$${(value / 1000).toStringAsFixed(0)}k'
                    : '\$${value.toStringAsFixed(0)}';
                return SideTitleWidget(
                  meta: meta,
                  child: Text(
                    label,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppDesign.getTextSecondary(context),
                      fontSize: 11,
                    ),
                  ),
                );
              },
            ),
          ),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: interval,
          getDrawingHorizontalLine: (value) => FlLine(
            color: (isDark ? AppColors.borderDark : AppColors.borderLight)
                .withValues(alpha: 0.5),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: chartData.asMap().entries.map((entry) {
          final data = entry.value;
          final expenses = data.expenses.clamp(0.0, data.income);
          final savings = (data.income - expenses).clamp(0.0, double.infinity);
          return BarChartGroupData(
            x: entry.key,
            barRods: [
              BarChartRodData(
                toY: data.income,
                rodStackItems: [
                  BarChartRodStackItem(0, expenses, expenseColor),
                  BarChartRodStackItem(
                      expenses, expenses + savings, incomeColor),
                ],
                width: 28,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(5),
                  topRight: Radius.circular(5),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  double _roundUpNice(double value) {
    if (value <= 0) return 1000;
    final magnitude = pow(10, (log(value) / ln10).floor()).toDouble();
    final normalized = (value / magnitude).ceil();
    return normalized * magnitude;
  }

  void _showMonthDetailsBottomSheet(MonthCashFlow data, bool isDark) {
    final fmt = NumberFormat("#,##0.00", "en_US");
    final incomeColor = AppColors.getIncome(isDark);
    final expenseColor = AppColors.getExpense(isDark);
    final net = data.income - data.expenses;
    final netColor = net >= 0 ? incomeColor : expenseColor;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : AppColors.cardLight,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
                    color:
                        AppDesign.getTextTertiary(ctx).withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: netColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(CupertinoIcons.calendar,
                          color: netColor, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      DateFormat.yMMMM().format(data.month),
                      style: AppTypography.headingMedium.copyWith(
                        color: AppDesign.getTextPrimary(ctx),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _buildDetailTile(
                        ctx,
                        label: 'Income',
                        amount: '\$${fmt.format(data.income)}',
                        color: incomeColor,
                        icon: CupertinoIcons.arrow_down_circle_fill,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildDetailTile(
                        ctx,
                        label: 'Expenses',
                        amount: '\$${fmt.format(data.expenses)}',
                        color: expenseColor,
                        icon: CupertinoIcons.arrow_up_circle_fill,
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
                    borderRadius: BorderRadius.circular(12),
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
                                ? CupertinoIcons.checkmark_circle_fill
                                : CupertinoIcons.exclamationmark_circle_fill,
                            color: netColor,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Net Cash Flow',
                            style: AppTypography.bodyLarge.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppDesign.getTextPrimary(ctx),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '\$${fmt.format(net)}',
                        style: AppTypography.headingMedium.copyWith(
                          fontWeight: FontWeight.bold,
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

  Widget _buildDetailTile(
    BuildContext context, {
    required String label,
    required String amount,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTypography.bodySmall.copyWith(
                  color: AppDesign.getTextSecondary(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            amount,
            style: AppTypography.headingSmall.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 17,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
    BuildContext context, {
    required String label,
    required String value,
    required bool isPositive,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor =
        isPositive ? AppColors.getIncome(isDark) : AppColors.getExpense(isDark);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              color: AppDesign.getTextSecondary(context),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  value,
                  style: AppTypography.headingSmall.copyWith(
                    color: AppDesign.getTextPrimary(context),
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                isPositive
                    ? CupertinoIcons.arrow_up
                    : CupertinoIcons.arrow_down,
                color: accentColor,
                size: 20,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
