import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'design_system.dart';
import 'net_worth_entry.dart';
import 'transaction_model.dart';
import 'utils/platform_utils.dart';
import 'widgets/empty_state.dart';
import 'widgets/month_selector.dart';

// ---------- Main Page ----------

class NetWorthPage extends StatefulWidget {
  const NetWorthPage({super.key});

  @override
  State<NetWorthPage> createState() => _NetWorthPageState();
}

class _NetWorthPageState extends State<NetWorthPage> {
  int _selectedTab = 0; // 0 = Assets, 1 = Liabilities

  @override
  Widget build(BuildContext context) {
    return Consumer<TransactionModel>(
      builder: (context, model, child) {
        final month = model.selectedNetWorthMonth;
        final assets = model.totalAssets;
        final liabilities = model.totalLiabilities;
        final netWorth = model.netWorth;
        final assetEntries = model.assetEntriesForSelectedNetWorthMonth;
        final liabilityEntries = model.liabilityEntriesForSelectedNetWorthMonth;
        final availableMonths = model.getNetWorthAvailableMonths();
        final history = model.getNetWorthHistory(limit: 24);
        final chartData = history.reversed.toList();
        final previousMonth = DateTime(month.year, month.month - 1);
        final hasPreviousData = model.hasNetWorthDataForMonth(previousMonth);
        final monthChange = hasPreviousData
            ? netWorth - model.getNetWorthForMonth(previousMonth)
            : null;

        return Scaffold(
          appBar: AppBar(
            title: Text(
              'Net Worth Tracker',
              style: AppTypography.headingLarge.copyWith(
                color: AppDesign.getTextPrimary(context),
                fontWeight: FontWeight.w700,
              ),
            ),
            centerTitle: true,
            backgroundColor: AppDesign.getBackgroundColor(context),
            elevation: 0,
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: AppDesign.spacingS),
                child: IconButton(
                  icon: Icon(
                    CupertinoIcons.plus_circle_fill,
                    color: AppDesign.getIncomeColor(context),
                  ),
                  onPressed: () => _showNetWorthEditor(
                    context: context,
                    transactionModel: model,
                    month: month,
                    initialType: _selectedTab == 0
                        ? NetWorthEntryType.asset
                        : NetWorthEntryType.liability,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: AppDesign.getBackgroundColor(context),
          body: model.hasNetWorthEntries
              ? SingleChildScrollView(
                  physics: PlatformUtils.platformScrollPhysics,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Month selector
                      MonthSelector(
                        selectedMonth: month,
                        availableMonths: availableMonths,
                        onMonthChanged: (m) async {
                          await model.selectNetWorthMonth(m);
                        },
                      ),
                      // Hero: net worth amount + change badge
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppDesign.spacingM,
                          AppDesign.spacingS,
                          AppDesign.spacingM,
                          AppDesign.spacingL,
                        ),
                        child: Column(
                          children: [
                            Text(
                              _formatCurrency(netWorth),
                              style: AppTypography.displayLarge.copyWith(
                                color: netWorth >= 0
                                    ? AppDesign.getIncomeColor(context)
                                    : AppDesign.getExpenseColor(context),
                                fontWeight: FontWeight.w800,
                                fontSize: 44,
                                letterSpacing: -1.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: AppDesign.spacingS),
                            if (monthChange != null)
                              _ChangeBadge(
                                change: monthChange,
                                netWorth: netWorth,
                              ),
                          ],
                        ),
                      ),
                      // Growth chart card
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDesign.spacingM,
                        ),
                        child: _GrowthChartCard(chartData: chartData),
                      ),
                      const SizedBox(height: AppDesign.spacingL),
                      // Assets / Liabilities toggle
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDesign.spacingM,
                        ),
                        child: _AccountsToggle(
                          selectedTab: _selectedTab,
                          onTabChanged: (tab) =>
                              setState(() => _selectedTab = tab),
                        ),
                      ),
                      const SizedBox(height: AppDesign.spacingM),
                      // Accounts list
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDesign.spacingM,
                        ),
                        child: _AccountsList(
                          selectedTab: _selectedTab,
                          assetEntries: assetEntries,
                          liabilityEntries: liabilityEntries,
                          totalAssets: assets,
                          totalLiabilities: liabilities,
                          month: month,
                          onEditEntry: (entry) => _showNetWorthEditor(
                            context: context,
                            transactionModel: model,
                            month: month,
                            existingEntry: entry,
                          ),
                          onDeleteEntry: (entry) => _confirmDeleteNetWorthEntry(
                            context: context,
                            transactionModel: model,
                            entry: entry,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppDesign.spacingXXL),
                    ],
                  ),
                )
              : EmptyState.noData(
                  title: 'No Net Worth Accounts Yet',
                  message:
                      'Create your first asset or liability to start tracking net worth over time.',
                  icon: CupertinoIcons.chart_bar_alt_fill,
                  actionLabel: 'Add Account',
                  onAction: () => _showNetWorthEditor(
                    context: context,
                    transactionModel: model,
                    month: month,
                  ),
                ),
        );
      },
    );
  }
}

