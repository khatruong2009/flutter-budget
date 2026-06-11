import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'transaction_model.dart';
import 'transaction.dart';
import 'design_system.dart';
import 'utils/platform_utils.dart';

enum _HistoryTransactionTypeFilter { all, income, expense }

class HistoryPage extends StatefulWidget {
  const HistoryPage({Key? key}) : super(key: key);

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _minAmountController = TextEditingController();
  final TextEditingController _maxAmountController = TextEditingController();

  String _searchQuery = '';
  _HistoryTransactionTypeFilter _typeFilter = _HistoryTransactionTypeFilter.all;
  String? _selectedCategory;
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
        final allChartData = model.getNetCashFlowHistory();
        final availableMonths = model.getAvailableMonths();
        final selectedMonth = model.selectedMonth;

        final chartData = _getChartDisplayData(allChartData, selectedMonth);
        final metrics = _computeMetrics(chartData);
        final currentReport =
            _buildMonthReport(model.transactions, selectedMonth);
        final previousYearMonth =
            DateTime(selectedMonth.year - 1, selectedMonth.month);
        final previousReport =
            _buildMonthReport(model.transactions, previousYearMonth);
        final rollingTrendData =
            _getRollingTrendData(model.transactions, selectedMonth);
        final filteredTransactions = _getFilteredTransactions(model);
        final categoryOptions = _getCategoryOptions(model.transactions);

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
                const SizedBox(height: 16),
                _buildYearOverYearReportCard(
                  context,
                  currentReport,
                  previousReport,
                ),
                const SizedBox(height: 16),
                _buildRollingTrendCard(context, rollingTrendData),
                const SizedBox(height: 16),
                _buildFiltersCard(context, model, categoryOptions),
                const SizedBox(height: 16),
                _buildFilteredTransactionsCard(
                  context,
                  filteredTransactions,
                  model.transactions.length,
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
    final categoryExpenses = <String, double>{};

    for (final transaction in monthTransactions) {
      if (transaction.type != TransactionTyp.expense) continue;
      categoryExpenses.update(
        transaction.category,
        (value) => value + transaction.amount,
        ifAbsent: () => transaction.amount,
      );
    }

    return _MonthlyCashFlowReport(
      month: DateTime(month.year, month.month),
      income: income,
      expenses: expenses,
      categoryExpenses: categoryExpenses,
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

  List<Transaction> _getFilteredTransactions(TransactionModel model) {
    final query = _searchQuery.toLowerCase();
    final transactions = List<Transaction>.from(model.transactions)
      ..sort((a, b) => b.date.compareTo(a.date));

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

  bool _isSameMonth(DateTime date, DateTime month) {
    return date.year == month.year && date.month == month.month;
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  bool get _hasActiveFilters {
    return _searchQuery.isNotEmpty ||
        _typeFilter != _HistoryTransactionTypeFilter.all ||
        _selectedCategory != null ||
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
      _startDate = null;
      _endDate = null;
      _minAmount = null;
      _maxAmount = null;
    });
  }

  String _formatCurrency(double value) {
    return '\$${NumberFormat("#,##0.00", "en_US").format(value)}';
  }

  String _formatSignedCurrency(double value) {
    final sign = value > 0
        ? '+'
        : value < 0
            ? '-'
            : '';
    return '$sign\$${NumberFormat("#,##0.00", "en_US").format(value.abs())}';
  }

  String _formatCompactCurrency(double value) {
    final absValue = value.abs();
    final prefix = value < 0 ? '-\$' : '\$';
    if (absValue >= 1000000) {
      return '$prefix${(absValue / 1000000).toStringAsFixed(absValue >= 10000000 ? 0 : 1)}m';
    }
    if (absValue >= 1000) {
      return '$prefix${(absValue / 1000).toStringAsFixed(absValue >= 10000 ? 0 : 1)}k';
    }
    return '$prefix${absValue.toStringAsFixed(0)}';
  }

  Widget _buildYearOverYearReportCard(
    BuildContext context,
    _MonthlyCashFlowReport currentReport,
    _MonthlyCashFlowReport previousReport,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppDesign.getCardColor(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildReportHeader(
            context,
            title: 'Year-over-Year Comparison',
            subtitle:
                '${DateFormat.yMMM().format(currentReport.month)} vs ${DateFormat.yMMM().format(previousReport.month)}',
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 240,
            child: _buildTotalYearOverYearChart(
              context,
              currentReport,
              previousReport,
            ),
          ),
          const SizedBox(height: 16),
          _buildYearOverYearLegend(context, currentReport, previousReport),
          const SizedBox(height: 20),
          Text(
            'Expense Categories',
            style: AppTypography.bodyLarge.copyWith(
              color: AppDesign.getTextPrimary(context),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildCategoryYearOverYearChart(
            context,
            currentReport,
            previousReport,
          ),
        ],
      ),
    );
  }

  Widget _buildRollingTrendCard(
    BuildContext context,
    List<MonthCashFlow> trendData,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppDesign.getCardColor(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildReportHeader(
            context,
            title: '12-Month Rolling Trend',
            subtitle:
                'Net cash flow ending ${DateFormat.yMMM().format(trendData.last.month)}',
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: _buildRollingTrendLineChart(context, trendData),
          ),
        ],
      ),
    );
  }

