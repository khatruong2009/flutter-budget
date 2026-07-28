import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../design_system.dart';
import '../insights/insight_engine.dart';
import '../transaction_model.dart';

class LocalInsightsSection extends StatefulWidget {
  final TransactionModel model;

  const LocalInsightsSection({super.key, required this.model});

  @override
  State<LocalInsightsSection> createState() => _LocalInsightsSectionState();
}

class _LocalInsightsSectionState extends State<LocalInsightsSection> {
  static const _dismissedKey = 'local_insights_dismissed_v1';
  static const _snoozedKey = 'local_insights_snoozed_v1';
  static const _snoozeDuration = Duration(days: 30);

  final _engine = const InsightEngine();
  final Set<String> _dismissedIds = {};
  final Map<String, DateTime> _snoozedUntil = {};
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final dismissed = prefs.getStringList(_dismissedKey) ?? const [];
    final rawSnoozed = prefs.getString(_snoozedKey);
    final snoozed = <String, DateTime>{};
    if (rawSnoozed != null) {
      try {
        final decoded = jsonDecode(rawSnoozed) as Map<String, dynamic>;
        for (final entry in decoded.entries) {
          final date = DateTime.tryParse(entry.value as String);
          if (date != null) snoozed[entry.key] = date;
        }
      } on FormatException {
        // Ignore only this optional UI preference if it becomes malformed.
      } on TypeError {
        // Older or invalid values should not prevent the dashboard loading.
      }
    }
    if (!mounted) return;
    setState(() {
      _dismissedIds
        ..clear()
        ..addAll(dismissed);
      _snoozedUntil
        ..clear()
        ..addAll(snoozed);
      _loaded = true;
    });
  }

  Set<String> _excluded(DateTime now) {
    final excluded = <String>{..._dismissedIds};
    for (final entry in _snoozedUntil.entries) {
      if (entry.value.isAfter(now)) excluded.add(entry.key);
    }
    return excluded;
  }

  Future<void> _dismiss(LocalInsight insight) async {
    setState(() => _dismissedIds.add(insight.id));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_dismissedKey, _dismissedIds.toList()..sort());
  }

  Future<void> _snooze(LocalInsight insight) async {
    setState(() {
      _snoozedUntil[insight.id] = DateTime.now().add(_snoozeDuration);
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _snoozedKey,
      jsonEncode(
        _snoozedUntil.map(
          (id, until) => MapEntry(id, until.toIso8601String()),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();

    final now = DateTime.now();
    final insights = _engine.generate(
      transactions: widget.model.transactions,
      categoryBudgetLimits: widget.model.categoryBudgetLimits,
      savingsGoals: widget.model.savingsGoals,
      selectedMonth: widget.model.selectedMonth,
      now: now,
      excludedIds: _excluded(now),
    );
    if (insights.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: 'Insights'),
        const SizedBox(height: 12),
        for (var index = 0; index < insights.length; index++) ...[
          _InsightCard(
            insight: insights[index],
            onDismiss: () => _dismiss(insights[index]),
            onSnooze: () => _snooze(insights[index]),
          ),
          if (index != insights.length - 1) const SizedBox(height: 10),
        ],
        const SizedBox(height: 8),
        Text(
          'Calculated privately on this device · Not financial advice',
          style: AppTypography.caption.copyWith(
            color: AppDesign.getTextTertiary(context),
          ),
        ),
      ],
    );
  }
}

class _InsightCard extends StatelessWidget {
  final LocalInsight insight;
  final VoidCallback onDismiss;
  final VoidCallback onSnooze;

  const _InsightCard({
    required this.insight,
    required this.onDismiss,
    required this.onSnooze,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = switch (insight.severity) {
      InsightSeverity.urgent => AppColors.getDanger(isDark),
      InsightSeverity.warning => AppColors.getWarning(isDark),
      InsightSeverity.positive => AppColors.getIncome(isDark),
      InsightSeverity.info => AppColors.getAccent(isDark),
    };

    return GlowCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconTile(
            icon: _iconFor(insight.type),
            color: color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insight.headline,
                  style: AppTypography.rowTitle.copyWith(
                    color: AppColors.getTextColor(isDark),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  insight.explanation,
                  style: AppTypography.rowSubtitle.copyWith(
                    color: AppColors.getTextSecondaryColor(isDark),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  insight.suggestedAction,
                  style: AppTypography.caption.copyWith(color: color),
                ),
              ],
            ),
          ),
          PopupMenuButton<_InsightMenuAction>(
            tooltip: 'Insight options',
            icon: Icon(
              Symbols.more_horiz_rounded,
              color: AppColors.getTextSecondaryColor(isDark),
            ),
            onSelected: (action) {
              switch (action) {
                case _InsightMenuAction.snooze:
                  onSnooze();
                  return;
                case _InsightMenuAction.dismiss:
                  onDismiss();
                  return;
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: _InsightMenuAction.snooze,
                child: Text('Snooze for 30 days'),
              ),
              PopupMenuItem(
                value: _InsightMenuAction.dismiss,
                child: Text('Dismiss'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _iconFor(InsightType type) => switch (type) {
        InsightType.budgetPace => Symbols.speed_rounded,
        InsightType.monthlySpendingChange => Symbols.trending_up_rounded,
        InsightType.unusualTransaction =>
          Symbols.notification_important_rounded,
        InsightType.savingsRateTrend => Symbols.savings_rounded,
        InsightType.recurringAmountChange => Symbols.repeat_rounded,
        InsightType.consistentlyUnderBudget => Symbols.thumb_up_rounded,
        InsightType.goalBehindSchedule => Symbols.flag_rounded,
        InsightType.negativeCashFlow => Symbols.trending_down_rounded,
        InsightType.possibleDuplicate => Symbols.content_copy_rounded,
      };
}

enum _InsightMenuAction { snooze, dismiss }
