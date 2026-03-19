import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
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
  final List<NetWorthMonthSummary> chartData;

  const _GrowthChartCard({required this.chartData});

  @override
  State<_GrowthChartCard> createState() => _GrowthChartCardState();
}

class _GrowthChartCardState extends State<_GrowthChartCard> {
  final ScrollController _scrollController = ScrollController();
  int? _lastLength;
  bool _hasScrolledToLatest = false;

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
          const SizedBox(height: AppDesign.spacingM),
          if (chartData.isEmpty)
            Container(
              height: 220,
              alignment: Alignment.center,
              child: Text(
                'Add monthly balances to build your growth chart.',
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
    List<NetWorthMonthSummary> chartData,
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
      child: _NetWorthLineChart(chartData: chartData, isDark: isDark),
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
}

// ---------- Line Chart ----------

class _NetWorthLineChart extends StatelessWidget {
  final List<NetWorthMonthSummary> chartData;
  final bool isDark;

  const _NetWorthLineChart({
    required this.chartData,
    required this.isDark,
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
                final month = chartData[index].month;
                return SideTitleWidget(
                  meta: meta,
                  child: Text(
                    DateFormat('MMM').format(month),
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
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) =>
                isDark ? AppColors.cardDark : AppColors.cardLight,
            tooltipBorder: BorderSide(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
            ),
            getTooltipItems: (spots) {
              return spots.map((spot) {
                final index = spot.x.toInt().clamp(0, chartData.length - 1);
                final month = chartData[index].month;
                final value = chartData[index].netWorth;
                return LineTooltipItem(
                  '${DateFormat('MMM y').format(month)}\n',
                  AppTypography.bodySmall.copyWith(
                    color: AppDesign.getTextPrimary(context),
                    fontWeight: FontWeight.w700,
                  ),
                  children: [
                    TextSpan(
                      text: _formatCurrency(value),
                      style: AppTypography.bodySmall.copyWith(
                        color: value >= 0
                            ? AppDesign.getIncomeColor(context)
                            : AppDesign.getExpenseColor(context),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                );
              }).toList();
            },
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: chartData.length == 1
                ? [
                    FlSpot(0.0, chartData[0].netWorth),
                    FlSpot(1.0, chartData[0].netWorth),
                  ]
                : List.generate(
                    chartData.length,
                    (index) =>
                        FlSpot(index.toDouble(), chartData[index].netWorth),
                  ),
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
            dotData: const FlDotData(show: false),
          ),
        ],
      ),
    );
  }
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
    final effectiveSnapshot = entry.latestSnapshotThrough(month);
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
  late NetWorthEntryType _selectedType;
  String? _nameError;
  String? _amountError;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.existingEntry?.name ?? '',
    );
    _amountController = TextEditingController(
      text: widget.existingEntry == null
          ? ''
          : (widget.existingEntry!.amountForMonth(widget.month) ?? 0.0)
              .toStringAsFixed(2),
    );
    _selectedType = widget.existingEntry?.type ??
        widget.initialType ??
        NetWorthEntryType.asset;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final existingEntry = widget.existingEntry;
    final hasPriorValue = existingEntry != null &&
        existingEntry.snapshotForMonth(widget.month) == null &&
        existingEntry.latestSnapshotThrough(widget.month) != null;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppDesign.spacingL,
        vertical: AppDesign.spacingXL,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppDesign.getCardColor(context),
          borderRadius: BorderRadius.circular(AppDesign.radiusXL),
          boxShadow: AppDesign.shadowXL,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDesign.spacingM),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                existingEntry == null
                    ? 'Add Account'
                    : 'Update ${existingEntry.name}',
                style: AppTypography.headingMedium.copyWith(
                  color: AppDesign.getTextPrimary(context),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDesign.spacingXS),
              Text(
                'Save a balance for ${formatNetWorthMonth(widget.month)}.',
                style: AppTypography.bodySmall.copyWith(
                  color: AppDesign.getTextSecondary(context),
                ),
                textAlign: TextAlign.center,
              ),
              if (hasPriorValue) ...[
                const SizedBox(height: AppDesign.spacingS),
                Text(
                  'This account is currently carrying forward an older balance.',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppDesign.getTextSecondary(context),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: AppDesign.spacingM),
              _TypeSelector(
                selectedType: _selectedType,
                onChanged: (type) {
                  if (type == null) return;
                  setState(() {
                    _selectedType = type;
                  });
                },
              ),
              const SizedBox(height: AppDesign.spacingM),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Account Name',
                  errorText: _nameError,
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: AppDesign.spacingS),
              TextField(
                controller: _amountController,
                decoration: InputDecoration(
                  labelText: _selectedType == NetWorthEntryType.asset
                      ? 'Asset Balance'
                      : 'Liability Balance',
                  prefixText: '\$',
                  errorText: _amountError,
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: AppDesign.spacingM),
              Row(
                children: [
                  Expanded(
                    child: AppButton.secondary(
                      label: 'Cancel',
                      onPressed: () =>
                          Navigator.of(context, rootNavigator: true).pop(),
                    ),
                  ),
                  const SizedBox(width: AppDesign.spacingM),
                  Expanded(
                    child: AppButton.primary(
                      label: existingEntry == null ? 'Add' : 'Save',
                      icon: CupertinoIcons.check_mark_circled_solid,
                      gradient: _selectedType == NetWorthEntryType.asset
                          ? AppDesign.getIncomeGradient(context)
                          : AppDesign.getExpenseGradient(context),
                      onPressed: _save,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final parsedAmount = double.tryParse(_amountController.text.trim());

    setState(() {
      _nameError = null;
      _amountError = null;
    });

    if (_nameController.text.trim().isEmpty) {
      setState(() {
        _nameError = 'Name is required';
      });
      return;
    }

    if (parsedAmount == null || parsedAmount < 0) {
      setState(() {
        _amountError = 'Enter a valid balance';
      });
      return;
    }

    if (widget.existingEntry == null) {
      await widget.transactionModel.addNetWorthEntry(
        name: _nameController.text,
        type: _selectedType,
        amount: parsedAmount,
        month: widget.month,
      );
    } else {
      await widget.transactionModel.updateNetWorthEntry(
        id: widget.existingEntry!.id,
        name: _nameController.text,
        type: _selectedType,
        amount: parsedAmount,
        month: widget.month,
      );
    }

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
  }
}

class _TypeSelector extends StatelessWidget {
  final NetWorthEntryType selectedType;
  final ValueChanged<NetWorthEntryType?> onChanged;

  const _TypeSelector({
    required this.selectedType,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoSlidingSegmentedControl<NetWorthEntryType>(
      groupValue: selectedType,
      onValueChanged: onChanged,
      children: {
        NetWorthEntryType.asset: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDesign.spacingM,
            vertical: AppDesign.spacingS,
          ),
          child: Text(
            'Asset',
            style: AppTypography.bodyMedium.copyWith(
              color: selectedType == NetWorthEntryType.asset
                  ? Colors.white
                  : AppDesign.getTextPrimary(context),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        NetWorthEntryType.liability: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDesign.spacingM,
            vertical: AppDesign.spacingS,
          ),
          child: Text(
            'Liability',
            style: AppTypography.bodyMedium.copyWith(
              color: selectedType == NetWorthEntryType.liability
                  ? Colors.white
                  : AppDesign.getTextPrimary(context),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      },
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
