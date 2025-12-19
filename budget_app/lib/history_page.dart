import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'transaction_model.dart';
import 'design_system.dart';
import 'widgets/empty_state.dart';
import 'utils/platform_utils.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({Key? key}) : super(key: key);

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final ScrollController _chartScrollController = ScrollController();
  int? _lastChartDataLength;
  bool _hasScrolledToLatest = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<TransactionModel>(
      builder: (context, transactionModel, child) {
        List<MonthCashFlow> chartData = transactionModel.getNetCashFlowHistory();
        CashFlowStatistics statistics = transactionModel.getCashFlowStatistics();

        return Scaffold(
          appBar: AppBar(
            title: Text(
              'Cash Flow History',
              style: AppTypography.headingMedium.copyWith(
                color: AppDesign.getTextPrimary(context),
              ),
            ),
            centerTitle: true,
            backgroundColor: AppDesign.getBackgroundColor(context),
            elevation: 0,
            surfaceTintColor: Colors.transparent,
          ),
          extendBodyBehindAppBar: false,
          body: Container(
            color: AppDesign.getBackgroundColor(context),
            child: chartData.isEmpty
                ? EmptyState.noData(
                    title: 'No Transaction History',
                    message: 'Start adding transactions to see your cash flow',
                    icon: CupertinoIcons.chart_bar,
                  )
                : SingleChildScrollView(
                    physics: PlatformUtils.platformScrollPhysics,
                    child: Column(
                      children: [
                        // Summary statistics card
                        Padding(
                          padding: const EdgeInsets.all(AppDesign.spacingM),
                          child: ElevatedCard(
                            elevation: AppDesign.elevationS,
                            child: _buildSummaryStatistics(statistics, isDark),
                          ),
                        ),

                        // Chart card
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppDesign.spacingM,
                          ),
                          child: ElevatedCard(
                            elevation: AppDesign.elevationS,
                            child: Padding(
                              padding: const EdgeInsets.all(AppDesign.spacingM),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Monthly Net Cash Flow',
                                    style: AppTypography.bodyLarge.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: AppDesign.getTextPrimary(context),
                                    ),
                                  ),
                                  const SizedBox(height: AppDesign.spacingS),
                                  Text(
                                    'Tap any bar to see details',
                                    style: AppTypography.bodySmall.copyWith(
                                      color: AppDesign.getTextTertiary(context),
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                  const SizedBox(height: AppDesign.spacingM),
                                  _buildResponsiveChart(chartData, isDark),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: AppDesign.spacingL),
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _chartScrollController.dispose();
    super.dispose();
  }

  Widget _buildSummaryStatistics(CashFlowStatistics statistics, bool isDark) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 360;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Summary Statistics',
          style: AppTypography.bodyLarge.copyWith(
            fontWeight: FontWeight.bold,
            color: AppDesign.getTextPrimary(context),
          ),
        ),
        SizedBox(height: isCompact ? AppDesign.spacingS : AppDesign.spacingM),
        _buildStatisticRow(
          'Average Monthly Net',
          statistics.average,
          isDark,
          isCompact: isCompact,
        ),
        SizedBox(height: isCompact ? AppDesign.spacingXS : AppDesign.spacingS),
        _buildStatisticRow(
          'Best Month (${DateFormat.MMM().format(statistics.bestMonth.month)})',
          statistics.bestMonth.netCashFlow,
          isDark,
          isCompact: isCompact,
        ),
        SizedBox(height: isCompact ? AppDesign.spacingXS : AppDesign.spacingS),
        _buildStatisticRow(
          'Worst Month (${DateFormat.MMM().format(statistics.worstMonth.month)})',
          statistics.worstMonth.netCashFlow,
          isDark,
          isCompact: isCompact,
        ),
      ],
    );
  }

  Widget _buildStatisticRow(String label, double value, bool isDark, {bool isCompact = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: (isCompact ? AppTypography.bodySmall : AppTypography.bodyMedium).copyWith(
              color: AppDesign.getTextSecondary(context),
            ),
          ),
        ),
        const SizedBox(width: AppDesign.spacingS),
        Flexible(
          child: Text(
            '\$${NumberFormat("#,##0.00", "en_US").format(value)}',
            style: (isCompact ? AppTypography.bodyMedium : AppTypography.bodyLarge).copyWith(
              fontWeight: FontWeight.w600,
              color: value >= 0
                  ? AppColors.getIncome(isDark)
                  : AppColors.getExpense(isDark),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildResponsiveChart(List<MonthCashFlow> chartData, bool isDark) {
    final screenWidth = MediaQuery.of(context).size.width;

    // Determine if we need horizontal scrolling
    final needsScrolling = chartData.length > 12;

    if (_lastChartDataLength != chartData.length) {
      _lastChartDataLength = chartData.length;
      _hasScrolledToLatest = false;
    }

    if (needsScrolling && !_hasScrolledToLatest) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_chartScrollController.hasClients) {
          _chartScrollController.jumpTo(
            _chartScrollController.position.maxScrollExtent,
          );
          _hasScrolledToLatest = true;
        }
      });
    }

    if (needsScrolling) {
      // Calculate width needed for all bars with proper spacing
      final chartWidth = chartData.length * 50.0 + 100;
      
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: AppDesign.spacingS),
            child: Row(
              children: [
                Icon(
                  CupertinoIcons.arrow_left_right,
                  size: 14,
                  color: AppDesign.getTextTertiary(context),
                ),
                const SizedBox(width: 4),
                Text(
                  'Swipe to see all ${chartData.length} months',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppDesign.getTextTertiary(context),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 300,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              controller: _chartScrollController,
              child: SizedBox(
                width: chartWidth.clamp(screenWidth, double.infinity),
                child: _buildChart(chartData, isDark, useFixedWidth: true),
              ),
            ),
          ),
        ],
      );
    } else {
      return SizedBox(
        height: 300,
        child: _buildChart(chartData, isDark, useFixedWidth: false),
      );
    }
  }

  Widget _buildChart(List<MonthCashFlow> chartData, bool isDark, {required bool useFixedWidth}) {
    final screenWidth = MediaQuery.of(context).size.width;

    List<MonthCashFlow> displayData;
    if (useFixedWidth) {
      displayData = chartData;
    } else {
      int maxMonthsToDisplay;
      if (screenWidth < 360) {
        maxMonthsToDisplay = 6;
      } else if (screenWidth < 600) {
        maxMonthsToDisplay = 8;
      } else if (screenWidth < 900) {
        maxMonthsToDisplay = 10;
      } else {
        maxMonthsToDisplay = 12;
      }

      displayData = chartData.length > maxMonthsToDisplay
          ? chartData.sublist(0, maxMonthsToDisplay)
          : chartData;
    }

    displayData = displayData.reversed.toList();

    double minValue = displayData.map((d) => d.netCashFlow).reduce((a, b) => a < b ? a : b);
    double maxValue = displayData.map((d) => d.netCashFlow).reduce((a, b) => a > b ? a : b);

    double roundToNiceNumber(double value, bool roundUp) {
      if (value == 0) return 0;
      
      final absValue = value.abs();
      final magnitude = (absValue.abs() == 0) ? 1 : pow(10, (log(absValue) / ln10).floor()).toDouble();
      final normalized = absValue / magnitude;
      
      double niceNumber;
      if (roundUp) {
        if (normalized <= 1) {
          niceNumber = 1;
        } else if (normalized <= 2) {
          niceNumber = 2;
        } else if (normalized <= 5) {
          niceNumber = 5;
        } else {
          niceNumber = 10;
        }
      } else {
        if (normalized < 1.5) {
          niceNumber = 1;
        } else if (normalized < 3) {
          niceNumber = 2;
        } else if (normalized < 7) {
          niceNumber = 5;
        } else {
          niceNumber = 10;
        }
      }
      
      return (value < 0 ? -1 : 1) * niceNumber * magnitude;
    }

    double range = maxValue - minValue;
    double padding = range * 0.15;
    
    minValue = minValue < 0 ? roundToNiceNumber(minValue - padding, false) : 0;
    maxValue = roundToNiceNumber(maxValue + padding, true);

    final double barWidth;
    if (useFixedWidth) {
      barWidth = 20.0;
    } else {
      final availableWidth = screenWidth - 120;
      barWidth = (availableWidth / displayData.length).clamp(12.0, 24.0);
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxValue,
        minY: minValue,
        barTouchData: BarTouchData(
          enabled: true,
          touchCallback: (FlTouchEvent event, barTouchResponse) {
            if (barTouchResponse == null ||
                barTouchResponse.spot == null ||
                event is! FlTapUpEvent) {
              return;
            }
            
            final index = barTouchResponse.spot!.touchedBarGroupIndex;
            if (index >= 0 && index < displayData.length) {
              _showMonthDetailsBottomSheet(displayData[index], isDark);
            }
          },
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (group) => isDark 
                ? AppColors.cardDark 
                : AppColors.cardLight,
            tooltipBorder: BorderSide(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
              width: 1.5,
            ),
            tooltipPadding: const EdgeInsets.all(8),
            tooltipMargin: 8,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final monthData = displayData[groupIndex];
              return BarTooltipItem(
                "${DateFormat("MMM ''yy").format(monthData.month)}\n",
                AppTypography.bodySmall.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? AppColors.textPrimaryDark 
                      : AppColors.textPrimary,
                ),
                children: [
                  TextSpan(
                    text: '\$${NumberFormat("#,##0.00", "en_US").format(monthData.netCashFlow)}',
                    style: AppTypography.bodySmall.copyWith(
                      fontWeight: FontWeight.w600,
                      color: monthData.netCashFlow >= 0
                          ? AppColors.getIncome(isDark)
                          : AppColors.getExpense(isDark),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= 0 && value.toInt() < displayData.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      DateFormat("MMM ''yy")
                          .format(displayData[value.toInt()].month),
                      style: AppTypography.bodySmall.copyWith(
                        color: AppDesign.getTextSecondary(context),
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 60,
              getTitlesWidget: (value, meta) {
                String text;
                if (value.abs() >= 1000) {
                  text = '\$${(value / 1000).toStringAsFixed(1)}K';
                } else {
                  text = '\$${value.toStringAsFixed(0)}';
                }
                return Padding(
                  padding: EdgeInsets.only(
                    top: value == meta.max ? 4.0 : 0,
                    bottom: value == meta.min ? 4.0 : 0,
                    right: 4.0,
                  ),
                  child: Text(
                    text,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppDesign.getTextSecondary(context),
                    ),
                  ),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: (maxValue - minValue) / 5,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: isDark 
                  ? AppColors.borderDark.withValues(alpha: 0.5)
                  : AppColors.borderLight.withValues(alpha: 0.5),
              strokeWidth: 1,
            );
          },
        ),
        borderData: FlBorderData(
          show: true,
          border: Border(
            bottom: BorderSide(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
              width: 1.5,
            ),
            left: BorderSide(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
              width: 1.5,
            ),
          ),
        ),
        barGroups: displayData.asMap().entries.map((entry) {
          final index = entry.key;
          final data = entry.value;

          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: data.netCashFlow,
                color: data.netCashFlow >= 0
                    ? AppColors.getIncome(isDark)
                    : AppColors.getExpense(isDark),
                width: barWidth,
                borderRadius: BorderRadius.circular(4),
                backDrawRodData: BackgroundBarChartRodData(
                  show: false,
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  void _showMonthDetailsBottomSheet(MonthCashFlow monthData, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppDesign.getBackgroundColor(context),
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppDesign.radiusL),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppDesign.spacingL),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: AppDesign.spacingM),
                    decoration: BoxDecoration(
                      color: AppDesign.getTextTertiary(context).withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppDesign.spacingS),
                      decoration: BoxDecoration(
                        color: (monthData.netCashFlow >= 0
                                ? AppColors.getIncome(isDark)
                                : AppColors.getExpense(isDark))
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppDesign.radiusM),
                      ),
                      child: Icon(
                        CupertinoIcons.calendar,
                        color: monthData.netCashFlow >= 0
                            ? AppColors.getIncome(isDark)
                            : AppColors.getExpense(isDark),
                        size: AppDesign.iconM,
                      ),
                    ),
                    const SizedBox(width: AppDesign.spacingM),
                    Expanded(
                      child: Text(
                        DateFormat.yMMMM().format(monthData.month),
                        style: AppTypography.headingMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppDesign.getTextPrimary(context),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDesign.spacingL),
                Row(
                  children: [
                    Expanded(
                      child: _buildDetailCard(
                        'Income',
                        monthData.income,
                        AppColors.getIncome(isDark),
                        CupertinoIcons.arrow_down_circle_fill,
                        isDark,
                      ),
                    ),
                    const SizedBox(width: AppDesign.spacingM),
                    Expanded(
                      child: _buildDetailCard(
                        'Expenses',
                        monthData.expenses,
                        AppColors.getExpense(isDark),
                        CupertinoIcons.arrow_up_circle_fill,
                        isDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDesign.spacingM),
                Container(
                  padding: const EdgeInsets.all(AppDesign.spacingM),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: monthData.netCashFlow >= 0
                          ? [
                              AppColors.getIncome(isDark).withValues(alpha: 0.15),
                              AppColors.getIncome(isDark).withValues(alpha: 0.05),
                            ]
                          : [
                              AppColors.getExpense(isDark).withValues(alpha: 0.15),
                              AppColors.getExpense(isDark).withValues(alpha: 0.05),
                            ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(AppDesign.radiusM),
                    border: Border.all(
                      color: (monthData.netCashFlow >= 0
                              ? AppColors.getIncome(isDark)
                              : AppColors.getExpense(isDark))
                          .withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            monthData.netCashFlow >= 0
                                ? CupertinoIcons.checkmark_circle_fill
                                : CupertinoIcons.exclamationmark_circle_fill,
                            color: monthData.netCashFlow >= 0
                                ? AppColors.getIncome(isDark)
                                : AppColors.getExpense(isDark),
                            size: AppDesign.iconM,
                          ),
                          const SizedBox(width: AppDesign.spacingS),
                          Text(
                            'Net Cash Flow',
                            style: AppTypography.bodyLarge.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppDesign.getTextPrimary(context),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '\$${NumberFormat("#,##0.00", "en_US").format(monthData.netCashFlow)}',
                        style: AppTypography.headingMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: monthData.netCashFlow >= 0
                              ? AppColors.getIncome(isDark)
                              : AppColors.getExpense(isDark),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppDesign.spacingM),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailCard(String label, double amount, Color color, IconData icon, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(AppDesign.spacingM),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDesign.radiusM),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: color,
                size: AppDesign.iconS,
              ),
              const SizedBox(width: AppDesign.spacingXS),
              Text(
                label,
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppDesign.getTextSecondary(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDesign.spacingS),
          Text(
            '\$${NumberFormat("#,##0.00", "en_US").format(amount)}',
            style: AppTypography.headingMedium.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
