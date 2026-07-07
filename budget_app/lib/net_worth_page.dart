import 'dart:math';

import 'package:animated_digit/animated_digit.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import 'design_system.dart';
import 'net_worth_entry.dart';
import 'transaction_model.dart';
import 'utils/platform_utils.dart';
import 'widgets/month_selector.dart';

// ---------- Main Page ----------

/// Chart range filter for the growth card.
enum _GrowthRange { sixMonths, oneYear, all }

class NetWorthPage extends StatefulWidget {
  const NetWorthPage({super.key});

  @override
  State<NetWorthPage> createState() => _NetWorthPageState();
}

class _NetWorthPageState extends State<NetWorthPage> {
  int _selectedTab = 0; // 0 = Assets, 1 = Liabilities
  _GrowthRange _range = _GrowthRange.oneYear;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
        // getNetWorthHistory returns newest-first; chart wants oldest-first.
        final chartData = history.reversed.toList();
        final previousMonth = DateTime(month.year, month.month - 1);
        final hasPreviousData = model.hasNetWorthDataForMonth(previousMonth);
        final previousNetWorth =
            hasPreviousData ? model.getNetWorthForMonth(previousMonth) : null;
        final monthChange =
            previousNetWorth == null ? null : netWorth - previousNetWorth;

        if (!model.hasNetWorthEntries) {
          return BudgiePageScaffold(
            fab: GlowFab(
              onPressed: () => _showNetWorthEditor(
                context: context,
                transactionModel: model,
                month: month,
              ),
              semanticLabel: 'Add account',
            ),
            body: SingleChildScrollView(
              padding: EdgeInsets.only(
                bottom: DockMetrics.contentBottomPadding(context),
              ),
              child: SafeArea(
                bottom: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const BudgieHeader(title: 'Net worth'),
                    const SizedBox(height: 8),
                    _NetWorthEmptyState(
                      onAddAccount: () => _showNetWorthEditor(
                        context: context,
                        transactionModel: model,
                        month: month,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return BudgiePageScaffold(
          fab: GlowFab(
            onPressed: () => _showNetWorthEditor(
              context: context,
              transactionModel: model,
              month: month,
              initialType: _selectedTab == 0
                  ? NetWorthEntryType.asset
                  : NetWorthEntryType.liability,
            ),
            semanticLabel: 'Add account',
          ),
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
                  const BudgieHeader(title: 'Net worth'),
                  // Month selector strip preserves month navigation.
                  MonthSelector(
                    selectedMonth: month,
                    availableMonths: availableMonths,
                    onMonthChanged: (m) async {
                      await model.selectNetWorthMonth(m);
                    },
                  ),
                  // Hero.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                    child: _NetWorthHero(
                      month: month,
                      netWorth: netWorth,
                      change: monthChange,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Growth chart card.
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _GrowthChartCard(
                      chartData: chartData,
                      range: _range,
                      onRangeChanged: (r) => setState(() => _range = r),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Assets vs liabilities split card.
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _AssetsLiabilitiesCard(
                      assets: assets,
                      liabilities: liabilities,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Assets / Liabilities toggle chips.
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _AccountsToggle(
                      selectedTab: _selectedTab,
                      onTabChanged: (tab) => setState(() => _selectedTab = tab),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Accounts list.
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
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
                      onViewHistory: (entry) => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => _AccountHistoryPage(entry: entry),
                        ),
                      ),
                      onDeleteEntry: (entry) => _confirmDeleteNetWorthEntry(
                        context: context,
                        transactionModel: model,
                        entry: entry,
                      ),
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
}

// ---------- Empty state ----------

class _NetWorthEmptyState extends StatelessWidget {
  final VoidCallback onAddAccount;

  const _NetWorthEmptyState({required this.onAddAccount});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = AppColors.getAccent(isDark);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 48, 20, 0),
      child: GlowCard(
        child: Column(
          children: [
            IconTile(
              icon: Symbols.trending_up_rounded,
              color: accent,
              size: 56,
              iconSize: 28,
            ),
            const SizedBox(height: 20),
            Text(
              'No net worth accounts yet',
              textAlign: TextAlign.center,
              style: AppTypography.sectionHeader.copyWith(
                color: AppColors.getTextColor(isDark),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first asset or liability to start tracking net '
              'worth over time.',
              textAlign: TextAlign.center,
              style: AppTypography.rowSubtitle.copyWith(
                fontSize: 13,
                color: AppColors.getTextSecondaryColor(isDark),
              ),
            ),
            const SizedBox(height: 20),
            PillButton(
              label: 'Add account',
              icon: Symbols.add_rounded,
              color: accent,
              filled: true,
              height: 48,
              onPressed: onAddAccount,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- Hero ----------

class _NetWorthHero extends StatelessWidget {
  final DateTime month;
  final double netWorth;
  final double? change;
  final bool isDark;

  const _NetWorthHero({
    required this.month,
    required this.netWorth,
    required this.change,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final green = AppColors.getIncome(isDark);
    final rose = AppColors.getDanger(isDark);
    // Hero glows green when positive (design), rose when net worth is negative.
    final glowColor = netWorth >= 0 ? green : rose;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    final heroStyle = AppTypography.heroMedium.copyWith(
      color: AppColors.getTextColor(isDark),
      shadows: AppColors.textGlow(glowColor, alpha: 0.35, isDark: isDark),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TOTAL · ${DateFormat('MMMM y').format(month).toUpperCase()}',
          style: AppTypography.eyebrow.copyWith(
            color: AppColors.getTextSecondaryColor(isDark),
          ),
        ),
        const SizedBox(height: 10),
        Semantics(
          label: 'Net worth ${_formatCurrency(netWorth)}',
          child: Row(
            children: [
              if (netWorth < 0) Text('-', style: heroStyle),
              AnimatedDigitWidget(
                value: netWorth.abs(),
                fractionDigits: 0,
                enableSeparator: true,
                prefix: '\$',
                duration: reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 900),
                textStyle: heroStyle,
              ),
            ],
          ),
        ),
        if (change != null) ...[
          const SizedBox(height: 12),
          _DeltaPill(
            change: change!,
            previousNetWorth: netWorth - change!,
            isDark: isDark,
          ),
        ],
      ],
    );
  }
}

/// Hero delta badge: tinted background AND a matching-color 35% border, with a
/// trending icon. `+$4,120 · +2.3% this month`.
class _DeltaPill extends StatelessWidget {
  final double change;
  final double previousNetWorth;
  final bool isDark;

  const _DeltaPill({
    required this.change,
    required this.previousNetWorth,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final isPositive = change >= 0;
    final color =
        isPositive ? AppColors.getIncome(isDark) : AppColors.getDanger(isDark);

    final dollarStr =
        '${isPositive ? '+' : '-'}${_formatCurrencyNoDecimals(change.abs())}';
    final percentStr = previousNetWorth.abs() > 0.001
        ? '${isPositive ? '+' : '-'}'
            '${(change.abs() / previousNetWorth.abs() * 100).toStringAsFixed(1)}%'
        : '${isPositive ? '+' : '-'}—';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPositive
                ? Symbols.trending_up_rounded
                : Symbols.trending_down_rounded,
            size: 15,
            weight: 500,
            color: color,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              '$dollarStr · $percentStr this month',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.badge.copyWith(
                fontSize: 13,
                color: color,
              ),
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
  final _GrowthRange range;
  final ValueChanged<_GrowthRange> onRangeChanged;

  const _GrowthChartCard({
    required this.chartData,
    required this.range,
    required this.onRangeChanged,
  });

  @override
  State<_GrowthChartCard> createState() => _GrowthChartCardState();
}

class _GrowthChartCardState extends State<_GrowthChartCard> {
  int? _selectedSpotIndex;

  /// Filters the (oldest-first) chart data by the active range relative to the
  /// newest recorded point.
  List<NetWorthHistoryPoint> get _rangeData {
    final data = widget.chartData;
    if (data.isEmpty || widget.range == _GrowthRange.all) {
      return data;
    }
    final months = widget.range == _GrowthRange.sixMonths ? 6 : 12;
    final anchor = data.last.date;
    final cutoff = DateTime(anchor.year, anchor.month - (months - 1));
    final filtered = data
        .where((p) => !DateTime(p.date.year, p.date.month).isBefore(cutoff))
        .toList();
    // Keep at least two points so the line is meaningful.
    if (filtered.length < 2 && data.length >= 2) {
      return data.sublist(data.length - 2);
    }
    return filtered.isEmpty ? data : filtered;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chartData = _rangeData;
    final selected = _selectedSpotIndex?.clamp(0, chartData.length - 1);

    return GlowCard(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    'Growth',
                    style: AppTypography.cardTitle.copyWith(
                      color: AppColors.getTextColor(isDark),
                    ),
                  ),
                ),
                SegmentedPillControl(
                  segments: const ['6M', '1Y', 'ALL'],
                  selectedIndex: widget.range.index,
                  mono: true,
                  onChanged: (i) {
                    setState(() => _selectedSpotIndex = null);
                    widget.onRangeChanged(_GrowthRange.values[i]);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (chartData.isEmpty)
            SizedBox(
              height: 180,
              child: Center(
                child: Text(
                  'Add balance updates to build your growth chart.',
                  textAlign: TextAlign.center,
                  style: AppTypography.rowSubtitle.copyWith(
                    fontSize: 13,
                    color: AppColors.getTextSecondaryColor(isDark),
                  ),
                ),
              ),
            )
          else ...[
            SizedBox(
              height: 180,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: _NetWorthLineChart(
                      chartData: chartData,
                      isDark: isDark,
                      selectedSpotIndex: selected,
                      onTouchSpot: _handleTouchSpot,
                    ),
                  ),
                  if (selected != null)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: _NetWorthHoverCard(
                          point: chartData[selected],
                          alignment:
                              _overlayAlignment(selected, chartData, isDark),
                          isDark: isDark,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            _AxisLabels(chartData: chartData, isDark: isDark),
          ],
        ],
      ),
    );
  }

  void _handleTouchSpot(FlTouchEvent event, int? spotIndex) {
    final data = _rangeData;
    if (data.isEmpty) {
      return;
    }

    if (event is FlLongPressStart || event is FlLongPressMoveUpdate) {
      if (spotIndex == null) {
        return;
      }
      final normalized = spotIndex.clamp(0, data.length - 1);
      if (_selectedSpotIndex == normalized) {
        return;
      }
      HapticFeedback.selectionClick();
      setState(() => _selectedSpotIndex = normalized);
      return;
    }

    if (_selectedSpotIndex != null &&
        (event is FlLongPressEnd || !event.isInterestedForInteractions)) {
      setState(() => _selectedSpotIndex = null);
    }
  }

  Alignment _overlayAlignment(
    int selectedIndex,
    List<NetWorthHistoryPoint> chartData,
    bool isDark,
  ) {
    final point = chartData[selectedIndex];
    final values = chartData.map((item) => item.netWorth).toList();
    final minValue = values.reduce(min);
    final maxValue = values.reduce(max);
    final midpoint = (minValue + maxValue) / 2;
    final useBottom = point.netWorth >= midpoint;

    final x = chartData.length <= 1
        ? 0.0
        : (selectedIndex / (chartData.length - 1) * 2 - 1)
            .clamp(-0.84, 0.84)
            .toDouble();
    return Alignment(x, useBottom ? 0.5 : -0.6);
  }
}

/// Mono first / mid / last axis labels beneath the growth chart.
class _AxisLabels extends StatelessWidget {
  final List<NetWorthHistoryPoint> chartData;
  final bool isDark;

  const _AxisLabels({required this.chartData, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.getTextTertiaryColor(isDark);
    final labelStyle = AppTypography.monoAxis.copyWith(color: color);

    String label(NetWorthHistoryPoint p) =>
        DateFormat("MMM ''yy").format(p.date).toUpperCase();

    final first = chartData.first;
    final last = chartData.last;
    final mid = chartData[chartData.length ~/ 2];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label(first), style: labelStyle),
          if (chartData.length > 2) Text(label(mid), style: labelStyle),
          Text(label(last), style: labelStyle),
        ],
      ),
    );
  }
}

// ---------- Line Chart ----------

class _NetWorthChartScale {
  final double paddedMin;
  final double paddedMax;

  const _NetWorthChartScale({
    required this.paddedMin,
    required this.paddedMax,
  });
}

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
    final scale = _netWorthChartScale(chartData);
    final green = AppColors.getIncome(isDark);
    final gridColor = AppColors.getHairline(isDark);

    final lineSpots = chartData.length == 1
        ? [
            FlSpot(0, chartData[0].netWorth),
            FlSpot(1, chartData[0].netWorth),
          ]
        : List.generate(
            chartData.length,
            (index) => FlSpot(index.toDouble(), chartData[index].netWorth),
          );

    final lastIndex = lineSpots.length - 1;

    // Glow: a wider, low-opacity line drawn under the main 3px line.
    final glowBar = LineChartBarData(
      spots: lineSpots,
      isCurved: true,
      curveSmoothness: 0.28,
      color: green.withValues(alpha: 0.35),
      barWidth: 9,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
    );

    final mainBar = LineChartBarData(
      spots: lineSpots,
      isCurved: true,
      curveSmoothness: 0.28,
      color: green,
      barWidth: 3,
      isStrokeCapRound: true,
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            green.withValues(alpha: 0.35),
            green.withValues(alpha: 0.0),
          ],
        ),
      ),
      dotData: FlDotData(
        show: true,
        // Always show the white endpoint dot; also the selected spot.
        checkToShowDot: (spot, _) {
          final i = spot.x.round();
          return i == lastIndex ||
              (selectedSpotIndex != null && i == selectedSpotIndex);
        },
        getDotPainter: (spot, _, __, index) {
          final i = spot.x.round();
          if (i == lastIndex && selectedSpotIndex == null) {
            return FlDotCirclePainter(
              radius: 5,
              color: const Color(0xFFF2F2FA),
              strokeWidth: 3,
              strokeColor: green.withValues(alpha: 0.5),
            );
          }
          return FlDotCirclePainter(
            radius: 5,
            color: green,
            strokeWidth: 3,
            strokeColor: green.withValues(alpha: 0.25),
          );
        },
      ),
    );

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: max(1.0, (chartData.length - 1).toDouble()),
        minY: scale.paddedMin,
        maxY: scale.paddedMax,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: (scale.paddedMax - scale.paddedMin) / 4,
          getDrawingHorizontalLine: (value) => FlLine(
            color: gridColor,
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: const FlTitlesData(show: false),
        lineTouchData: LineTouchData(
          enabled: true,
          handleBuiltInTouches: false,
          longPressDuration: const Duration(milliseconds: 150),
          touchSpotThreshold: 48,
          touchCallback: (event, response) {
            final spotIndex = response?.lineBarSpots?.first.spotIndex;
            onTouchSpot(event, spotIndex);
          },
        ),
        lineBarsData: [glowBar, mainBar],
      ),
    );
  }
}

class _NetWorthHoverCard extends StatelessWidget {
  final NetWorthHistoryPoint point;
  final Alignment alignment;
  final bool isDark;

  const _NetWorthHoverCard({
    required this.point,
    required this.alignment,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final netWorthColor = point.netWorth >= 0
        ? AppColors.getIncome(isDark)
        : AppColors.getDanger(isDark);

    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 200),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.getChipSurface(isDark),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.getCardBorder(isDark)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.12),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _formatNetWorthHistoryTooltipTitle(point),
                style: AppTypography.rowSubtitle.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.getTextSecondaryColor(isDark),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _formatCurrency(point.netWorth),
                style: AppTypography.amount.copyWith(color: netWorthColor),
              ),
              const SizedBox(height: 6),
              _hoverRow(
                  'Assets', point.assets, AppColors.getIncome(isDark), isDark),
              const SizedBox(height: 2),
              _hoverRow('Liabilities', point.liabilities,
                  AppColors.getDanger(isDark), isDark),
              if (point.granularity == NetWorthHistoryGranularity.month) ...[
                const SizedBox(height: 6),
                Text(
                  'Monthly snapshot',
                  style: AppTypography.monoLabel.copyWith(
                    fontSize: 9,
                    color: AppColors.getTextTertiaryColor(isDark),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _hoverRow(String label, double value, Color dot, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          '$label  ${_formatCurrency(value)}',
          style: AppTypography.rowSubtitle.copyWith(
            fontSize: 11,
            color: AppColors.getTextSecondaryColor(isDark),
          ),
        ),
      ],
    );
  }
}

String _formatNetWorthHistoryTooltipTitle(NetWorthHistoryPoint point) {
  if (point.granularity == NetWorthHistoryGranularity.month) {
    return DateFormat('MMMM y').format(point.date);
  }
  return DateFormat('MMM d, y').format(point.date);
}

_NetWorthChartScale _netWorthChartScale(List<NetWorthHistoryPoint> chartData) {
  final values = chartData.map((item) => item.netWorth).toList();
  final minValue = values.reduce(min);
  final maxValue = values.reduce(max);
  final rawRange = maxValue - minValue;
  final range = max(rawRange, max(1.0, maxValue.abs() * 0.10));
  return _NetWorthChartScale(
    paddedMin: minValue - (range * 0.18),
    paddedMax: maxValue + (range * 0.18),
  );
}

// ---------- Assets vs Liabilities card ----------

class _AssetsLiabilitiesCard extends StatelessWidget {
  final double assets;
  final double liabilities;
  final bool isDark;

  const _AssetsLiabilitiesCard({
    required this.assets,
    required this.liabilities,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final total = assets + liabilities;
    final assetsFraction = total > 0 ? assets / total : 1.0;
    final green = AppColors.getIncome(isDark);
    final rose = AppColors.getDanger(isDark);

    return GlowCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SplitGlowBar(assetsFraction: assetsFraction),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _legend(
                  label: 'Assets',
                  amount: assets,
                  dotColor: green,
                  alignEnd: false,
                ),
              ),
              Expanded(
                child: _legend(
                  label: 'Liabilities',
                  amount: liabilities,
                  dotColor: rose,
                  alignEnd: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legend({
    required String label,
    required double amount,
    required Color dotColor,
    required bool alignEnd,
  }) {
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
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

    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        row,
        const SizedBox(height: 4),
        Text(
          _formatCurrencyNoDecimals(amount),
          style: AppTypography.rowTitle.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            color: AppColors.getTextColor(isDark),
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
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
    return Row(
      children: [
        _ToggleChip(
          label: 'Assets',
          isSelected: selectedTab == 0,
          onTap: () => onTabChanged(0),
        ),
        const SizedBox(width: 8),
        _ToggleChip(
          label: 'Liabilities',
          isSelected: selectedTab == 1,
          onTap: () => onTabChanged(1),
        ),
      ],
    );
  }
}

/// Toggle chip: selected = filled accent pill with glow; unselected = surface
/// pill with white/8% border.
class _ToggleChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ToggleChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = AppColors.getAccent(isDark);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (!isSelected) {
          MicroInteractions.selectionClick();
          onTap();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? accent : AppColors.getChipSurface(isDark),
          borderRadius: BorderRadius.circular(999),
          border: isSelected
              ? null
              : Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.08),
                ),
          boxShadow: isSelected
              ? AppColors.glow(accent,
                  blurRadius: 20, alpha: 0.5, isDark: isDark)
              : null,
        ),
        child: Text(
          label,
          style: AppTypography.rowTitle.copyWith(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected
                ? AppColors.getOnAccent(isDark)
                : AppColors.getTextSecondaryColor(isDark),
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
  final void Function(NetWorthEntry) onViewHistory;
  final void Function(NetWorthEntry) onDeleteEntry;

  const _AccountsList({
    required this.selectedTab,
    required this.assetEntries,
    required this.liabilityEntries,
    required this.totalAssets,
    required this.totalLiabilities,
    required this.month,
    required this.onEditEntry,
    required this.onViewHistory,
    required this.onDeleteEntry,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAssets = selectedTab == 0;
    final entries = isAssets ? assetEntries : liabilityEntries;
    final total = isAssets ? totalAssets : totalLiabilities;

    if (entries.isEmpty) {
      return GlowCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(
            'No ${isAssets ? 'assets' : 'liabilities'} tracked for '
            '${formatNetWorthMonth(month)}.',
            textAlign: TextAlign.center,
            style: AppTypography.rowSubtitle.copyWith(
              fontSize: 13,
              color: AppColors.getTextSecondaryColor(isDark),
            ),
          ),
        ),
      );
    }

    return GlowListCard(
      children: [
        for (final entry in entries)
          _AccountRow(
            entry: entry,
            month: month,
            totalForCategory: total,
            isAssetsTab: isAssets,
            onViewHistory: () => onViewHistory(entry),
            onEdit: () => onEditEntry(entry),
            onDelete: () => onDeleteEntry(entry),
          ),
      ],
    );
  }
}

// ---------- Account Row ----------

class _AccountRow extends StatelessWidget {
  final NetWorthEntry entry;
  final DateTime month;
  final double totalForCategory;
  final bool isAssetsTab;
  final VoidCallback onViewHistory;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AccountRow({
    required this.entry,
    required this.month,
    required this.totalForCategory,
    required this.isAssetsTab,
    required this.onViewHistory,
    required this.onEdit,
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
    final previousSnapshot = _previousSnapshotBefore(
      entry.snapshots,
      effectiveSnapshot?.recordedAt,
    );
    final percentChange = previousSnapshot == null ||
            previousSnapshot.amount.abs() < 0.001
        ? null
        : ((amount - previousSnapshot.amount) / previousSnapshot.amount.abs()) *
            100;

    final isAsset = entry.type == NetWorthEntryType.asset;
    // Green tint for assets, danger tint when viewing liabilities (design).
    final tileColor =
        isAsset ? AppColors.getIncome(isDark) : AppColors.getDanger(isDark);
    final changeColor = percentChange == null
        ? AppColors.getTextTertiaryColor(isDark)
        : (isAsset ? percentChange >= 0 : percentChange <= 0)
            ? AppColors.getIncome(isDark)
            : AppColors.getDanger(isDark);

    final shareLabel = '${(percentage * 100).toStringAsFixed(1)}% of '
        '${isAssetsTab ? 'assets' : 'liabilities'}';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        MicroInteractions.lightImpact();
        onEdit();
      },
      onLongPress: () {
        MicroInteractions.mediumImpact();
        _showRowSheet(context);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconTile(
                  icon: _iconForEntry(entry),
                  color: tileColor,
                  size: 44,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.rowTitle.copyWith(
                          color: AppColors.getTextColor(isDark),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        shareLabel,
                        style: AppTypography.rowSubtitle.copyWith(
                          color: AppColors.getTextSecondaryColor(isDark),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatCurrencyNoDecimals(amount),
                      style: AppTypography.amount.copyWith(
                        color: AppColors.getTextColor(isDark),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      percentChange == null
                          ? '—'
                          : '${percentChange >= 0 ? '+' : ''}'
                              '${percentChange.toStringAsFixed(1)}%',
                      style: AppTypography.badge.copyWith(color: changeColor),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Share-of-total bar: width = this account's slice of the
            // selected tab's assets/liabilities.
            GlowProgressBar(
              value: percentage,
              color: tileColor,
              height: 6,
            ),
          ],
        ),
      ),
    );
  }

  void _showRowSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: AppColors.getCard(isDark),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.getTextTertiaryColor(isDark),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 8),
            _sheetTile(
              ctx,
              icon: Symbols.edit_rounded,
              label: 'Edit Balance',
              color: AppColors.getTextColor(isDark),
              onTap: () {
                Navigator.pop(ctx);
                onEdit();
              },
            ),
            _sheetTile(
              ctx,
              icon: Symbols.bar_chart_rounded,
              label: 'View History',
              color: AppColors.getTextColor(isDark),
              onTap: () {
                Navigator.pop(ctx);
                onViewHistory();
              },
            ),
            _sheetTile(
              ctx,
              icon: Symbols.delete_rounded,
              label: 'Delete Account',
              color: AppColors.getDanger(isDark),
              onTap: () {
                Navigator.pop(ctx);
                onDelete();
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _sheetTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: color, weight: 500),
      title: Text(
        label,
        style: AppTypography.rowTitle.copyWith(color: color),
      ),
      onTap: onTap,
    );
  }

  IconData _iconForEntry(NetWorthEntry e) {
    final n = e.name.toLowerCase();
    if (e.type == NetWorthEntryType.asset) {
      if (n.contains('bank') || n.contains('checking')) {
        return Symbols.account_balance_rounded;
      }
      if (n.contains('saving')) {
        return Symbols.savings_rounded;
      }
      if (n.contains('invest') ||
          n.contains('stock') ||
          n.contains('portfolio') ||
          n.contains('broker') ||
          n.contains('etf') ||
          n.contains('401') ||
          n.contains('ira')) {
        return Symbols.trending_up_rounded;
      }
      if (n.contains('real estate') ||
          n.contains('house') ||
          n.contains('home') ||
          n.contains('property')) {
        return Symbols.home_rounded;
      }
      if (n.contains('wallet') || n.contains('cash')) {
        return Symbols.account_balance_wallet_rounded;
      }
      return Symbols.north_east_rounded;
    } else {
      if (n.contains('loan') ||
          n.contains('student') ||
          n.contains('auto') ||
          n.contains('personal')) {
        return Symbols.attach_money_rounded;
      }
      if (n.contains('credit') || n.contains('card')) {
        return Symbols.account_balance_wallet_rounded;
      }
      return Symbols.south_west_rounded;
    }
  }
}

NetWorthSnapshot? _previousSnapshotBefore(
  List<NetWorthSnapshot> snapshots,
  DateTime? recordedAt,
) {
  if (recordedAt == null) {
    return null;
  }

  NetWorthSnapshot? previous;
  for (final snapshot in snapshots) {
    if (!snapshot.recordedAt.isBefore(recordedAt)) {
      continue;
    }
    if (previous == null || snapshot.recordedAt.isAfter(previous.recordedAt)) {
      previous = snapshot;
    }
  }
  return previous;
}

// ---------- Account History Page ----------

class _AccountHistoryPage extends StatelessWidget {
  final NetWorthEntry entry;

  const _AccountHistoryPage({required this.entry});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final model = context.watch<TransactionModel>();
    final currentEntry = model.netWorthEntries.firstWhere(
      (item) => item.id == entry.id,
      orElse: () => entry,
    );
    final chartHistory = model.getNetWorthEntryHistory(currentEntry.id);
    final timelineHistory = chartHistory.reversed.toList();
    final isAsset = currentEntry.type == NetWorthEntryType.asset;
    final accentColor =
        isAsset ? AppColors.getIncome(isDark) : AppColors.getDanger(isDark);
    final latestSnapshot = chartHistory.isNotEmpty ? chartHistory.last : null;
    final previousSnapshot =
        chartHistory.length > 1 ? chartHistory[chartHistory.length - 2] : null;
    final latestAmount = latestSnapshot?.amount ?? 0.0;
    final changeFromPrevious =
        latestSnapshot != null && previousSnapshot != null
            ? latestSnapshot.amount - previousSnapshot.amount
            : null;
    final totalChange = chartHistory.length > 1
        ? chartHistory.last.amount - chartHistory.first.amount
        : null;
    final totalChangeIsPositive = totalChange == null
        ? null
        : isAsset
            ? totalChange >= 0
            : totalChange <= 0;
    final peakAmount = chartHistory.isEmpty
        ? null
        : chartHistory.map((point) => point.amount).reduce(max);
    final lowAmount = chartHistory.isEmpty
        ? null
        : chartHistory.map((point) => point.amount).reduce(min);

    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      appBar: AppBar(
        title: Text(
          currentEntry.name,
          style: AppTypography.cardTitle.copyWith(
            color: AppColors.getTextColor(isDark),
          ),
        ),
        backgroundColor: AppColors.getBackground(isDark),
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.getTextColor(isDark)),
        actions: [
          IconButton(
            icon: Icon(
              Symbols.edit_rounded,
              weight: 500,
              color: AppColors.getTextColor(isDark),
            ),
            onPressed: () => _showNetWorthEditor(
              context: context,
              transactionModel: model,
              month: model.selectedNetWorthMonth,
              existingEntry: currentEntry,
            ),
          ),
          IconButton(
            icon: Icon(
              Symbols.delete_rounded,
              weight: 500,
              color: AppColors.getDanger(isDark),
            ),
            onPressed: () async {
              await _confirmDeleteNetWorthEntry(
                context: context,
                transactionModel: model,
                entry: currentEntry,
              );
              if (!context.mounted) return;

              final stillExists =
                  model.netWorthEntries.any((item) => item.id == entry.id);
              if (!stillExists) {
                Navigator.of(context).pop();
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: PlatformUtils.platformScrollPhysics,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _AccountHistoryHeroCard(
              entry: currentEntry,
              color: accentColor,
              latestAmount: latestAmount,
              lastUpdated: latestSnapshot?.recordedAt,
              changeFromPrevious: changeFromPrevious,
              totalChange: totalChange,
              totalChangeIsPositive: totalChangeIsPositive,
              snapshotCount: chartHistory.length,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _AccountHistoryStatCard(
                    label: 'CURRENT',
                    value: _formatCompactCurrencyNoDecimals(latestAmount),
                    color: accentColor,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _AccountHistoryStatCard(
                    label: 'PEAK',
                    value: peakAmount == null
                        ? '—'
                        : _formatCompactCurrencyNoDecimals(peakAmount),
                    color: accentColor,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _AccountHistoryStatCard(
                    label: 'LOW',
                    value: lowAmount == null
                        ? '—'
                        : _formatCompactCurrencyNoDecimals(lowAmount),
                    color: AppColors.getTextColor(isDark),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _AccountHistoryChart(
              entryName: currentEntry.name,
              history: chartHistory,
              color: accentColor,
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Timeline',
                      style: AppTypography.sectionHeader.copyWith(
                        color: AppColors.getTextColor(isDark),
                      ),
                    ),
                  ),
                  Text(
                    '${chartHistory.length} '
                    '${chartHistory.length == 1 ? 'entry' : 'entries'}',
                    style: AppTypography.rowSubtitle.copyWith(
                      color: AppColors.getTextSecondaryColor(isDark),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (timelineHistory.isEmpty)
              GlowCard(
                child: Text(
                  'Add updates to this account to build a balance timeline.',
                  style: AppTypography.rowSubtitle.copyWith(
                    fontSize: 13,
                    color: AppColors.getTextSecondaryColor(isDark),
                  ),
                ),
              )
            else
              GlowListCard(
                children: [
                  for (var index = 0; index < timelineHistory.length; index++)
                    _AccountHistoryTimelineRow(
                      snapshot: timelineHistory[index],
                      delta: index < timelineHistory.length - 1
                          ? timelineHistory[index].amount -
                              timelineHistory[index + 1].amount
                          : null,
                      color: accentColor,
                      isAsset: isAsset,
                      canDelete: chartHistory.length > 1,
                      onDelete: () => _confirmDeleteNetWorthSnapshot(
                        context: context,
                        transactionModel: model,
                        entry: currentEntry,
                        snapshot: timelineHistory[index],
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _AccountHistoryHeroCard extends StatelessWidget {
  final NetWorthEntry entry;
  final Color color;
  final double latestAmount;
  final DateTime? lastUpdated;
  final double? changeFromPrevious;
  final double? totalChange;
  final bool? totalChangeIsPositive;
  final int snapshotCount;

  const _AccountHistoryHeroCard({
    required this.entry,
    required this.color,
    required this.latestAmount,
    required this.lastUpdated,
    required this.changeFromPrevious,
    required this.totalChange,
    required this.totalChangeIsPositive,
    required this.snapshotCount,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAsset = entry.type == NetWorthEntryType.asset;

    return GlowCard(
      padding: const EdgeInsets.all(24),
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: 0.16),
          color.withValues(alpha: 0.06),
          AppColors.getCard(isDark),
        ],
        stops: const [0, 0.4, 1],
      ),
      border: Border.all(color: color.withValues(alpha: 0.18)),
      boxShadow:
          AppColors.glow(color, blurRadius: 24, alpha: 0.16, isDark: isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconTile(
                icon: isAsset
                    ? Symbols.north_east_rounded
                    : Symbols.south_west_rounded,
                color: color,
                size: 48,
                iconSize: 24,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Balance history',
                      style: AppTypography.cardTitle.copyWith(
                        color: AppColors.getTextColor(isDark),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      lastUpdated == null
                          ? 'No recorded updates yet'
                          : 'Last update '
                              '${DateFormat.yMMMd().format(lastUpdated!)}',
                      style: AppTypography.rowSubtitle.copyWith(
                        color: AppColors.getTextSecondaryColor(isDark),
                      ),
                    ),
                  ],
                ),
              ),
              PillChip(
                label: isAsset ? 'Asset' : 'Liability',
                color: color,
                textStyle: AppTypography.badgeSmall,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'CURRENT BALANCE',
            style: AppTypography.eyebrow.copyWith(
              color: AppColors.getTextSecondaryColor(isDark),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                _formatCurrency(latestAmount),
                style: AppTypography.heroSmall.copyWith(
                  color: AppColors.getTextColor(isDark),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _metaChip(
                context,
                icon: Symbols.calendar_month_rounded,
                label: '$snapshotCount '
                    '${snapshotCount == 1 ? 'snapshot' : 'snapshots'}',
                color: AppColors.getTextColor(isDark),
                background: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.05),
              ),
              if (changeFromPrevious != null)
                _metaChip(
                  context,
                  icon: changeFromPrevious! >= 0
                      ? Symbols.north_east_rounded
                      : Symbols.south_west_rounded,
                  label: '${changeFromPrevious! >= 0 ? '+' : ''}'
                      '${_formatCompactCurrencyNoDecimals(changeFromPrevious!)}'
                      ' vs prior',
                  color: changeFromPrevious! >= 0
                      ? AppColors.getIncome(isDark)
                      : AppColors.getDanger(isDark),
                  background: (changeFromPrevious! >= 0
                          ? AppColors.getIncome(isDark)
                          : AppColors.getDanger(isDark))
                      .withValues(alpha: 0.14),
                ),
              if (totalChange != null)
                _metaChip(
                  context,
                  icon: totalChangeIsPositive == true
                      ? Symbols.north_east_rounded
                      : Symbols.south_west_rounded,
                  label: '${totalChange! >= 0 ? '+' : ''}'
                      '${_formatCompactCurrencyNoDecimals(totalChange!)}'
                      ' overall',
                  color: totalChangeIsPositive == true
                      ? AppColors.getIncome(isDark)
                      : AppColors.getDanger(isDark),
                  background: (totalChangeIsPositive == true
                          ? AppColors.getIncome(isDark)
                          : AppColors.getDanger(isDark))
                      .withValues(alpha: 0.14),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metaChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required Color background,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, weight: 500, color: color),
          const SizedBox(width: 6),
          Text(label, style: AppTypography.badgeSmall.copyWith(color: color)),
        ],
      ),
    );
  }
}

class _AccountHistoryStatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _AccountHistoryStatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GlowCard(
      radius: 22,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppTypography.monoMetricLabel.copyWith(
              color: AppColors.getTextSecondaryColor(isDark),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTypography.amount.copyWith(fontSize: 17, color: color),
          ),
        ],
      ),
    );
  }
}

class _AccountHistoryTimelineRow extends StatelessWidget {
  final NetWorthSnapshot snapshot;
  final double? delta;
  final Color color;
  final bool isAsset;
  final bool canDelete;
  final VoidCallback onDelete;

  const _AccountHistoryTimelineRow({
    required this.snapshot,
    required this.delta,
    required this.color,
    required this.isAsset,
    required this.canDelete,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final deltaColor = delta == null
        ? AppColors.getTextSecondaryColor(isDark)
        : (isAsset ? delta! >= 0 : delta! <= 0)
            ? AppColors.getIncome(isDark)
            : AppColors.getDanger(isDark);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: AppColors.glow(color,
                  blurRadius: 10, alpha: 0.35, isDark: isDark),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat.yMMMd().format(snapshot.recordedAt),
                  style: AppTypography.rowTitle.copyWith(
                    color: AppColors.getTextColor(isDark),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat.jm().format(snapshot.recordedAt),
                  style: AppTypography.rowSubtitle.copyWith(
                    color: AppColors.getTextSecondaryColor(isDark),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatCurrency(snapshot.amount),
                style: AppTypography.amount.copyWith(
                  color: AppColors.getTextColor(isDark),
                ),
              ),
              if (delta != null) ...[
                const SizedBox(height: 2),
                Text(
                  '${delta! >= 0 ? '+' : ''}'
                  '${_formatCompactCurrencyNoDecimals(delta!)}',
                  style: AppTypography.badge.copyWith(color: deltaColor),
                ),
              ],
            ],
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: canDelete
                ? 'Delete this balance update'
                : 'Keep at least one balance update',
            icon: Icon(
              Symbols.delete_rounded,
              size: 18,
              weight: 500,
              color: canDelete
                  ? AppColors.getDanger(isDark)
                  : AppColors.getTextTertiaryColor(isDark),
            ),
            onPressed: canDelete ? onDelete : null,
          ),
        ],
      ),
    );
  }
}

class _AccountHistoryChart extends StatelessWidget {
  final String entryName;
  final List<NetWorthSnapshot> history;
  final Color color;

  const _AccountHistoryChart({
    required this.entryName,
    required this.history,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (history.isEmpty) {
      return GlowCard(
        padding: const EdgeInsets.all(24),
        child: SizedBox(
          height: 200,
          child: Center(
            child: Text(
              'No chart data yet for $entryName.',
              style: AppTypography.rowSubtitle.copyWith(
                fontSize: 13,
                color: AppColors.getTextSecondaryColor(isDark),
              ),
            ),
          ),
        ),
      );
    }

    final values = history.map((point) => point.amount).toList();
    final minValue = values.reduce(min);
    final maxValue = values.reduce(max);
    final rawRange = maxValue - minValue;
    final baselineRange = max(1.0, max(maxValue.abs(), minValue.abs()) * 0.08);
    final range = max(rawRange, baselineRange);
    final paddedMin = minValue - (range * 0.20);
    final paddedMax = maxValue + (range * 0.20);

    final spots = history.length == 1
        ? [
            FlSpot(0, history.first.amount),
            FlSpot(1, history.first.amount),
          ]
        : List.generate(
            history.length,
            (index) => FlSpot(index.toDouble(), history[index].amount),
          );
    final lastIndex = spots.length - 1;

    final glowBar = LineChartBarData(
      spots: spots,
      isCurved: history.length > 2,
      curveSmoothness: 0.28,
      color: color.withValues(alpha: 0.35),
      barWidth: 9,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
    );

    final mainBar = LineChartBarData(
      spots: spots,
      isCurved: history.length > 2,
      curveSmoothness: 0.28,
      color: color,
      barWidth: 3,
      isStrokeCapRound: true,
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.35),
            color.withValues(alpha: 0.0),
          ],
        ),
      ),
      dotData: FlDotData(
        show: true,
        checkToShowDot: (spot, _) => spot.x.round() == lastIndex,
        getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
          radius: 5,
          color: const Color(0xFFF2F2FA),
          strokeWidth: 3,
          strokeColor: color.withValues(alpha: 0.5),
        ),
      ),
    );

    return GlowCard(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
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
                      'Trend',
                      style: AppTypography.cardTitle.copyWith(
                        color: AppColors.getTextColor(isDark),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      history.length == 1
                          ? 'Showing the first recorded balance.'
                          : '${DateFormat.MMMd().format(history.first.recordedAt)}'
                              ' to '
                              '${DateFormat.MMMd().format(history.last.recordedAt)}',
                      style: AppTypography.rowSubtitle.copyWith(
                        color: AppColors.getTextSecondaryColor(isDark),
                      ),
                    ),
                  ],
                ),
              ),
              PillChip(
                label: _formatCompactCurrencyNoDecimals(history.last.amount),
                color: color,
                textStyle: AppTypography.badgeSmall,
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: max(1, history.length - 1).toDouble(),
                minY: paddedMin,
                maxY: paddedMax,
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: (paddedMax - paddedMin) / 4,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: AppColors.getHairline(isDark),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      interval: max(1, (history.length / 3).floor()).toDouble(),
                      getTitlesWidget: (value, meta) {
                        final i = value.round();
                        if (i < 0 || i >= history.length) {
                          return const SizedBox.shrink();
                        }
                        if (history.length > 3 &&
                            i != 0 &&
                            i != history.length - 1 &&
                            i != (history.length / 2).round()) {
                          return const SizedBox.shrink();
                        }
                        return SideTitleWidget(
                          meta: meta,
                          space: 8,
                          child: Text(
                            DateFormat.MMMd()
                                .format(history[i].recordedAt)
                                .toUpperCase(),
                            style: AppTypography.monoAxis.copyWith(
                              color: AppColors.getTextTertiaryColor(isDark),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  enabled: true,
                  handleBuiltInTouches: true,
                  touchSpotThreshold: 48,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => AppColors.getChipSurface(isDark),
                    getTooltipItems: (spots) {
                      return spots.map((spot) {
                        // Single-snapshot accounts duplicate the point at
                        // x=1 to draw a flat line — clamp before indexing.
                        final point = history[
                            spot.x.round().clamp(0, history.length - 1)];
                        return LineTooltipItem(
                          '${DateFormat.yMMMd().format(point.recordedAt)}\n',
                          AppTypography.rowSubtitle.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.getTextSecondaryColor(isDark),
                          ),
                          children: [
                            TextSpan(
                              text: _formatCurrency(point.amount),
                              style: AppTypography.amount.copyWith(
                                color: AppColors.getTextColor(isDark),
                              ),
                            ),
                          ],
                        );
                      }).toList();
                    },
                  ),
                ),
                lineBarsData: [glowBar, mainBar],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- Editor Dialog ----------

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

/// Formats a number with commas in the integer part, preserving a decimal
/// portion.
class _CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;

    final stripped = text.replaceAll(',', '');
    if (!RegExp(r'^\d*\.?\d{0,2}$').hasMatch(stripped)) {
      return oldValue;
    }

    final dotIndex = stripped.indexOf('.');
    final intPart = dotIndex == -1 ? stripped : stripped.substring(0, dotIndex);
    final decPart = dotIndex == -1 ? null : stripped.substring(dotIndex + 1);

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
  late DateTime _entryMonth;
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
    _entryMonth = DateTime(widget.month.year, widget.month.month);
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

  Color _accentColor(bool isDark) =>
      _isAsset ? AppColors.getIncome(isDark) : AppColors.getDanger(isDark);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final existingEntry = widget.existingEntry;
    final accent = _accentColor(isDark);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.getCard(isDark),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: AppColors.getCardBorder(isDark)),
          boxShadow: [
            ...AppColors.glow(accent,
                blurRadius: 32, alpha: 0.18, isDark: isDark),
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header banner.
              AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeInOut,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      accent.withValues(alpha: 0.22),
                      accent.withValues(alpha: 0.10),
                    ],
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Row(
                  children: [
                    IconTile(
                      icon: _isAsset
                          ? Symbols.north_east_rounded
                          : Symbols.south_west_rounded,
                      color: accent,
                      size: 48,
                      iconSize: 24,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            existingEntry == null
                                ? 'Add account'
                                : 'Edit account',
                            style: AppTypography.cardTitle.copyWith(
                              color: AppColors.getTextColor(isDark),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            formatNetWorthMonth(_entryMonth),
                            style: AppTypography.rowSubtitle.copyWith(
                              color: AppColors.getTextSecondaryColor(isDark),
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () =>
                          Navigator.of(context, rootNavigator: true).pop(),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.06),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Symbols.close_rounded,
                          weight: 500,
                          color: AppColors.getTextColor(isDark),
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Form body.
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TypeToggle(
                      selectedType: _selectedType,
                      onChanged: (type) => setState(() => _selectedType = type),
                    ),
                    const SizedBox(height: 16),
                    _MonthPickerField(
                      month: _entryMonth,
                      accentColor: accent,
                      isDark: isDark,
                      onTap: _pickEntryMonth,
                    ),
                    const SizedBox(height: 16),
                    _EditorField(
                      label: 'Account name',
                      controller: _nameController,
                      focusNode: _nameFocus,
                      isFocused: _nameFocused,
                      errorText: _nameError,
                      accentColor: accent,
                      prefixIcon: Symbols.account_balance_wallet_rounded,
                      keyboardType: TextInputType.text,
                      textCapitalization: TextCapitalization.words,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 16),
                    _EditorField(
                      label: _isAsset ? 'Asset balance' : 'Liability balance',
                      controller: _amountController,
                      focusNode: _amountFocus,
                      isFocused: _amountFocused,
                      errorText: _amountError,
                      accentColor: accent,
                      prefixIcon: Symbols.attach_money_rounded,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [_CurrencyInputFormatter()],
                      isDark: isDark,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: _DialogButton(
                            label: 'Cancel',
                            filled: false,
                            color: AppColors.getTextColor(isDark),
                            onPressed: () =>
                                Navigator.of(context, rootNavigator: true)
                                    .pop(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _DialogButton(
                            label: existingEntry == null ? 'Add' : 'Save',
                            filled: true,
                            color: accent,
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
        month: _entryMonth,
      );
    } else {
      await widget.transactionModel.updateNetWorthEntry(
        id: widget.existingEntry!.id,
        name: _nameController.text.trim(),
        type: _selectedType,
        amount: parsedAmount,
        month: _entryMonth,
      );
    }

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
  }

  Future<void> _pickEntryMonth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _entryMonth,
      firstDate: DateTime(1970),
      lastDate: DateTime(now.year, now.month + 1, 0),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      helpText: 'Select balance month',
    );

    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      _entryMonth = DateTime(picked.year, picked.month);
      if (widget.existingEntry != null) {
        final amount = widget.existingEntry!.amountForMonth(_entryMonth);
        _amountController.text =
            amount == null ? '' : NumberFormat('#,##0.##').format(amount);
      }
    });
  }
}

/// Filled accent / outlined pill button for the editor actions.
class _DialogButton extends StatelessWidget {
  final String label;
  final bool filled;
  final Color color;
  final VoidCallback onPressed;

  const _DialogButton({
    required this.label,
    required this.filled,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        MicroInteractions.lightImpact();
        onPressed();
      },
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled
              ? color
              : (isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.05)),
          borderRadius: BorderRadius.circular(999),
          border: filled
              ? null
              : Border.all(color: AppColors.getCardBorder(isDark)),
          boxShadow: filled
              ? AppColors.glow(color,
                  blurRadius: 20, alpha: 0.45, isDark: isDark)
              : null,
        ),
        child: Text(
          label,
          style: AppTypography.rowTitle.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: filled
                ? AppColors.getOnAccent(isDark)
                : AppColors.getTextColor(isDark),
          ),
        ),
      ),
    );
  }
}