// ---------- Change Badge ----------

class _ChangeBadge extends StatelessWidget {
  final double change;
  final double netWorth;

  const _ChangeBadge({required this.change, required this.netWorth});

  @override
  Widget build(BuildContext context) {
    final isPositive = change >= 0;
    final color = isPositive
        ? AppDesign.getIncomeColor(context)
        : AppDesign.getExpenseColor(context);

    final previousNetWorth = netWorth - change;
    final percentStr = previousNetWorth.abs() > 0.001
        ? '${isPositive ? '+' : ''}${(change / previousNetWorth.abs() * 100).toStringAsFixed(1)}%'
        : '${isPositive ? '+' : '-'}—';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDesign.spacingM,
        vertical: AppDesign.spacingS,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppDesign.radiusRound),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(AppDesign.radiusXS),
            ),
            child: Icon(
              isPositive ? CupertinoIcons.arrow_up : CupertinoIcons.arrow_down,
              size: 13,
              color: color,
            ),
          ),
          const SizedBox(width: AppDesign.spacingS),
          Text(
            '$percentStr  Since last month',
            style: AppTypography.bodyMedium.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- Growth Chart Card ----------

class _GrowthChartCard extends StatefulWidget {
  final List<NetWorthHistoryPoint> chartData;

  const _GrowthChartCard({required this.chartData});

  @override
  State<_GrowthChartCard> createState() => _GrowthChartCardState();
}

class _GrowthChartCardState extends State<_GrowthChartCard> {
  final ScrollController _scrollController = ScrollController();
  int? _lastLength;
  bool _hasScrolledToLatest = false;
  int? _selectedSpotIndex;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chartData = widget.chartData;

    if (_lastLength != chartData.length) {
      _lastLength = chartData.length;
      _hasScrolledToLatest = false;
      _selectedSpotIndex = null;
    }

    final needsScrolling = chartData.length > 8;

    if (needsScrolling && !_hasScrolledToLatest) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(
            _scrollController.position.maxScrollExtent,
          );
          setState(() => _hasScrolledToLatest = true);
        }
      });
    }

    return Container(
      decoration: BoxDecoration(
        color: AppDesign.getCardColor(context),
        borderRadius: BorderRadius.circular(AppDesign.radiusXL),
        boxShadow: AppDesign.shadowM,
      ),
      padding: const EdgeInsets.all(AppDesign.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Net Worth Growth',
            style: AppTypography.headingMedium.copyWith(
              color: AppDesign.getTextPrimary(context),
              fontWeight: FontWeight.w700,
            ),
          ),
          if (chartData.any(
            (point) => point.granularity == NetWorthHistoryGranularity.month,
          )) ...[
            const SizedBox(height: AppDesign.spacingXS),
            Text(
              'Older updates are grouped into monthly snapshots.',
              style: AppTypography.bodySmall.copyWith(
                color: AppDesign.getTextSecondary(context),
              ),
            ),
          ],
          const SizedBox(height: AppDesign.spacingM),
          if (chartData.isEmpty)
            Container(
              height: 220,
              alignment: Alignment.center,
              child: Text(
                'Add balance updates to build your growth chart.',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppDesign.getTextSecondary(context),
                ),
                textAlign: TextAlign.center,
              ),
            )
          else
            _buildChartContent(context, chartData, isDark, needsScrolling),
        ],
      ),
    );
  }

  Widget _buildChartContent(
    BuildContext context,
    List<NetWorthHistoryPoint> chartData,
    bool isDark,
    bool needsScrolling,
  ) {
    final chartWidth = max(
      MediaQuery.of(context).size.width - (AppDesign.spacingM * 4 + 32),
      chartData.length * 72.0,
    );

    final chart = SizedBox(
      width: needsScrolling ? chartWidth : double.infinity,
      height: 240,
      child: Stack(
        children: [
          Positioned.fill(
            child: _NetWorthLineChart(
              chartData: chartData,
              isDark: isDark,
              selectedSpotIndex: _selectedSpotIndex,
              onTouchSpot: _handleTouchSpot,
            ),
          ),
          if (_selectedSpotIndex != null)
            Positioned.fill(
              child: IgnorePointer(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDesign.spacingS,
                    vertical: AppDesign.spacingXS,
                  ),
                  child: _NetWorthHoverCard(
                    point: chartData[_selectedSpotIndex!.clamp(
                      0,
                      chartData.length - 1,
                    )],
                    alignment: _overlayAlignmentForSelectedPoint(chartData),
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    if (!needsScrolling) {
      return SizedBox(height: 240, child: chart);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              CupertinoIcons.arrow_left_right,
              size: AppDesign.iconXS,
              color: AppDesign.getTextTertiary(context),
            ),
            const SizedBox(width: AppDesign.spacingXS),
            Text(
              'Swipe to see full history',
              style: AppTypography.bodySmall.copyWith(
                color: AppDesign.getTextTertiary(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDesign.spacingS),
        SizedBox(
          height: 240,
          child: SingleChildScrollView(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: chart,
          ),
        ),
      ],
    );
  }

  void _handleTouchSpot(FlTouchEvent event, int? spotIndex) {
    if (widget.chartData.isEmpty) {
      return;
    }

    if (event is FlLongPressStart || event is FlLongPressMoveUpdate) {
      if (spotIndex == null) {
        return;
      }

      final normalizedIndex = spotIndex.clamp(0, widget.chartData.length - 1);
      if (_selectedSpotIndex == normalizedIndex) {
        return;
      }

      HapticFeedback.selectionClick();
      setState(() => _selectedSpotIndex = normalizedIndex);
      return;
    }

    if (_selectedSpotIndex != null &&
        (event is FlLongPressEnd || !event.isInterestedForInteractions)) {
      setState(() => _selectedSpotIndex = null);
    }
  }

  Alignment _overlayAlignmentForSelectedPoint(
    List<NetWorthHistoryPoint> chartData,
  ) {
    final selectedIndex = _selectedSpotIndex;
    if (selectedIndex == null || chartData.isEmpty) {
      return const Alignment(0, -0.42);
    }

    final safeIndex = selectedIndex.clamp(0, chartData.length - 1);
    final point = chartData[safeIndex];
    final values = chartData.map((item) => item.netWorth).toList();
    final minValue = values.reduce(min);
    final maxValue = values.reduce(max);
    final midpoint = (minValue + maxValue) / 2;
    final useBottom = point.netWorth >= midpoint;

    if (useBottom) {
      return const Alignment(0, 0.42);
    }
    return const Alignment(0, -0.42);
  }
}

// ---------- Line Chart ----------

class _NetWorthLineChart extends StatelessWidget {
  final List<NetWorthHistoryPoint> chartData;
  final bool isDark;
  final int? selectedSpotIndex;
  final void Function(FlTouchEvent event, int? spotIndex) onTouchSpot;

  const _NetWorthLineChart({
    required this.chartData,
    required this.isDark,
    required this.selectedSpotIndex,
    required this.onTouchSpot,
  });

  @override
  Widget build(BuildContext context) {
    final values = chartData.map((item) => item.netWorth).toList();
    final minValue = values.reduce(min);
    final maxValue = values.reduce(max);
    // Enforce a minimum range (10% of the max value) so Y labels stay
    // meaningfully spaced even with a single data point.
    final rawRange = maxValue - minValue;
    final range = max(rawRange, max(1.0, maxValue.abs() * 0.10));
    final paddedMin = minValue - (range * 0.18);
    final paddedMax = maxValue + (range * 0.18);
    final yInterval = _niceInterval(paddedMax - paddedMin);
    final incomeColor = AppDesign.getIncomeColor(context);
    final expenseColor = AppDesign.getExpenseColor(context);
    final lineSpots = chartData.length == 1
        ? [
            FlSpot(0.0, chartData[0].netWorth),
            FlSpot(1.0, chartData[0].netWorth),
          ]
        : List.generate(
            chartData.length,
            (index) => FlSpot(index.toDouble(), chartData[index].netWorth),
          );
    final lineBarData = LineChartBarData(
      spots: lineSpots,
      isCurved: true,
      color: incomeColor,
      barWidth: 3,
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          colors: [
            incomeColor.withValues(alpha: 0.30),
            incomeColor.withValues(alpha: 0.0),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      dotData: FlDotData(
        show: selectedSpotIndex != null,
        checkToShowDot: (spot, _) =>
            selectedSpotIndex != null &&
            (spot.x.round() == selectedSpotIndex ||
                (chartData.length == 1 &&
                    selectedSpotIndex == 0 &&
                    spot.x.round() == 1)),
        getDotPainter: (spot, _, __, index) {
          final pointIndex = chartData.length == 1
              ? 0
              : index.clamp(0, chartData.length - 1);
          final point = chartData[pointIndex];
          final highlightColor =
              point.netWorth >= 0 ? incomeColor : expenseColor;
          return FlDotCirclePainter(
            radius: 7,
            color: highlightColor,
            strokeWidth: 5,
            strokeColor: highlightColor.withValues(alpha: 0.22),
          );
        },
      ),
    );

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: max(1.0, (chartData.length - 1).toDouble()),
        minY: paddedMin,
        maxY: paddedMax,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: yInterval,
          getDrawingHorizontalLine: (value) => FlLine(
            color: (isDark ? AppColors.borderDark : AppColors.borderLight)
                .withValues(alpha: 0.45),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border(
            left: BorderSide(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
            ),
            bottom: BorderSide(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
            ),
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (value != index.toDouble()) return const SizedBox.shrink();
                if (index < 0 || index >= chartData.length) {
                  return const SizedBox.shrink();
                }
                final shouldShow = chartData.length <= 6 ||
                    index.isEven ||
                    index == chartData.length - 1;
                if (!shouldShow) return const SizedBox.shrink();
                final point = chartData[index];
                return SideTitleWidget(
                  meta: meta,
                  child: Text(
                    _formatNetWorthHistoryAxisLabel(point),
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
              reservedSize: 64,
              interval: yInterval,
              getTitlesWidget: (value, meta) {
                // Skip the auto boundary labels fl_chart injects at min/max —
                // they land right on top of the nearest interval tick.
                if (value == meta.min || value == meta.max) {
                  return const SizedBox.shrink();
                }
                return SideTitleWidget(
                  meta: meta,
                  child: Text(
                    _formatCompactCurrency(value),
                    style: AppTypography.bodySmall.copyWith(
                      color: AppDesign.getTextSecondary(context),
                      fontSize: 11,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          enabled: true,
          handleBuiltInTouches: false,
          longPressDuration: const Duration(milliseconds: 150),
          touchCallback: (event, response) {
            final spotIndex = response?.lineBarSpots?.first.spotIndex;
            onTouchSpot(event, spotIndex);
          },
        ),
        lineBarsData: [lineBarData],
      ),
    );
  }

}

class _NetWorthHoverCard extends StatelessWidget {
  final NetWorthHistoryPoint point;
  final Alignment alignment;

  const _NetWorthHoverCard({
    required this.point,
    required this.alignment,
  });

  @override
  Widget build(BuildContext context) {
    final netWorthColor = point.netWorth >= 0
        ? AppDesign.getIncomeColor(context)
        : AppDesign.getExpenseColor(context);

    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 220),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDesign.spacingM,
            vertical: AppDesign.spacingS,
          ),
          decoration: BoxDecoration(
            color: AppDesign.getCardColor(context),
            borderRadius: BorderRadius.circular(AppDesign.radiusL),
            border: Border.all(color: AppDesign.getBorderColor(context)),
            boxShadow: AppDesign.shadowM,
          ),
          child: DefaultTextStyle(
            style: AppTypography.bodySmall.copyWith(
              color: AppDesign.getTextSecondary(context),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatNetWorthHistoryTooltipTitle(point),
                  style: AppTypography.bodySmall.copyWith(
                    color: AppDesign.getTextPrimary(context),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppDesign.spacingXS),
                Text(
                  _formatCurrency(point.netWorth),
                  style: AppTypography.bodyMedium.copyWith(
                    color: netWorthColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppDesign.spacingXS),
                Text('Assets: ${_formatCurrency(point.assets)}'),
                Text('Liabilities: ${_formatCurrency(point.liabilities)}'),
                if (point.granularity == NetWorthHistoryGranularity.month) ...[
                  const SizedBox(height: AppDesign.spacingXS),
                  Text(
                    'Monthly snapshot',
                    style: AppTypography.caption.copyWith(
                      color: AppDesign.getTextTertiary(context),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _formatNetWorthHistoryAxisLabel(NetWorthHistoryPoint point) {
  if (point.granularity == NetWorthHistoryGranularity.month) {
    return DateFormat('MMM').format(point.date);
  }

  return DateFormat('MMM d').format(point.date);
}

String _formatNetWorthHistoryTooltipTitle(NetWorthHistoryPoint point) {
  if (point.granularity == NetWorthHistoryGranularity.month) {
    return DateFormat('MMMM y').format(point.date);
  }

  return DateFormat('MMM d, y').format(point.date);
}

// ---------- Accounts Toggle ----------

class _AccountsToggle extends StatelessWidget {
  final int selectedTab;
  final ValueChanged<int> onTabChanged;

  const _AccountsToggle({
    required this.selectedTab,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 52,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : const Color(0xFF1E2530),
        borderRadius: BorderRadius.circular(AppDesign.radiusRound),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ToggleTab(
              label: 'Assets',
              isSelected: selectedTab == 0,
              activeColor: AppDesign.getIncomeColor(context),
              onTap: () => onTabChanged(0),
            ),
          ),
          Expanded(
            child: _ToggleTab(
              label: 'Liabilities',
              isSelected: selectedTab == 1,
              activeColor: AppDesign.getExpenseColor(context),
              onTap: () => onTabChanged(1),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleTab extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color activeColor;
  final VoidCallback onTap;

  const _ToggleTab({
    required this.label,
    required this.isSelected,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(AppDesign.radiusRound - 4),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppTypography.bodyMedium.copyWith(
            color: isSelected
                ? const Color(0xFF0D1117)
                : AppDesign.getTextSecondary(context),
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ---------- Accounts List ----------

class _AccountsList extends StatelessWidget {
  final int selectedTab;
  final List<NetWorthEntry> assetEntries;
  final List<NetWorthEntry> liabilityEntries;
  final double totalAssets;
  final double totalLiabilities;
  final DateTime month;
  final void Function(NetWorthEntry) onEditEntry;
  final void Function(NetWorthEntry) onDeleteEntry;

  const _AccountsList({
    required this.selectedTab,
    required this.assetEntries,
    required this.liabilityEntries,
    required this.totalAssets,
    required this.totalLiabilities,
    required this.month,
    required this.onEditEntry,
    required this.onDeleteEntry,
  });

  @override
  Widget build(BuildContext context) {
    final isAssets = selectedTab == 0;
    final entries = isAssets ? assetEntries : liabilityEntries;
    final total = isAssets ? totalAssets : totalLiabilities;

    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppDesign.spacingL),
        child: Text(
          'No ${isAssets ? 'assets' : 'liabilities'} tracked for ${formatNetWorthMonth(month)}.',
          style: AppTypography.bodyMedium.copyWith(
            color: AppDesign.getTextSecondary(context),
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Column(
      children: entries.map((entry) {
        return Padding(
          padding: const EdgeInsets.only(bottom: AppDesign.spacingS),
          child: _AccountRow(
            entry: entry,
            month: month,
            totalForCategory: total,
            onTap: () => onEditEntry(entry),
            onDelete: () => onDeleteEntry(entry),
          ),
        );
      }).toList(),
    );
  }
}

// ---------- Account Row ----------

class _AccountRow extends StatelessWidget {
  final NetWorthEntry entry;
  final DateTime month;
  final double totalForCategory;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _AccountRow({
    required this.entry,
    required this.month,
    required this.totalForCategory,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveSnapshot = entry.latestSnapshotThrough(
      endOfNetWorthMonth(month),
    );
    final amount = effectiveSnapshot?.amount ?? 0.0;
    final percentage = totalForCategory > 0
        ? (amount / totalForCategory).clamp(0.0, 1.0)
        : 0.0;
    final isAsset = entry.type == NetWorthEntryType.asset;
    final color = isAsset
        ? AppDesign.getIncomeColor(context)
        : AppDesign.getExpenseColor(context);
    final icon = _iconForEntry(entry);

    return GestureDetector(
      onTap: onTap,
      onLongPress: () => showModalBottomSheet<void>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: AppDesign.spacingS),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppDesign.getBorderColor(context),
                  borderRadius: BorderRadius.circular(AppDesign.radiusRound),
                ),
              ),
              const SizedBox(height: AppDesign.spacingM),
              ListTile(
                leading: Icon(CupertinoIcons.pencil,
                    color: AppDesign.getTextPrimary(ctx)),
                title: Text(
                  'Edit Balance',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppDesign.getTextPrimary(ctx),
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  onTap();
                },
              ),
              ListTile(
                leading: Icon(CupertinoIcons.trash,
                    color: AppDesign.getExpenseColor(ctx)),
                title: Text(
                  'Delete Account',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppDesign.getExpenseColor(ctx),
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  onDelete();
                },
              ),
              const SizedBox(height: AppDesign.spacingM),
            ],
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppDesign.spacingM,
          AppDesign.spacingM,
          AppDesign.spacingM,
          AppDesign.spacingM,
        ),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.cardLight,
          borderRadius: BorderRadius.circular(AppDesign.radiusXL),
          boxShadow: AppDesign.shadowS,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(AppDesign.radiusM),
                  ),
                  child: Icon(icon, color: color, size: AppDesign.iconS),
                ),
                const SizedBox(width: AppDesign.spacingM),
                // Name + amount
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.name,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppDesign.getTextPrimary(context),
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppDesign.spacingXXS),
                      Text(
                        _formatCurrency(amount),
                        style: AppTypography.bodySmall.copyWith(
                          color: AppDesign.getTextSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppDesign.spacingS),
                // Percentage on right
                Text(
                  '+${(percentage * 100).toStringAsFixed(1)}%',
                  style: AppTypography.bodyMedium.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDesign.spacingS),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(AppDesign.radiusRound),
              child: LinearProgressIndicator(
                value: percentage,
                minHeight: 4,
                backgroundColor: color.withValues(alpha: 0.14),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconForEntry(NetWorthEntry e) {
    final n = e.name.toLowerCase();
    if (e.type == NetWorthEntryType.asset) {
      if (n.contains('bank') ||
          n.contains('checking') ||
          n.contains('saving')) {
        return CupertinoIcons.building_2_fill;
      }
      if (n.contains('invest') ||
          n.contains('stock') ||
          n.contains('portfolio') ||
          n.contains('etf') ||
          n.contains('401') ||
          n.contains('ira')) {
        return CupertinoIcons.chart_bar_alt_fill;
      }
      if (n.contains('real estate') ||
          n.contains('house') ||
          n.contains('home') ||
          n.contains('property')) {
        return CupertinoIcons.house_fill;
      }
      return CupertinoIcons.arrow_up_right_circle_fill;
    } else {
      if (n.contains('loan') ||
          n.contains('student') ||
          n.contains('auto') ||
          n.contains('personal')) {
        return CupertinoIcons.money_dollar_circle_fill;
      }
      if (n.contains('credit') || n.contains('card')) {
        return CupertinoIcons.creditcard_fill;
      }
      return CupertinoIcons.arrow_down_left_circle_fill;
    }
  }
}

Future<void> _showNetWorthEditor({
  required BuildContext context,
  required TransactionModel transactionModel,
  required DateTime month,
  NetWorthEntry? existingEntry,
  NetWorthEntryType? initialType,
}) async {
  await showDialog<void>(
    context: context,
    useRootNavigator: true,
    builder: (_) => _NetWorthEditorDialog(
      transactionModel: transactionModel,
      month: month,
      existingEntry: existingEntry,
      initialType: initialType,
    ),
  );
}

// Formats a number with commas in the integer part, preserving a decimal portion.
class _CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;

    // Strip commas, then validate only digits + at most one decimal point
    final stripped = text.replaceAll(',', '');
    if (!RegExp(r'^\d*\.?\d{0,2}$').hasMatch(stripped)) {
      return oldValue;
    }

    final dotIndex = stripped.indexOf('.');
    final intPart = dotIndex == -1 ? stripped : stripped.substring(0, dotIndex);
    final decPart = dotIndex == -1 ? null : stripped.substring(dotIndex + 1);

    // Build comma-separated integer string
    String formatted = '';
    if (intPart.isNotEmpty) {
      final buffer = StringBuffer();
      for (int i = 0; i < intPart.length; i++) {
        if (i > 0 && (intPart.length - i) % 3 == 0) {
          buffer.write(',');
        }
        buffer.write(intPart[i]);
      }
      formatted = buffer.toString();
    }

    if (dotIndex != -1) {
      formatted += '.${decPart ?? ''}';
    }

    return newValue.copyWith(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _NetWorthEditorDialog extends StatefulWidget {
  final TransactionModel transactionModel;
  final DateTime month;
  final NetWorthEntry? existingEntry;
  final NetWorthEntryType? initialType;

  const _NetWorthEditorDialog({
    required this.transactionModel,
    required this.month,
    this.existingEntry,
    this.initialType,
  });

  @override
  State<_NetWorthEditorDialog> createState() => _NetWorthEditorDialogState();
}

class _NetWorthEditorDialogState extends State<_NetWorthEditorDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  late final FocusNode _nameFocus;
  late final FocusNode _amountFocus;
  late NetWorthEntryType _selectedType;
  String? _nameError;
  String? _amountError;
  bool _nameFocused = false;
  bool _amountFocused = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.existingEntry?.name ?? '',
    );
    final rawAmount = widget.existingEntry == null
        ? null
        : (widget.existingEntry!.amountForMonth(widget.month) ?? 0.0);
    _amountController = TextEditingController(
      text: rawAmount == null ? '' : NumberFormat('#,##0.##').format(rawAmount),
    );
    _selectedType = widget.existingEntry?.type ??
        widget.initialType ??
        NetWorthEntryType.asset;
    _nameFocus = FocusNode()
      ..addListener(() => setState(() => _nameFocused = _nameFocus.hasFocus));
    _amountFocus = FocusNode()
      ..addListener(
          () => setState(() => _amountFocused = _amountFocus.hasFocus));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _nameFocus.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  bool get _isAsset => _selectedType == NetWorthEntryType.asset;

  Color _accentColor(BuildContext context) => _isAsset
      ? AppDesign.getIncomeColor(context)
      : AppDesign.getExpenseColor(context);

  LinearGradient _accentGradient(BuildContext context) => _isAsset
      ? AppDesign.getIncomeGradient(context)
      : AppDesign.getExpenseGradient(context);

  @override
  Widget build(BuildContext context) {
    final existingEntry = widget.existingEntry;
    final hasPriorValue = existingEntry != null &&
        existingEntry.snapshotForMonth(widget.month) == null &&
        existingEntry.latestSnapshotThrough(endOfNetWorthMonth(widget.month)) !=
            null;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppDesign.spacingL,
        vertical: AppDesign.spacingXL,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppDesign.getCardColor(context),
          borderRadius: BorderRadius.circular(AppDesign.radiusXXL),
          boxShadow: [
            BoxShadow(
              color: _accentColor(context).withValues(alpha: 0.18),
              blurRadius: 32,
              offset: const Offset(0, 8),
            ),
            ...AppDesign.shadowXL,
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Gradient header banner
              AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeInOut,
                decoration: BoxDecoration(
                  gradient: _accentGradient(context),
                ),
                padding: const EdgeInsets.fromLTRB(
                  AppDesign.spacingL,
                  AppDesign.spacingL,
                  AppDesign.spacingL,
                  AppDesign.spacingM,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(AppDesign.radiusM),
                      ),
                      child: Icon(
                        _isAsset
                            ? CupertinoIcons.arrow_up_right_circle_fill
                            : CupertinoIcons.arrow_down_left_circle_fill,
                        color: Colors.white,
                        size: AppDesign.iconL,
                      ),
                    ),
                    const SizedBox(width: AppDesign.spacingM),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            existingEntry == null
                                ? 'Add Account'
                                : 'Edit Account',
                            style: AppTypography.headingMedium.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            formatNetWorthMonth(widget.month),
                            style: AppTypography.bodySmall.copyWith(
                              color: Colors.white.withValues(alpha: 0.80),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Close button
                    GestureDetector(
                      onTap: () =>
                          Navigator.of(context, rootNavigator: true).pop(),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          CupertinoIcons.xmark,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Form body
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDesign.spacingL,
                  AppDesign.spacingL,
                  AppDesign.spacingL,
                  AppDesign.spacingM,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Type toggle
                    _TypeToggle(
                      selectedType: _selectedType,
                      onChanged: (type) => setState(() => _selectedType = type),
                    ),

                    const SizedBox(height: AppDesign.spacingM),

                    // Account name field
                    _EditorField(
                      label: 'Account Name',
                      controller: _nameController,
                      focusNode: _nameFocus,
                      isFocused: _nameFocused,
                      errorText: _nameError,
                      accentColor: _accentColor(context),
                      prefixIcon: CupertinoIcons.creditcard,
                      keyboardType: TextInputType.text,
                      textCapitalization: TextCapitalization.words,
                      isDark: isDark,
                    ),

                    const SizedBox(height: AppDesign.spacingM),

                    // Balance field
                    _EditorField(
                      label: _isAsset ? 'Asset Balance' : 'Liability Balance',
                      controller: _amountController,
                      focusNode: _amountFocus,
                      isFocused: _amountFocused,
                      errorText: _amountError,
                      accentColor: _accentColor(context),
                      prefixIcon: CupertinoIcons.money_dollar_circle,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [_CurrencyInputFormatter()],
                      isDark: isDark,
                    ),

                    const SizedBox(height: AppDesign.spacingL),

                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: AppButton.secondary(
                            label: 'Cancel',
                            onPressed: () =>
                                Navigator.of(context, rootNavigator: true)
                                    .pop(),
                          ),
                        ),
                        const SizedBox(width: AppDesign.spacingM),
                        Expanded(
                          child: AppButton.primary(
                            label: existingEntry == null ? 'Add' : 'Save',
                            icon: CupertinoIcons.check_mark_circled_solid,
                            gradient: _accentGradient(context),
                            onPressed: _save,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final cleanText = _amountController.text.replaceAll(',', '').trim();
    final parsedAmount = double.tryParse(cleanText);

    setState(() {
      _nameError = null;
      _amountError = null;
    });

    if (_nameController.text.trim().isEmpty) {
      setState(() => _nameError = 'Name is required');
      return;
    }

    if (parsedAmount == null || parsedAmount < 0) {
      setState(() => _amountError = 'Enter a valid balance');
      return;
    }

    if (widget.existingEntry == null) {
      await widget.transactionModel.addNetWorthEntry(
        name: _nameController.text.trim(),
        type: _selectedType,
        amount: parsedAmount,
        month: widget.month,
      );
    } else {
      await widget.transactionModel.updateNetWorthEntry(
        id: widget.existingEntry!.id,
        name: _nameController.text.trim(),
        type: _selectedType,
        amount: parsedAmount,
        month: widget.month,
      );
    }

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
  }
}

// Reusable styled input field for the editor dialog.
class _EditorField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isFocused;
  final String? errorText;
  final Color accentColor;
  final IconData prefixIcon;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final bool isDark;

  const _EditorField({
    required this.label,
    required this.controller,
    required this.focusNode,
    required this.isFocused,
    required this.errorText,
    required this.accentColor,
    required this.prefixIcon,
    required this.isDark,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null;
    final borderColor = hasError
        ? AppDesign.getErrorColor(context)
        : isFocused
            ? accentColor
            : AppDesign.getBorderColor(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: AppDesign.spacingXS,
            bottom: AppDesign.spacingXS,
          ),
          child: Text(
            label,
            style: AppTypography.caption.copyWith(
              color: hasError
                  ? AppDesign.getErrorColor(context)
                  : isFocused
                      ? accentColor
                      : AppDesign.getTextSecondary(context),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.surfaceDark.withValues(alpha: 0.6)
                : AppColors.backgroundLight,
            borderRadius: BorderRadius.circular(AppDesign.radiusM),
            border: Border.all(
              color: borderColor,
              width: isFocused ? AppDesign.borderThick : AppDesign.borderThin,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDesign.spacingM,
              vertical: AppDesign.spacingS,
            ),
            child: Row(
              children: [
                Icon(
                  prefixIcon,
                  size: AppDesign.iconS,
                  color: hasError
                      ? AppDesign.getErrorColor(context)
                      : isFocused
                          ? accentColor
                          : AppDesign.getTextTertiary(context),
                ),
                const SizedBox(width: AppDesign.spacingS),
                Expanded(
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    keyboardType: keyboardType,
                    textCapitalization: textCapitalization,
                    inputFormatters: inputFormatters,
                    style: AppTypography.bodyLarge.copyWith(
                      color: AppDesign.getTextPrimary(context),
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: AppDesign.spacingXS),
          Row(
            children: [
              Icon(
                CupertinoIcons.exclamationmark_circle_fill,
                size: AppDesign.iconXS,
                color: AppDesign.getErrorColor(context),
              ),
              const SizedBox(width: AppDesign.spacingXS),
              Text(
                errorText!,
                style: AppTypography.caption.copyWith(
                  color: AppDesign.getErrorColor(context),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

// Two-pill toggle for asset / liability selection.
class _TypeToggle extends StatelessWidget {
  final NetWorthEntryType selectedType;
  final ValueChanged<NetWorthEntryType> onChanged;

  const _TypeToggle({
    required this.selectedType,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _TypePill(
          label: 'Asset',
          icon: CupertinoIcons.arrow_up_right,
          type: NetWorthEntryType.asset,
          isSelected: selectedType == NetWorthEntryType.asset,
          gradient: AppDesign.getIncomeGradient(context),
          onTap: () => onChanged(NetWorthEntryType.asset),
        ),
        const SizedBox(width: AppDesign.spacingS),
        _TypePill(
          label: 'Liability',
          icon: CupertinoIcons.arrow_down_left,
          type: NetWorthEntryType.liability,
          isSelected: selectedType == NetWorthEntryType.liability,
          gradient: AppDesign.getExpenseGradient(context),
          onTap: () => onChanged(NetWorthEntryType.liability),
        ),
      ],
    );
  }
}

class _TypePill extends StatelessWidget {
  final String label;
  final IconData icon;
  final NetWorthEntryType type;
  final bool isSelected;
  final LinearGradient gradient;
  final VoidCallback onTap;

  const _TypePill({
    required this.label,
    required this.icon,
    required this.type,
    required this.isSelected,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          height: 48,
          decoration: BoxDecoration(
            gradient: isSelected ? gradient : null,
            color: isSelected
                ? null
                : AppDesign.getBorderColor(context).withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(AppDesign.radiusM),
            border: isSelected
                ? null
                : Border.all(color: AppDesign.getBorderColor(context)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: AppDesign.iconXS,
                color: isSelected
                    ? Colors.white
                    : AppDesign.getTextSecondary(context),
              ),
              const SizedBox(width: AppDesign.spacingXS),
              Text(
                label,
                style: AppTypography.labelMedium.copyWith(
                  color: isSelected
                      ? Colors.white
                      : AppDesign.getTextSecondary(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _confirmDeleteNetWorthEntry({
  required BuildContext context,
  required TransactionModel transactionModel,
  required NetWorthEntry entry,
}) async {
  final shouldDelete = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Delete account?'),
        content: Text(
          'Remove ${entry.name} and all of its saved monthly balances?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      );
    },
  );

  if (shouldDelete == true) {
    await transactionModel.deleteNetWorthEntry(entry.id);
  }
}

String _formatCurrency(double value) {
  final formatter = NumberFormat.currency(
    locale: 'en_US',
    symbol: '\$',
    decimalDigits: 2,
  );
  return value < 0
      ? '-${formatter.format(value.abs())}'
      : formatter.format(value);
}

String _formatCompactCurrency(double value) {
  final absValue = value.abs();
  if (absValue >= 1000000) {
    return '${value < 0 ? '-' : ''}\$${(absValue / 1000000).toStringAsFixed(1)}M';
  }
  if (absValue >= 1000) {
    return '${value < 0 ? '-' : ''}\$${(absValue / 1000).toStringAsFixed(1)}k';
  }
  return '${value < 0 ? '-' : ''}\$${absValue.toStringAsFixed(0)}';
}

/// Returns a "nice" rounded interval for chart axes.
double _niceInterval(double range) {
  if (range <= 0) return 1;
  final raw = range / 4;
  final magnitude = pow(10, (log(raw) / log(10)).floor()).toDouble();
  final normalized = raw / magnitude;
  final double nice;
  if (normalized < 1.5) {
    nice = 1;
  } else if (normalized < 3.5) {
    nice = 2;
  } else if (normalized < 7.5) {
    nice = 5;
  } else {
    nice = 10;
  }
  return nice * magnitude;
}
