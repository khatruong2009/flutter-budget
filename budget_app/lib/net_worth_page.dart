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

class NetWorthPage extends StatefulWidget {
  const NetWorthPage({super.key});

  @override
  State<NetWorthPage> createState() => _NetWorthPageState();
}

class _NetWorthPageState extends State<NetWorthPage> {
  final ScrollController _chartScrollController = ScrollController();
  int? _lastChartLength;
  bool _hasScrolledToLatest = false;

  @override
  void dispose() {
    _chartScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TransactionModel>(
      builder: (context, transactionModel, child) {
        final month = transactionModel.selectedNetWorthMonth;
        final monthLabel = formatNetWorthMonth(month);
        final assets = transactionModel.totalAssets;
        final liabilities = transactionModel.totalLiabilities;
        final netWorth = transactionModel.netWorth;
        final staleCount = transactionModel.staleNetWorthEntryCount;
        final trackedCount = transactionModel.getTrackedNetWorthEntryCountForMonth(
          month,
        );
        final updatedCount = transactionModel.getUpdatedNetWorthEntryCountForMonth(
          month,
        );
        final assetEntries =
            transactionModel.assetEntriesForSelectedNetWorthMonth;
        final liabilityEntries =
            transactionModel.liabilityEntriesForSelectedNetWorthMonth;
        final availableMonths = transactionModel.getNetWorthAvailableMonths();
        final history = transactionModel.getNetWorthHistory(limit: 24);
        final chartData = history.reversed.toList();
        final previousMonth = DateTime(month.year, month.month - 1);
        final hasPreviousData =
            transactionModel.hasNetWorthDataForMonth(previousMonth);
        final monthChange = hasPreviousData
            ? netWorth - transactionModel.getNetWorthForMonth(previousMonth)
            : null;

        return Scaffold(
          appBar: AppBar(
            title: Text(
              'Net Worth',
              style: AppTypography.headingLarge.copyWith(
                color: AppDesign.getTextPrimary(context),
              ),
            ),
            centerTitle: true,
            backgroundColor: AppDesign.getBackgroundColor(context),
            elevation: 0,
          ),
          backgroundColor: AppDesign.getBackgroundColor(context),
          body: transactionModel.hasNetWorthEntries
              ? SingleChildScrollView(
                  physics: PlatformUtils.platformScrollPhysics,
                  padding: const EdgeInsets.all(AppDesign.spacingM),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _NetWorthHeroCard(
                        monthLabel: monthLabel,
                        netWorth: netWorth,
                        monthChange: monthChange,
                        updatedCount: updatedCount,
                        trackedCount: trackedCount,
                      ),
                      const SizedBox(height: AppDesign.spacingM),
                      Row(
                        children: [
                          Expanded(
                            child: _MetricTile(
                              label: 'Assets',
                              value: _formatCurrency(assets),
                              accentColor: AppDesign.getIncomeColor(context),
                              icon: CupertinoIcons.arrow_up_right_circle_fill,
                            ),
                          ),
                          const SizedBox(width: AppDesign.spacingM),
                          Expanded(
                            child: _MetricTile(
                              label: 'Liabilities',
                              value: _formatCurrency(liabilities),
                              accentColor: AppDesign.getExpenseColor(context),
                              icon: CupertinoIcons.arrow_down_left_circle_fill,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppDesign.spacingM),
                      ElevatedCard(
                        elevation: AppDesign.elevationM,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Timeline',
                              style: AppTypography.headingMedium.copyWith(
                                color: AppDesign.getTextPrimary(context),
                              ),
                            ),
                            const SizedBox(height: AppDesign.spacingXS),
                            Text(
                              'Net worth over time across your saved monthly snapshots.',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppDesign.getTextSecondary(context),
                              ),
                            ),
                            const SizedBox(height: AppDesign.spacingM),
                            _buildChart(chartData),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppDesign.spacingM),
                      ElevatedCard(
                        elevation: AppDesign.elevationM,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Monthly Workflow',
                              style: AppTypography.headingMedium.copyWith(
                                color: AppDesign.getTextPrimary(context),
                              ),
                            ),
                            const SizedBox(height: AppDesign.spacingXS),
                            Text(
                              staleCount > 0
                                  ? '$staleCount account${staleCount == 1 ? '' : 's'} still show their latest saved balances in $monthLabel.'
                                  : 'Every tracked account has a fresh balance saved for $monthLabel.',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppDesign.getTextSecondary(context),
                              ),
                            ),
                            const SizedBox(height: AppDesign.spacingM),
                            MonthSelector(
                              selectedMonth: month,
                              availableMonths: availableMonths,
                              onMonthChanged: (selectedMonth) async {
                                await transactionModel.selectNetWorthMonth(
                                  selectedMonth,
                                );
                              },
                            ),
                            const SizedBox(height: AppDesign.spacingM),
                            Wrap(
                              spacing: AppDesign.spacingS,
                              runSpacing: AppDesign.spacingS,
                              children: [
                                AppButton.primary(
                                  label: 'Add Account',
                                  icon: CupertinoIcons.plus_circle_fill,
                                  gradient: AppDesign.getPrimaryGradient(context),
                                  onPressed: () => _showNetWorthEditor(
                                    context: context,
                                    transactionModel: transactionModel,
                                    month: month,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppDesign.spacingM),
                      _SectionCard(
                        title: 'Assets',
                        subtitle:
                            '${assetEntries.length} tracked in $monthLabel',
                        onAdd: () => _showNetWorthEditor(
                          context: context,
                          transactionModel: transactionModel,
                          month: month,
                          initialType: NetWorthEntryType.asset,
                        ),
                        addLabel: 'Add Account',
                        entries: assetEntries,
                        month: month,
                      ),
                      const SizedBox(height: AppDesign.spacingM),
                      _SectionCard(
                        title: 'Liabilities',
                        subtitle:
                            '${liabilityEntries.length} tracked in $monthLabel',
                        onAdd: () => _showNetWorthEditor(
                          context: context,
                          transactionModel: transactionModel,
                          month: month,
                          initialType: NetWorthEntryType.liability,
                        ),
                        addLabel: 'Add Account',
                        entries: liabilityEntries,
                        month: month,
                      ),
                      const SizedBox(height: AppDesign.spacingM),
                      ElevatedCard(
                        elevation: AppDesign.elevationM,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Recent Months',
                              style: AppTypography.headingMedium.copyWith(
                                color: AppDesign.getTextPrimary(context),
                              ),
                            ),
                            const SizedBox(height: AppDesign.spacingS),
                            ...history.take(6).map(
                              (summary) {
                                final priorMonth = DateTime(
                                  summary.month.year,
                                  summary.month.month - 1,
                                );
                                final change = transactionModel
                                        .hasNetWorthDataForMonth(priorMonth)
                                    ? summary.netWorth -
                                        transactionModel.getNetWorthForMonth(
                                          priorMonth,
                                        )
                                    : null;

                                return Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: AppDesign.spacingS,
                                  ),
                                  child: _HistoryRow(
                                    summary: summary,
                                    change: change,
                                    isSelected: _isSameMonth(
                                      summary.month,
                                      month,
                                    ),
                                    onTap: () async {
                                      await transactionModel.selectNetWorthMonth(
                                        summary.month,
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
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
                    transactionModel: transactionModel,
                    month: month,
                  ),
                ),
        );
      },
    );
  }

  Widget _buildChart(List<NetWorthMonthSummary> chartData) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (chartData.isEmpty) {
      return Container(
        height: 220,
        alignment: Alignment.center,
        child: Text(
          'Add monthly balances to build your line chart.',
          style: AppTypography.bodyMedium.copyWith(
            color: AppDesign.getTextSecondary(context),
          ),
        ),
      );
    }

    if (_lastChartLength != chartData.length) {
      _lastChartLength = chartData.length;
      _hasScrolledToLatest = false;
    }

    final needsScrolling = chartData.length > 8;
    final chartWidth = max(
      MediaQuery.of(context).size.width - (AppDesign.spacingM * 4),
      chartData.length * 72.0,
    );

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

    final chart = SizedBox(
      width: chartWidth,
      height: 260,
      child: _NetWorthLineChart(
        chartData: chartData,
        isDark: isDark,
      ),
    );

    if (!needsScrolling) {
      return SizedBox(
        height: 260,
        child: chart,
      );
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
              'Swipe to see the full history',
              style: AppTypography.bodySmall.copyWith(
                color: AppDesign.getTextTertiary(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDesign.spacingS),
        SizedBox(
          height: 260,
          child: SingleChildScrollView(
            controller: _chartScrollController,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: chart,
          ),
        ),
      ],
    );
  }

  bool _isSameMonth(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month;
  }
}

class _NetWorthHeroCard extends StatelessWidget {
  final String monthLabel;
  final double netWorth;
  final double? monthChange;
  final int updatedCount;
  final int trackedCount;

  const _NetWorthHeroCard({
    required this.monthLabel,
    required this.netWorth,
    required this.monthChange,
    required this.updatedCount,
    required this.trackedCount,
  });

  @override
  Widget build(BuildContext context) {
    final completion = trackedCount == 0 ? 0.0 : updatedCount / trackedCount;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDesign.spacingL),
      decoration: BoxDecoration(
        gradient: AppDesign.getAccentGradient(context),
        borderRadius: BorderRadius.circular(AppDesign.radiusXL),
        boxShadow: AppDesign.shadowL,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            monthLabel,
            style: AppTypography.bodyMedium.copyWith(
              color: Colors.white.withValues(alpha: 0.88),
            ),
          ),
          const SizedBox(height: AppDesign.spacingXS),
          Text(
            _formatCurrency(netWorth),
            style: AppTypography.displayLarge.copyWith(
              color: Colors.white,
            ),
          ),
          const SizedBox(height: AppDesign.spacingM),
          Wrap(
            spacing: AppDesign.spacingS,
            runSpacing: AppDesign.spacingS,
            children: [
              _HeroChip(
                label: monthChange == null
                    ? 'No prior month'
                    : '${monthChange! >= 0 ? '+' : '-'}${_formatCurrency(monthChange!.abs())} vs last month',
              ),
              _HeroChip(
                label: '$updatedCount of $trackedCount accounts updated',
              ),
            ],
          ),
          const SizedBox(height: AppDesign.spacingM),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppDesign.radiusRound),
            child: LinearProgressIndicator(
              value: completion,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.24),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  final String label;

  const _HeroChip({
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDesign.spacingM,
        vertical: AppDesign.spacingS,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppDesign.radiusRound),
      ),
      child: Text(
        label,
        style: AppTypography.bodySmall.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final Color accentColor;
  final IconData icon;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.accentColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedCard(
      elevation: AppDesign.elevationM,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accentColor),
          const SizedBox(height: AppDesign.spacingS),
          Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              color: AppDesign.getTextSecondary(context),
            ),
          ),
          const SizedBox(height: AppDesign.spacingXS),
          Text(
            value,
            style: AppTypography.headingMedium.copyWith(
              color: accentColor,
            ),
          ),
        ],
      ),
    );
  }
}

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
    final range = max(maxValue - minValue, 1.0);
    final paddedMin = minValue - (range * 0.18);
    final paddedMax = maxValue + (range * 0.18);

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (chartData.length - 1).toDouble(),
        minY: paddedMin,
        maxY: paddedMax,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: range / 4,
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
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= chartData.length) {
                  return const SizedBox.shrink();
                }

                final shouldShow =
                    chartData.length <= 6 || index.isEven || index == chartData.length - 1;
                if (!shouldShow) {
                  return const SizedBox.shrink();
                }

                final month = chartData[index].month;
                return SideTitleWidget(
                  meta: meta,
                  child: Text(
                    DateFormat('MMM yy').format(month),
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
              reservedSize: 68,
              getTitlesWidget: (value, meta) {
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
                final month = chartData[spot.x.toInt()].month;
                final value = chartData[spot.x.toInt()].netWorth;
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
            spots: List.generate(
              chartData.length,
              (index) => FlSpot(index.toDouble(), chartData[index].netWorth),
            ),
            isCurved: true,
            color: AppColors.primary,
            barWidth: 4,
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.24),
                  AppColors.primary.withValues(alpha: 0.02),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                final value = chartData[index].netWorth;
                return FlDotCirclePainter(
                  radius: 4.5,
                  color: value >= 0 ? AppColors.primary : AppColors.expense,
                  strokeWidth: 2,
                  strokeColor:
                      isDark ? AppColors.cardDark : AppColors.cardLight,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String addLabel;
  final VoidCallback onAdd;
  final List<NetWorthEntry> entries;
  final DateTime month;

  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.addLabel,
    required this.onAdd,
    required this.entries,
    required this.month,
  });

  @override
  Widget build(BuildContext context) {
    final transactionModel = Provider.of<TransactionModel>(
      context,
      listen: false,
    );

    return ElevatedCard(
      elevation: AppDesign.elevationM,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.headingMedium.copyWith(
                        color: AppDesign.getTextPrimary(context),
                      ),
                    ),
                    const SizedBox(height: AppDesign.spacingXXS),
                    Text(
                      subtitle,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppDesign.getTextSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: onAdd,
                icon: const Icon(CupertinoIcons.plus, size: AppDesign.iconS),
                label: Text(addLabel),
              ),
            ],
          ),
          const SizedBox(height: AppDesign.spacingM),
          if (entries.isEmpty)
            Text(
              'No $title saved for ${formatNetWorthMonth(month)} yet.',
              style: AppTypography.bodyMedium.copyWith(
                color: AppDesign.getTextSecondary(context),
              ),
            )
          else
            ...entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: AppDesign.spacingS),
                child: _AccountRow(
                  entry: entry,
                  month: month,
                  onEdit: () => _showNetWorthEditor(
                    context: context,
                    transactionModel: transactionModel,
                    month: month,
                    existingEntry: entry,
                  ),
                  onDelete: () => _confirmDeleteNetWorthEntry(
                    context: context,
                    transactionModel: transactionModel,
                    entry: entry,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  final NetWorthEntry entry;
  final DateTime month;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AccountRow({
    required this.entry,
    required this.month,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final exactSnapshot = entry.snapshotForMonth(month);
    final effectiveSnapshot = entry.latestSnapshotThrough(month);
    final amount = effectiveSnapshot?.amount ?? 0.0;
    final isCurrentMonth = exactSnapshot != null;

    return Container(
      padding: const EdgeInsets.all(AppDesign.spacingM),
      decoration: BoxDecoration(
        color: AppDesign.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(AppDesign.radiusL),
        border: Border.all(
          color: AppDesign.getBorderColor(context),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: (entry.type == NetWorthEntryType.asset
                      ? AppDesign.getIncomeColor(context)
                      : AppDesign.getExpenseColor(context))
                  .withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppDesign.radiusM),
            ),
            child: Icon(
              entry.type == NetWorthEntryType.asset
                  ? CupertinoIcons.arrow_up_right_circle_fill
                  : CupertinoIcons.arrow_down_left_circle_fill,
              color: entry.type == NetWorthEntryType.asset
                  ? AppDesign.getIncomeColor(context)
                  : AppDesign.getExpenseColor(context),
            ),
          ),
          const SizedBox(width: AppDesign.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.name,
                  style: AppTypography.bodyLarge.copyWith(
                    color: AppDesign.getTextPrimary(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppDesign.spacingXXS),
                Text(
                  isCurrentMonth
                      ? 'Updated for ${formatNetWorthMonth(month)}'
                      : effectiveSnapshot == null
                          ? 'No balance saved yet'
                          : 'Using ${formatNetWorthMonth(netWorthMonthFromKey(effectiveSnapshot.monthKey))} value',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppDesign.getTextSecondary(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppDesign.spacingS),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatCurrency(amount),
                style: AppTypography.bodyLarge.copyWith(
                  color: AppDesign.getTextPrimary(context),
                  fontWeight: FontWeight.w700,
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'delete') {
                    onDelete();
                  } else {
                    onEdit();
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem<String>(
                    value: 'edit',
                    child: Text('Edit Balance'),
                  ),
                  PopupMenuItem<String>(
                    value: 'delete',
                    child: Text('Delete Account'),
                  ),
                ],
                child: Padding(
                  padding: const EdgeInsets.only(top: AppDesign.spacingXS),
                  child: Icon(
                    CupertinoIcons.ellipsis_circle,
                    color: AppDesign.getTextTertiary(context),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final NetWorthMonthSummary summary;
  final double? change;
  final bool isSelected;
  final VoidCallback onTap;

  const _HistoryRow({
    required this.summary,
    required this.change,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDesign.radiusL),
      child: Container(
        padding: const EdgeInsets.all(AppDesign.spacingM),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.1)
              : AppDesign.getSurfaceColor(context),
          borderRadius: BorderRadius.circular(AppDesign.radiusL),
          border: Border.all(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.4)
                : AppDesign.getBorderColor(context),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatNetWorthMonth(summary.month),
                    style: AppTypography.bodyLarge.copyWith(
                      color: AppDesign.getTextPrimary(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppDesign.spacingXXS),
                  Text(
                    change == null
                        ? 'First tracked month'
                        : '${change! >= 0 ? '+' : '-'}${_formatCurrency(change!.abs())} vs previous month',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppDesign.getTextSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              _formatCurrency(summary.netWorth),
              style: AppTypography.bodyLarge.copyWith(
                color: summary.netWorth >= 0
                    ? AppDesign.getIncomeColor(context)
                    : AppDesign.getExpenseColor(context),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
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
                existingEntry == null ? 'Add Account' : 'Update ${existingEntry.name}',
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
                      onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
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
  return value < 0 ? '-${formatter.format(value.abs())}' : formatter.format(value);
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