class _MonthPickerField extends StatelessWidget {
  final DateTime month;
  final Color accentColor;
  final bool isDark;
  final VoidCallback onTap;

  const _MonthPickerField({
    required this.month,
    required this.accentColor,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            'Balance month',
            style: AppTypography.rowSubtitle.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.getTextSecondaryColor(isDark),
            ),
          ),
        ),
        GestureDetector(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.getChipSurface(isDark),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.getCardBorder(isDark)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Icon(
                  Symbols.calendar_month_rounded,
                  size: 20,
                  weight: 500,
                  color: accentColor,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    formatNetWorthMonth(month),
                    style: AppTypography.rowTitle.copyWith(
                      color: AppColors.getTextColor(isDark),
                    ),
                  ),
                ),
                Icon(
                  Symbols.expand_more_rounded,
                  size: 18,
                  weight: 500,
                  color: AppColors.getTextTertiaryColor(isDark),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

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
    final danger = AppColors.getDanger(isDark);
    final borderColor = hasError
        ? danger
        : isFocused
            ? accentColor
            : AppColors.getCardBorder(isDark);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            label,
            style: AppTypography.rowSubtitle.copyWith(
              fontWeight: FontWeight.w600,
              color: hasError
                  ? danger
                  : isFocused
                      ? accentColor
                      : AppColors.getTextSecondaryColor(isDark),
            ),
          ),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: AppColors.getChipSurface(isDark),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: borderColor,
              width: isFocused ? 2 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Row(
              children: [
                Icon(
                  prefixIcon,
                  size: 20,
                  weight: 500,
                  color: hasError
                      ? danger
                      : isFocused
                          ? accentColor
                          : AppColors.getTextTertiaryColor(isDark),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    keyboardType: keyboardType,
                    textCapitalization: textCapitalization,
                    inputFormatters: inputFormatters,
                    style: AppTypography.rowTitle.copyWith(
                      color: AppColors.getTextColor(isDark),
                    ),
                    cursorColor: accentColor,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                Symbols.error_rounded,
                size: 16,
                weight: 500,
                color: danger,
              ),
              const SizedBox(width: 4),
              Text(
                errorText!,
                style: AppTypography.rowSubtitle.copyWith(color: danger),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Two-pill toggle for asset / liability selection in the editor.
class _TypeToggle extends StatelessWidget {
  final NetWorthEntryType selectedType;
  final ValueChanged<NetWorthEntryType> onChanged;

  const _TypeToggle({
    required this.selectedType,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        _TypePill(
          label: 'Asset',
          icon: Symbols.north_east_rounded,
          isSelected: selectedType == NetWorthEntryType.asset,
          color: AppColors.getIncome(isDark),
          onTap: () => onChanged(NetWorthEntryType.asset),
        ),
        const SizedBox(width: 8),
        _TypePill(
          label: 'Liability',
          icon: Symbols.south_west_rounded,
          isSelected: selectedType == NetWorthEntryType.liability,
          color: AppColors.getDanger(isDark),
          onTap: () => onChanged(NetWorthEntryType.liability),
        ),
      ],
    );
  }
}

class _TypePill extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _TypePill({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          MicroInteractions.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          height: 48,
          decoration: BoxDecoration(
            color: isSelected ? color : AppColors.getChipSurface(isDark),
            borderRadius: BorderRadius.circular(14),
            border: isSelected
                ? null
                : Border.all(color: AppColors.getCardBorder(isDark)),
            boxShadow: isSelected
                ? AppColors.glow(color,
                    blurRadius: 16, alpha: 0.4, isDark: isDark)
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                weight: 500,
                color: isSelected
                    ? AppColors.getOnAccent(isDark)
                    : AppColors.getTextSecondaryColor(isDark),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTypography.rowTitle.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isSelected
                      ? AppColors.getOnAccent(isDark)
                      : AppColors.getTextSecondaryColor(isDark),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------- Delete confirmations ----------

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

Future<void> _confirmDeleteNetWorthSnapshot({
  required BuildContext context,
  required TransactionModel transactionModel,
  required NetWorthEntry entry,
  required NetWorthSnapshot snapshot,
}) async {
  final shouldDelete = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Delete balance update?'),
        content: Text(
          'Remove the ${DateFormat.yMMMd().add_jm().format(snapshot.recordedAt)} '
          'balance for ${entry.name}? This only removes this one data point.',
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
    await transactionModel.deleteNetWorthSnapshot(
      entryId: entry.id,
      recordedAt: snapshot.recordedAt,
    );
  }
}

// ---------- Formatting helpers ----------

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

String _formatCurrencyNoDecimals(double value) {
  final formatter = NumberFormat.currency(
    locale: 'en_US',
    symbol: '\$',
    decimalDigits: 0,
  );
  return value < 0
      ? '-${formatter.format(value.abs())}'
      : formatter.format(value);
}

String _formatCompactCurrencyNoDecimals(double value) {
  final absValue = value.abs();
  final sign = value < 0 ? '-' : '';
  if (absValue >= 1000000) {
    final digits = absValue >= 10000000 ? 0 : 1;
    return '$sign\$${(absValue / 1000000).toStringAsFixed(digits)}M';
  }
  if (absValue >= 1000) {
    final digits = absValue >= 100000 ? 0 : 1;
    return '$sign\$${(absValue / 1000).toStringAsFixed(digits)}k';
  }
  return '$sign\$${absValue.toStringAsFixed(0)}';
}