  Widget _buildReportHeader(
    BuildContext context, {
    required String title,
    required String subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTypography.bodyLarge.copyWith(
            color: AppDesign.getTextPrimary(context),
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: AppTypography.bodySmall.copyWith(
            color: AppDesign.getTextSecondary(context),
          ),
        ),
      ],
    );
  }

  Widget _buildYearOverYearLegend(
    BuildContext context,
    _MonthlyCashFlowReport currentReport,
    _MonthlyCashFlowReport previousReport,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        _buildLegendItem(
          context,
          DateFormat.yMMM().format(currentReport.month),
          AppColors.primary,
        ),
        _buildLegendItem(
          context,
          DateFormat.yMMM().format(previousReport.month),
          AppColors.getNeutral(isDark),
        ),
      ],
    );
  }

  Widget _buildLegendItem(BuildContext context, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppTypography.bodySmall.copyWith(
            color: AppDesign.getTextSecondary(context),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildTotalYearOverYearChart(
    BuildContext context,
    _MonthlyCashFlowReport currentReport,
    _MonthlyCashFlowReport previousReport,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final values = [
      currentReport.income,
      previousReport.income,
      currentReport.expenses,
      previousReport.expenses,
      currentReport.netCashFlow,
      previousReport.netCashFlow,
    ];
    final bounds = _getChartBounds(values);
    const currentColor = AppColors.primary;
    final previousColor = AppColors.getNeutral(isDark);
    final groups = [
      _ComparisonChartGroup(
        label: 'Income',
        currentValue: currentReport.income,
        previousValue: previousReport.income,
      ),
      _ComparisonChartGroup(
        label: 'Expenses',
        currentValue: currentReport.expenses,
        previousValue: previousReport.expenses,
      ),
      _ComparisonChartGroup(
        label: 'Net',
        currentValue: currentReport.netCashFlow,
        previousValue: previousReport.netCashFlow,
      ),
    ];

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        minY: bounds.minY,
        maxY: bounds.maxY,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => AppDesign.getCardColor(context),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final item = groups[group.x.toInt()];
              final label = rodIndex == 0 ? 'Current' : 'Previous';
              final value =
                  rodIndex == 0 ? item.currentValue : item.previousValue;
              return BarTooltipItem(
                '$label\n${_formatCurrency(value)}',
                AppTypography.bodySmall.copyWith(
                  color: AppDesign.getTextPrimary(context),
                  fontWeight: FontWeight.w600,
                ),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= groups.length) {
                  return const SizedBox.shrink();
                }
                return SideTitleWidget(
                  meta: meta,
                  child: Text(
                    groups[index].label,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppDesign.getTextSecondary(context),
                      fontSize: 11,
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
              interval: bounds.interval,
              getTitlesWidget: (value, meta) => SideTitleWidget(
                meta: meta,
                child: Text(
                  _formatCompactCurrency(value),
                  style: AppTypography.bodySmall.copyWith(
                    color: AppDesign.getTextSecondary(context),
                    fontSize: 11,
                  ),
                ),
              ),
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
          horizontalInterval: bounds.interval,
          getDrawingHorizontalLine: (value) => FlLine(
            color: AppDesign.getBorderColor(context).withValues(alpha: 0.5),
            strokeWidth: value == 0 ? 1.5 : 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: groups.asMap().entries.map((entry) {
          final group = entry.value;
          return BarChartGroupData(
            x: entry.key,
            barsSpace: 5,
            barRods: [
              _buildComparisonRod(group.currentValue, currentColor),
              _buildComparisonRod(group.previousValue, previousColor),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCategoryYearOverYearChart(
    BuildContext context,
    _MonthlyCashFlowReport currentReport,
    _MonthlyCashFlowReport previousReport,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final categories = {
      ...currentReport.categoryExpenses.keys,
      ...previousReport.categoryExpenses.keys,
    }.toList()
      ..sort((a, b) {
        final bTotal = (currentReport.categoryExpenses[b] ?? 0) +
            (previousReport.categoryExpenses[b] ?? 0);
        final aTotal = (currentReport.categoryExpenses[a] ?? 0) +
            (previousReport.categoryExpenses[a] ?? 0);
        return bTotal.compareTo(aTotal);
      });
    final visibleCategories = categories.take(8).toList();

    if (visibleCategories.isEmpty) {
      return _buildEmptyMessage(
        context,
        'No expense categories found for either month.',
      );
    }

    final values = visibleCategories
        .expand(
          (category) => [
            currentReport.categoryExpenses[category] ?? 0.0,
            previousReport.categoryExpenses[category] ?? 0.0,
          ],
        )
        .toList();
    final bounds = _getChartBounds(values, forcePositive: true);
    final currentColor = AppColors.getExpense(isDark);
    final previousColor = AppColors.getNeutral(isDark);
    final chartWidth = max(520.0, visibleCategories.length * 86.0);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: PlatformUtils.platformScrollPhysics,
      child: SizedBox(
        width: chartWidth,
        height: 260,
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            minY: 0,
            maxY: bounds.maxY,
            barTouchData: BarTouchData(
              enabled: true,
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => AppDesign.getCardColor(context),
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final category = visibleCategories[group.x.toInt()];
                  final label = rodIndex == 0 ? 'Current' : 'Previous';
                  final value = rodIndex == 0
                      ? currentReport.categoryExpenses[category] ?? 0.0
                      : previousReport.categoryExpenses[category] ?? 0.0;
                  return BarTooltipItem(
                    '$category\n$label ${_formatCurrency(value)}',
                    AppTypography.bodySmall.copyWith(
                      color: AppDesign.getTextPrimary(context),
                      fontWeight: FontWeight.w600,
                    ),
                  );
                },
              ),
            ),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 48,
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (index < 0 || index >= visibleCategories.length) {
                      return const SizedBox.shrink();
                    }
                    return SideTitleWidget(
                      meta: meta,
                      child: SizedBox(
                        width: 68,
                        child: Text(
                          visibleCategories[index],
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppDesign.getTextSecondary(context),
                            fontSize: 10,
                          ),
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
                  interval: bounds.interval,
                  getTitlesWidget: (value, meta) => SideTitleWidget(
                    meta: meta,
                    child: Text(
                      _formatCompactCurrency(value),
                      style: AppTypography.bodySmall.copyWith(
                        color: AppDesign.getTextSecondary(context),
                        fontSize: 11,
                      ),
                    ),
                  ),
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
              horizontalInterval: bounds.interval,
              getDrawingHorizontalLine: (value) => FlLine(
                color: AppDesign.getBorderColor(context).withValues(alpha: 0.5),
                strokeWidth: 1,
              ),
            ),
            borderData: FlBorderData(show: false),
            barGroups: visibleCategories.asMap().entries.map((entry) {
              final category = entry.value;
              return BarChartGroupData(
                x: entry.key,
                barsSpace: 4,
                barRods: [
                  _buildComparisonRod(
                    currentReport.categoryExpenses[category] ?? 0.0,
                    currentColor,
                  ),
                  _buildComparisonRod(
                    previousReport.categoryExpenses[category] ?? 0.0,
                    previousColor,
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildRollingTrendLineChart(
    BuildContext context,
    List<MonthCashFlow> trendData,
  ) {
    final values = trendData.map((data) => data.netCashFlow).toList();
    final bounds = _getChartBounds(values);
    final spots = trendData
        .asMap()
        .entries
        .map((entry) => FlSpot(entry.key.toDouble(), entry.value.netCashFlow))
        .toList();

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (trendData.length - 1).toDouble(),
        minY: bounds.minY,
        maxY: bounds.maxY,
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppDesign.getCardColor(context),
            getTooltipItems: (spots) {
              return spots.map((spot) {
                final index = spot.x.toInt();
                final data = trendData[index];
                return LineTooltipItem(
                  '${DateFormat.yMMM().format(data.month)}\n${_formatCurrency(data.netCashFlow)}',
                  AppTypography.bodySmall.copyWith(
                    color: AppDesign.getTextPrimary(context),
                    fontWeight: FontWeight.w600,
                  ),
                );
              }).toList();
            },
          ),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: 2,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= trendData.length || index.isOdd) {
                  return const SizedBox.shrink();
                }
                return SideTitleWidget(
                  meta: meta,
                  child: Text(
                    DateFormat.MMM().format(trendData[index].month),
                    style: AppTypography.bodySmall.copyWith(
                      color: AppDesign.getTextSecondary(context),
                      fontSize: 11,
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
              interval: bounds.interval,
              getTitlesWidget: (value, meta) => SideTitleWidget(
                meta: meta,
                child: Text(
                  _formatCompactCurrency(value),
                  style: AppTypography.bodySmall.copyWith(
                    color: AppDesign.getTextSecondary(context),
                    fontSize: 11,
                  ),
                ),
              ),
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
          horizontalInterval: bounds.interval,
          getDrawingHorizontalLine: (value) => FlLine(
            color: AppDesign.getBorderColor(context).withValues(alpha: 0.5),
            strokeWidth: value == 0 ? 1.5 : 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppColors.primary,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.primary.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }

  BarChartRodData _buildComparisonRod(double value, Color color) {
    final isPositive = value >= 0;
    return BarChartRodData(
      fromY: 0,
      toY: value,
      color: color,
      width: 14,
      borderRadius: BorderRadius.only(
        topLeft: isPositive ? const Radius.circular(4) : Radius.zero,
        topRight: isPositive ? const Radius.circular(4) : Radius.zero,
        bottomLeft: isPositive ? Radius.zero : const Radius.circular(4),
        bottomRight: isPositive ? Radius.zero : const Radius.circular(4),
      ),
    );
  }

  _ChartBounds _getChartBounds(
    List<double> values, {
    bool forcePositive = false,
  }) {
    if (values.isEmpty || values.every((value) => value == 0)) {
      return const _ChartBounds(minY: -100, maxY: 100, interval: 50);
    }

    final minValue = forcePositive ? 0.0 : min(0.0, values.reduce(min));
    final maxValue = max(0.0, values.reduce(max));
    final maxMagnitude =
        _roundUpNice(max(minValue.abs(), maxValue.abs()) * 1.15);

    if (forcePositive || minValue >= 0) {
      return _ChartBounds(
        minY: 0,
        maxY: maxMagnitude,
        interval: maxMagnitude / 2,
      );
    }

    return _ChartBounds(
      minY: -maxMagnitude,
      maxY: maxMagnitude,
      interval: maxMagnitude / 2,
    );
  }

  Widget _buildEmptyMessage(BuildContext context, String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppDesign.getSurfaceColor(context).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppDesign.getBorderColor(context)),
      ),
      child: Text(
        message,
        style: AppTypography.bodyMedium.copyWith(
          color: AppDesign.getTextSecondary(context),
        ),
      ),
    );
  }

  Widget _buildFiltersCard(
    BuildContext context,
    TransactionModel model,
    List<String> categoryOptions,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppDesign.getCardColor(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Transaction Filters',
                  style: AppTypography.bodyLarge.copyWith(
                    color: AppDesign.getTextPrimary(context),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (_hasActiveFilters)
                TextButton(
                  onPressed: _resetFilters,
                  child: Text(
                    'Reset',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _buildSearchField(context),
          const SizedBox(height: 12),
          _buildTypeFilter(context),
          const SizedBox(height: 12),
          _buildCategoryFilter(context, categoryOptions),
          const SizedBox(height: 12),
          _buildDateRangeFilters(context),
          const SizedBox(height: 12),
          _buildAmountRangeFilters(context),
        ],
      ),
    );
  }

  Widget _buildSearchField(BuildContext context) {
    return TextField(
      controller: _searchController,
      onChanged: (value) => setState(() => _searchQuery = value.trim()),
      style: AppTypography.bodyMedium.copyWith(
        color: AppDesign.getTextPrimary(context),
      ),
      decoration: InputDecoration(
        prefixIcon: Icon(
          CupertinoIcons.search,
          color: AppDesign.getTextSecondary(context),
          size: 20,
        ),
        suffixIcon: _searchQuery.isEmpty
            ? null
            : IconButton(
                icon: Icon(
                  CupertinoIcons.clear_circled_solid,
                  color: AppDesign.getTextSecondary(context),
                  size: 18,
                ),
                onPressed: () {
                  setState(() {
                    _searchController.clear();
                    _searchQuery = '';
                  });
                },
              ),
        hintText: 'Search descriptions',
        hintStyle: AppTypography.bodyMedium.copyWith(
          color: AppDesign.getTextSecondary(context),
        ),
        filled: true,
        fillColor: AppDesign.getSurfaceColor(context).withValues(alpha: 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppDesign.getBorderColor(context)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppDesign.getBorderColor(context)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildTypeFilter(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: CupertinoSlidingSegmentedControl<_HistoryTransactionTypeFilter>(
        groupValue: _typeFilter,
        backgroundColor:
            AppDesign.getSurfaceColor(context).withValues(alpha: 0.6),
        thumbColor: AppDesign.getCardColor(context),
        children: {
          _HistoryTransactionTypeFilter.all: _buildSegmentLabel(context, 'All'),
          _HistoryTransactionTypeFilter.income:
              _buildSegmentLabel(context, 'Income'),
          _HistoryTransactionTypeFilter.expense:
              _buildSegmentLabel(context, 'Expense'),
        },
        onValueChanged: (value) {
          if (value == null) return;
          setState(() => _typeFilter = value);
        },
      ),
    );
  }

  Widget _buildSegmentLabel(BuildContext context, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: AppTypography.bodySmall.copyWith(
          color: AppDesign.getTextPrimary(context),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildCategoryFilter(
    BuildContext context,
    List<String> categoryOptions,
  ) {
    return _buildFilterButton(
      context,
      label: 'Category',
      value: _selectedCategory ?? 'All categories',
      icon: CupertinoIcons.square_grid_2x2,
      onTap: () => _showCategoryPicker(context, categoryOptions),
    );
  }

  Widget _buildDateRangeFilters(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildFilterButton(
            context,
            label: 'From',
            value: _startDate == null
                ? 'Any date'
                : DateFormat.MMMd().format(_startDate!),
            icon: CupertinoIcons.calendar,
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
            icon: CupertinoIcons.calendar_badge_plus,
            onTap: () => _pickDateRangeEndpoint(context, isStart: false),
          ),
        ),
      ],
    );
  }

  Widget _buildAmountRangeFilters(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildAmountField(
            context,
            controller: _minAmountController,
            label: 'Min amount',
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
            onChanged: (value) => setState(() {
              _maxAmount = _parseAmount(value);
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildAmountField(
    BuildContext context, {
    required TextEditingController controller,
    required String label,
    required ValueChanged<String> onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: onChanged,
      style: AppTypography.bodyMedium.copyWith(
        color: AppDesign.getTextPrimary(context),
      ),
      decoration: InputDecoration(
        labelText: label,
        prefixText: '\$ ',
        labelStyle: AppTypography.bodySmall.copyWith(
          color: AppDesign.getTextSecondary(context),
        ),
        filled: true,
        fillColor: AppDesign.getSurfaceColor(context).withValues(alpha: 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppDesign.getBorderColor(context)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppDesign.getBorderColor(context)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildFilterButton(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: AppDesign.touchTargetL),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppDesign.getSurfaceColor(context).withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppDesign.getBorderColor(context)),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppDesign.getTextSecondary(context), size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppDesign.getTextSecondary(context),
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppDesign.getTextPrimary(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              CupertinoIcons.chevron_down,
              color: AppDesign.getTextSecondary(context),
              size: 14,
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

  void _showCategoryPicker(BuildContext context, List<String> categories) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: AppDesign.getCardColor(ctx),
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
                  color: AppDesign.getTextTertiary(ctx).withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Select Category',
                    style: AppTypography.headingSmall.copyWith(
                      color: AppDesign.getTextPrimary(ctx),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    _buildCategoryOptionTile(ctx, null),
                    ...categories.map(
                      (category) => _buildCategoryOptionTile(ctx, category),
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

  Widget _buildCategoryOptionTile(BuildContext context, String? category) {
    final isSelected = _selectedCategory == category;
    return ListTile(
      title: Text(
        category ?? 'All categories',
        style: AppTypography.bodyLarge.copyWith(
          color: isSelected
              ? AppColors.primary
              : AppDesign.getTextPrimary(context),
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      trailing: isSelected
          ? const Icon(CupertinoIcons.checkmark,
              color: AppColors.primary, size: 18)
          : null,
      onTap: () {
        setState(() => _selectedCategory = category);
        Navigator.pop(context);
      },
    );
  }

  double? _parseAmount(String value) {
    final normalized = value.replaceAll(',', '').trim();
    if (normalized.isEmpty) return null;
    return double.tryParse(normalized);
  }

  Widget _buildFilteredTransactionsCard(
    BuildContext context,
    List<Transaction> transactions,
    int totalTransactionCount,
  ) {
    final summary = _buildFilteredSummary(transactions);
    final visibleTransactions = transactions.take(50).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppDesign.getCardColor(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Filtered History',
                  style: AppTypography.bodyLarge.copyWith(
                    color: AppDesign.getTextPrimary(context),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                '${transactions.length} of $totalTransactionCount',
                style: AppTypography.bodySmall.copyWith(
                  color: AppDesign.getTextSecondary(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildSummaryPill(
                context,
                label: 'Income',
                value: _formatCurrency(summary.income),
                color: AppDesign.getIncomeColor(context),
              ),
              _buildSummaryPill(
                context,
                label: 'Expenses',
                value: _formatCurrency(summary.expenses),
                color: AppDesign.getExpenseColor(context),
              ),
              _buildSummaryPill(
                context,
                label: 'Net',
                value: _formatSignedCurrency(summary.netCashFlow),
                color: summary.netCashFlow >= 0
                    ? AppDesign.getIncomeColor(context)
                    : AppDesign.getExpenseColor(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (transactions.isEmpty)
            _buildEmptyMessage(
              context,
              _hasActiveFilters
                  ? 'No transactions match these filters.'
                  : 'No transactions have been recorded yet.',
            )
          else
            Column(
              children: [
                ...visibleTransactions.map(
                  (transaction) => _buildTransactionHistoryRow(
                    context,
                    transaction,
                  ),
                ),
                if (transactions.length > visibleTransactions.length) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Showing latest ${visibleTransactions.length} matches',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppDesign.getTextSecondary(context),
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryPill(
    BuildContext context, {
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label ',
            style: AppTypography.bodySmall.copyWith(
              color: AppDesign.getTextSecondary(context),
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value,
            style: AppTypography.bodySmall.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionHistoryRow(
    BuildContext context,
    Transaction transaction,
  ) {
    final isIncome = transaction.type == TransactionTyp.income;
    final color = isIncome
        ? AppDesign.getIncomeColor(context)
        : AppDesign.getExpenseColor(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppDesign.getBorderColor(context).withValues(alpha: 0.6),
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isIncome
                  ? CupertinoIcons.arrow_down_circle_fill
                  : CupertinoIcons.arrow_up_circle_fill,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppDesign.getTextPrimary(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${transaction.category} • ${DateFormat.MMMd().format(transaction.date)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppDesign.getTextSecondary(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${isIncome ? '+' : '-'}${_formatCurrency(transaction.amount)}',
            style: AppTypography.bodyMedium.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthDropdown(BuildContext context, TransactionModel model,
      List<DateTime> availableMonths, DateTime selectedMonth) {
    return GestureDetector(
      onTap: availableMonths.isEmpty
          ? null
          : () =>
              _showMonthPicker(context, model, availableMonths, selectedMonth),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppDesign.getCardColor(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppDesign.getBorderColor(context),
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
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: AppDesign.getCardColor(ctx),
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
        color: AppDesign.getCardColor(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Monthly Net Cash Flow',
            style: AppTypography.bodyLarge.copyWith(
              color: AppDesign.getTextPrimary(context),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: _buildNetCashFlowBarChart(context, chartData, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildNetCashFlowBarChart(
      BuildContext context, List<MonthCashFlow> chartData, bool isDark) {
    final incomeColor = AppColors.getIncome(isDark);
    final expenseColor = AppColors.getExpense(isDark);
    final netValues = chartData.map((d) => d.netCashFlow).toList();
    final minNet = netValues.reduce(min);
    final maxNet = netValues.reduce(max);

    late final double minY;
    late final double maxY;
    late final double interval;

    if (minNet == 0 && maxNet == 0) {
      minY = -100;
      maxY = 100;
      interval = 50;
    } else if (minNet < 0 && maxNet > 0) {
      final maxMagnitude = _roundUpNice(max(minNet.abs(), maxNet.abs()) * 1.15);
      minY = -maxMagnitude;
      maxY = maxMagnitude;
      interval = maxMagnitude / 2;
    } else if (maxNet <= 0) {
      minY = -_roundUpNice(minNet.abs() * 1.15);
      maxY = 0;
      interval = minY.abs() / 2;
    } else {
      minY = 0;
      maxY = _roundUpNice(maxNet * 1.15);
      interval = maxY / 2;
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        minY: minY,
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
                final absValue = value.abs();
                final prefix = value < 0 ? '-\$' : '\$';
                final label = absValue >= 1000
                    ? '$prefix${(absValue / 1000).toStringAsFixed(0)}k'
                    : '$prefix${absValue.toStringAsFixed(0)}';
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
            color: AppDesign.getBorderColor(context).withValues(alpha: 0.5),
            strokeWidth: value == 0 ? 1.5 : 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: chartData.asMap().entries.map((entry) {
          final data = entry.value;
          final isPositive = data.netCashFlow >= 0;
          return BarChartGroupData(
            x: entry.key,
            barRods: [
              BarChartRodData(
                fromY: 0,
                toY: data.netCashFlow,
                color: isPositive ? incomeColor : expenseColor,
                width: 28,
                borderRadius: BorderRadius.only(
                  topLeft: isPositive ? const Radius.circular(5) : Radius.zero,
                  topRight: isPositive ? const Radius.circular(5) : Radius.zero,
                  bottomLeft:
                      isPositive ? Radius.zero : const Radius.circular(5),
                  bottomRight:
                      isPositive ? Radius.zero : const Radius.circular(5),
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
          color: AppDesign.getCardColor(ctx),
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
        color: AppDesign.getCardColor(context),
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

class _MonthlyCashFlowReport {
  final DateTime month;
  final double income;
  final double expenses;
  final Map<String, double> categoryExpenses;

  const _MonthlyCashFlowReport({
    required this.month,
    required this.income,
    required this.expenses,
    required this.categoryExpenses,
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

class _ComparisonChartGroup {
  final String label;
  final double currentValue;
  final double previousValue;

  const _ComparisonChartGroup({
    required this.label,
    required this.currentValue,
    required this.previousValue,
  });
}

class _ChartBounds {
  final double minY;
  final double maxY;
  final double interval;

  const _ChartBounds({
    required this.minY,
    required this.maxY,
    required this.interval,
  });
}
