import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'design_system.dart';
import 'savings_goal.dart';

typedef AddSavingsGoalCallback = Future<void> Function({
  required String name,
  required double targetAmount,
  required DateTime targetDate,
});

typedef UpdateSavingsGoalCallback = Future<void> Function(SavingsGoal goal);
typedef DeleteSavingsGoalCallback = Future<void> Function(String id);
typedef AllocateSavingsGoalCallback = Future<void> Function(
  String goalId,
  double amount,
);

/// Status a goal falls into for the redesigned card badge / pace copy.
enum _GoalStatus { onTrack, behind, complete }

class SavingsGoalsPage extends StatefulWidget {
  final Object? model;
  final List<SavingsGoal>? savingsGoals;
  final AddSavingsGoalCallback? onAddSavingsGoal;
  final UpdateSavingsGoalCallback? onUpdateSavingsGoal;
  final DeleteSavingsGoalCallback? onDeleteSavingsGoal;
  final AllocateSavingsGoalCallback? onAllocateToSavingsGoal;

  const SavingsGoalsPage({
    super.key,
    this.model,
    this.savingsGoals,
    this.onAddSavingsGoal,
    this.onUpdateSavingsGoal,
    this.onDeleteSavingsGoal,
    this.onAllocateToSavingsGoal,
  });

  @override
  State<SavingsGoalsPage> createState() => _SavingsGoalsPageState();
}

class _SavingsGoalsPageState extends State<SavingsGoalsPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _celebrationController;
  String? _celebrationGoalName;
  bool _isBusy = false;

  final NumberFormat _currency = NumberFormat.currency(
    locale: 'en_US',
    symbol: r'$',
    decimalDigits: 2,
  );

  /// Whole-dollar formatter for the compact amounts in the redesign
  /// (`$8,200 of $10,000`, `$15,520`).
  final NumberFormat _currencyWhole = NumberFormat.currency(
    locale: 'en_US',
    symbol: r'$',
    decimalDigits: 0,
  );
  final DateFormat _dateFormat = DateFormat.yMMMd();

  /// Compact date used in the pace/funded copy (e.g. `Nov 30`).
  final DateFormat _shortDate = DateFormat.MMMd();

  @override
  void initState() {
    super.initState();
    _celebrationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() {
            _celebrationGoalName = null;
          });
          _celebrationController.reset();
        }
      });
  }

  @override
  void dispose() {
    _celebrationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final goals = _sortedGoals(_goals);

    return BudgiePageScaffold(
      fab: GlowFab(
        onPressed: _isBusy ? _noop : () => _showGoalForm(context),
        icon: Symbols.add_rounded,
        semanticLabel: 'Add savings goal',
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                bottom: DockMetrics.contentBottomPadding(context),
              ),
              child: SafeArea(
                bottom: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const BudgieHeader(title: 'Goals'),
                    if (goals.isEmpty)
                      _buildEmptyState(context)
                    else
                      _buildGoalsContent(goals),
                  ],
                ),
              ),
            ),
          ),
          if (_celebrationGoalName != null)
            Positioned.fill(
              child: _CompletionCelebration(
                animation: _celebrationController,
                goalName: _celebrationGoalName!,
              ),
            ),
        ],
      ),
    );
  }

  void _noop() {}

  List<SavingsGoal> get _goals {
    if (widget.savingsGoals != null) {
      return List<SavingsGoal>.from(widget.savingsGoals!);
    }

    final model = widget.model;
    if (model == null) {
      return const [];
    }

    try {
      final rawGoals = (model as dynamic).savingsGoals;
      if (rawGoals is List<SavingsGoal>) {
        return List<SavingsGoal>.from(rawGoals);
      }
      if (rawGoals is Iterable) {
        return rawGoals.cast<SavingsGoal>().toList();
      }
    } catch (_) {
      return const [];
    }

    return const [];
  }

  List<SavingsGoal> _sortedGoals(List<SavingsGoal> goals) {
    return List<SavingsGoal>.from(goals)
      ..sort((a, b) {
        if (a.isCompleted != b.isCompleted) {
          return a.isCompleted ? 1 : -1;
        }
        return a.targetDate.compareTo(b.targetDate);
      });
  }

  Widget _buildEmptyState(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = AppColors.getAccent(isDark);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 48, 20, 0),
      child: GlowCard(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            IconTile(
              icon: Symbols.savings_rounded,
              color: accent,
              size: 56,
              iconSize: 28,
            ),
            const SizedBox(height: 20),
            Text(
              'No savings goals yet',
              style: AppTypography.sectionHeader.copyWith(
                color: AppColors.getTextColor(isDark),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Create a goal, set a target date, and track progress '
              'as you set money aside.',
              style: AppTypography.rowSubtitle.copyWith(
                fontSize: 13,
                color: AppColors.getTextSecondaryColor(isDark),
                height: 1.45,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            PillButton(
              label: 'Add goal',
              icon: Symbols.add_rounded,
              color: accent,
              filled: true,
              height: 44,
              onPressed: _isBusy ? _noop : () => _showGoalForm(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalsContent(List<SavingsGoal> goals) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
          child: _SavingsGoalsSummary(
            goals: goals,
            currency: _currencyWhole,
          ),
        ),
        for (final goal in goals)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: _SavingsGoalCard(
              goal: goal,
              status: _statusFor(goal),
              currency: _currencyWhole,
              shortDate: _shortDate,
              paceCopy: _paceCopyFor(goal),
              onAddMoney: goal.isCompleted
                  ? null
                  : () => _showAllocationForm(context, goal),
              onMore: () => _showGoalActions(context, goal),
            ),
          ),
      ],
    );
  }

  /// Pace/status for a goal, derived from the existing model logic
  /// (`isCompleted`, `isOverdue`, expected vs actual progress across the goal
  /// lifespan). A goal is "behind" when it is overdue, or when actual progress
  /// trails the time-elapsed pace toward the deadline.
  _GoalStatus _statusFor(SavingsGoal goal) {
    if (goal.isCompleted) {
      return _GoalStatus.complete;
    }
    if (goal.isOverdue) {
      return _GoalStatus.behind;
    }

    final now = DateTime.now();
    final start = goal.createdAt;
    final totalSpan = goal.targetDate.difference(start).inMilliseconds;
    if (totalSpan <= 0) {
      // Same-day (or inverted) deadline: only on track once fully funded.
      return goal.progress >= 1.0 ? _GoalStatus.onTrack : _GoalStatus.behind;
    }

    final elapsed = now.difference(start).inMilliseconds;
    final expected = (elapsed / totalSpan).clamp(0.0, 1.0);
    return goal.progress + 1e-9 >= expected
        ? _GoalStatus.onTrack
        : _GoalStatus.behind;
  }

  /// Sub-copy under the goal amount, e.g. `Nov 30 · $360/mo keeps you on pace`
  /// or `Mar 15 · bump to $435/mo to catch up`.
  String _paceCopyFor(SavingsGoal goal) {
    final date = _shortDate.format(goal.targetDate);
    final monthly = _currencyWhole.format(goal.suggestedMonthlyContribution);
    if (_statusFor(goal) == _GoalStatus.behind) {
      return '$date · bump to $monthly/mo to catch up';
    }
    return '$date · $monthly/mo keeps you on pace';
  }

  Future<void> _showGoalForm(
    BuildContext context, {
    SavingsGoal? goal,
  }) async {
    final result = await showDialog<_GoalFormResult>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return _GoalFormDialog(
          goal: goal,
          dateFormat: _dateFormat,
        );
      },
    );

    if (result == null || !context.mounted) {
      return;
    }

    await _runMutation(
      context,
      () async {
        if (goal == null) {
          await _addSavingsGoal(
            name: result.name,
            targetAmount: result.targetAmount,
            targetDate: result.targetDate,
          );
          return;
        }

        await _updateSavingsGoal(
          goal.copyWith(
            name: result.name,
            targetAmount: result.targetAmount,
            currentAmount: result.currentAmount,
            targetDate: result.targetDate,
            completedAt: result.currentAmount >= result.targetAmount
                ? goal.completedAt ?? DateTime.now()
                : null,
          ),
        );
      },
      successMessage:
          goal == null ? 'Savings goal added' : 'Savings goal updated',
    );
  }

  Future<void> _showAllocationForm(
    BuildContext context,
    SavingsGoal goal,
  ) async {
    final amount = await showDialog<double>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return _AllocationDialog(
          goal: goal,
          currency: _currency,
        );
      },
    );

    if (amount == null || amount <= 0 || !context.mounted) {
      return;
    }

    final willComplete = !goal.isCompleted && amount >= goal.remainingAmount;

    await _runMutation(
      context,
      () => _allocateToSavingsGoal(goal.id, amount),
      successMessage: 'Allocation added',
    );

    if (willComplete && mounted && context.mounted) {
      HapticFeedback.mediumImpact();
      // Under reduced motion, skip the confetti overlay entirely — the
      // haptic and success snackbar already confirm the completion.
      if (!MediaQuery.disableAnimationsOf(context)) {
        setState(() {
          _celebrationGoalName = goal.name;
        });
        _celebrationController.forward(from: 0);
      }
    }
  }

  /// Bottom sheet opened by the `⋯` circle: edit / delete the goal.
  Future<void> _showGoalActions(BuildContext context, SavingsGoal goal) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: GlowCard(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            goal.name,
                            style: AppTypography.goalTitle.copyWith(
                              color: AppColors.getTextColor(isDark),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _GoalActionTile(
                    icon: Symbols.edit_rounded,
                    label: 'Edit goal',
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      _showGoalForm(context, goal: goal);
                    },
                  ),
                  _GoalActionTile(
                    icon: Symbols.delete_rounded,
                    label: 'Delete goal',
                    color: AppColors.getDanger(isDark),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      _confirmDelete(context, goal);
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context, SavingsGoal goal) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return _DarkDialog(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Delete savings goal?',
                style: AppTypography.goalTitle.copyWith(
                  color: AppColors.getTextColor(isDark),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'This removes "${goal.name}" and its saved progress '
                'from your goals.',
                style: AppTypography.rowSubtitle.copyWith(
                  fontSize: 13,
                  color: AppColors.getTextSecondaryColor(isDark),
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: PillButton(
                      label: 'Cancel',
                      color: AppColors.getTextSecondaryColor(isDark),
                      height: 44,
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PillButton(
                      label: 'Delete',
                      color: AppColors.getDanger(isDark),
                      filled: true,
                      height: 44,
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    await _runMutation(
      context,
      () => _deleteSavingsGoal(goal.id),
      successMessage: 'Savings goal deleted',
    );
  }

  Future<void> _runMutation(
    BuildContext context,
    Future<void> Function() mutation, {
    required String successMessage,
  }) async {
    if (_isBusy) {
      return;
    }

    setState(() {
      _isBusy = true;
    });

    try {
      await mutation();
      if (mounted) {
        setState(() {});
      }
      if (context.mounted) {
        _showSnackBar(
          context,
          successMessage,
          AppColors.getSuccess(
            Theme.of(context).brightness == Brightness.dark,
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        _showSnackBar(
          context,
          'Savings goal action failed',
          AppColors.getDanger(
            Theme.of(context).brightness == Brightness.dark,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  Future<void> _addSavingsGoal({
    required String name,
    required double targetAmount,
    required DateTime targetDate,
  }) async {
    if (widget.onAddSavingsGoal != null) {
      await widget.onAddSavingsGoal!(
        name: name,
        targetAmount: targetAmount,
        targetDate: targetDate,
      );
      return;
    }

    await (widget.model as dynamic).addSavingsGoal(
      name: name,
      targetAmount: targetAmount,
      targetDate: targetDate,
    );
  }

  Future<void> _updateSavingsGoal(SavingsGoal goal) async {
    if (widget.onUpdateSavingsGoal != null) {
      await widget.onUpdateSavingsGoal!(goal);
      return;
    }

    await (widget.model as dynamic).updateSavingsGoal(goal);
  }

  Future<void> _deleteSavingsGoal(String id) async {
    if (widget.onDeleteSavingsGoal != null) {
      await widget.onDeleteSavingsGoal!(id);
      return;
    }

    await (widget.model as dynamic).deleteSavingsGoal(id);
  }

  Future<void> _allocateToSavingsGoal(String goalId, double amount) async {
    if (widget.onAllocateToSavingsGoal != null) {
      await widget.onAllocateToSavingsGoal!(goalId, amount);
      return;
    }

    await (widget.model as dynamic).allocateToSavingsGoal(goalId, amount);
  }

  void _showSnackBar(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDesign.radiusM),
        ),
      ),
    );
  }
}

/// Summary strip: 72px accent progress ring + saved-so-far aggregates.
class _SavingsGoalsSummary extends StatelessWidget {
  final List<SavingsGoal> goals;
  final NumberFormat currency;

  const _SavingsGoalsSummary({
    required this.goals,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = AppColors.getAccent(isDark);

    final totalSaved = goals.fold<double>(
      0,
      (sum, goal) => sum + goal.currentAmount,
    );
    final totalTarget = goals.fold<double>(
      0,
      (sum, goal) => sum + goal.targetAmount,
    );
    final completedCount = goals.where((goal) => goal.isCompleted).length;
    final totalProgress =
        (totalTarget <= 0 ? 0.0 : totalSaved / totalTarget).clamp(0.0, 1.0);
    final percentLabel = '${(totalProgress * 100).round()}%';

    return GlowCard(
      child: Row(
        children: [
          ProgressRing(
            value: totalProgress,
            size: 72,
            thickness: 8,
            color: accent,
            glowAlpha: 0.35,
            child: Text(
              percentLabel,
              style: AppTypography.badgeSmall.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.getTextColor(isDark),
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SAVED SO FAR',
                  style: AppTypography.eyebrowTight.copyWith(
                    color: AppColors.getTextSecondaryColor(isDark),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  currency.format(totalSaved),
                  style: AppTypography.heroSmall.copyWith(
                    fontSize: 28,
                    letterSpacing: -0.8,
                    color: AppColors.getTextColor(isDark),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'of ${currency.format(totalTarget)} · '
                  '$completedCount of ${goals.length} complete',
                  style: AppTypography.rowSubtitle.copyWith(
                    fontSize: 13,
                    color: AppColors.getTextSecondaryColor(isDark),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Single goal card: 84px ring + title/status/amount/pace, and either an
/// action row (Add money + more) or a completed-state green-tint card.
class _SavingsGoalCard extends StatelessWidget {
  final SavingsGoal goal;
  final _GoalStatus status;
  final NumberFormat currency;
  final DateFormat shortDate;
  final String paceCopy;

  /// Opens the allocation flow. Null when the goal is complete.
  final VoidCallback? onAddMoney;

  /// Opens the edit/delete actions sheet.
  final VoidCallback onMore;

  const _SavingsGoalCard({
    required this.goal,
    required this.status,
    required this.currency,
    required this.shortDate,
    required this.paceCopy,
    required this.onAddMoney,
    required this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = AppColors.getAccent(isDark);
    final success = AppColors.getSuccess(isDark);
    final warning = AppColors.getWarning(isDark);
    final isComplete = status == _GoalStatus.complete;

    final ringColor = switch (status) {
      _GoalStatus.complete => success,
      _GoalStatus.behind => warning,
      _GoalStatus.onTrack => accent,
    };

    final gradient = isComplete
        ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              success.withValues(alpha: 0.10),
              success.withValues(alpha: 0.02),
            ],
          )
        : null;
    final border =
        isComplete ? Border.all(color: success.withValues(alpha: 0.30)) : null;

    return GlowCard(
      gradient: gradient,
      border: border,
      // Completed cards drop the action row, so keep Edit/Delete reachable
      // via long-press on the card itself.
      onLongPress: isComplete ? onMore : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ProgressRing(
                value: isComplete ? 1.0 : goal.progress,
                size: 84,
                thickness: 9,
                color: ringColor,
                glowAlpha: isComplete ? 0.45 : 0.4,
                child: isComplete
                    ? Icon(
                        Symbols.check_rounded,
                        size: 28,
                        weight: 500,
                        fill: 1,
                        color: success,
                      )
                    : Text(
                        '${goal.progressPercent}%',
                        style: AppTypography.badgeSmall.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.getTextColor(isDark),
                        ),
                      ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            goal.name,
                            style: AppTypography.goalTitle.copyWith(
                              color: AppColors.getTextColor(isDark),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _StatusPill(status: status),
                      ],
                    ),
                    const SizedBox(height: 6),
                    _amountLine(context, isDark, isComplete),
                    const SizedBox(height: 4),
                    Text(
                      isComplete ? _fundedCopy() : paceCopy,
                      style: AppTypography.rowSubtitle.copyWith(
                        color: isComplete
                            ? success
                            : AppColors.getTextSecondaryColor(isDark),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (!isComplete) ...[
                Expanded(
                  child: PillButton(
                    label: 'Add money',
                    icon: Symbols.add_rounded,
                    color: accent,
                    filled: true,
                    height: 44,
                    onPressed: onAddMoney ?? _noop,
                  ),
                ),
                const SizedBox(width: 8),
              ] else
                const Spacer(),
              _MoreButton(onTap: onMore),
            ],
          ),
        ],
      ),
    );
  }

  static void _noop() {}

  Widget _amountLine(BuildContext context, bool isDark, bool isComplete) {
    final primary = AppColors.getTextColor(isDark);
    final secondary = AppColors.getTextSecondaryColor(isDark);
    final base = AppTypography.rowTitle.copyWith(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      color: primary,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    if (isComplete) {
      return Text.rich(
        TextSpan(
          style: base,
          children: [
            TextSpan(text: currency.format(goal.currentAmount)),
            TextSpan(
              text: ' saved',
              style: TextStyle(color: secondary, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    return Text.rich(
      TextSpan(
        style: base,
        children: [
          TextSpan(text: currency.format(goal.currentAmount)),
          TextSpan(
            text: ' of ${currency.format(goal.targetAmount)}',
            style: TextStyle(color: secondary, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  String _fundedCopy() {
    final date = shortDate.format(goal.completedAt ?? goal.targetDate);
    return 'Fully funded on $date — nice work';
  }
}

/// Status badge: `On track` (accent tint) / `Behind` (warning) / `Complete`
/// (success).
class _StatusPill extends StatelessWidget {
  final _GoalStatus status;

  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final (color, label) = switch (status) {
      _GoalStatus.complete => (AppColors.getSuccess(isDark), 'Complete'),
      _GoalStatus.behind => (AppColors.getWarning(isDark), 'Behind'),
      _GoalStatus.onTrack => (AppColors.getAccent(isDark), 'On track'),
    };

    return PillChip(
      label: label,
      color: color,
      textStyle: AppTypography.badgeSmall,
    );
  }
}

/// 44px outlined circle housing the `⋯` more action.
class _MoreButton extends StatelessWidget {
  final VoidCallback onTap;

  const _MoreButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Semantics(
      button: true,
      label: 'More goal actions',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          MicroInteractions.lightImpact();
          onTap();
        },
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.10)
                  : Colors.black.withValues(alpha: 0.10),
            ),
          ),
          alignment: Alignment.center,
          child: Icon(
            Symbols.more_horiz_rounded,
            size: 18,
            weight: 500,
            color: AppColors.getTextSecondaryColor(isDark),
          ),
        ),
      ),
    );
  }
}

/// Row inside the goal actions sheet.
class _GoalActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;

  const _GoalActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tint = color ?? AppColors.getTextColor(isDark);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        MicroInteractions.lightImpact();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        child: Row(
          children: [
            IconTile(icon: icon, color: tint, size: 40, iconSize: 20),
            const SizedBox(width: 14),
            Text(
              label,
              style: AppTypography.rowTitle.copyWith(color: tint),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dark, token-styled dialog shell shared by the form / delete dialogs.
class _DarkDialog extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const _DarkDialog({required this.child, this.maxWidth = 500});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: GlowCard(
          padding: const EdgeInsets.all(20),
          child: child,
        ),
      ),
    );
  }
}

class _GoalFormDialog extends StatefulWidget {
  final SavingsGoal? goal;
  final DateFormat dateFormat;

  const _GoalFormDialog({
    required this.goal,
    required this.dateFormat,
  });

  @override
  State<_GoalFormDialog> createState() => _GoalFormDialogState();
}

class _GoalFormDialogState extends State<_GoalFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _targetAmountController;
  late final TextEditingController _currentAmountController;
  late DateTime _targetDate;

  bool get _isEditing => widget.goal != null;

  @override
  void initState() {
    super.initState();
    final goal = widget.goal;
    _nameController = TextEditingController(text: goal?.name ?? '');
    _targetAmountController = TextEditingController(
      text: goal == null ? '' : _formatInputAmount(goal.targetAmount),
    );
    _currentAmountController = TextEditingController(
      text: goal == null ? '0.00' : _formatInputAmount(goal.currentAmount),
    );
    _targetDate = goal?.targetDate ??
        DateTime(
          DateTime.now().year,
          DateTime.now().month + 6,
          DateTime.now().day,
        );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetAmountController.dispose();
    _currentAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = AppColors.getAccent(isDark);

    return _DarkDialog(
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _isEditing ? 'Edit savings goal' : 'Add savings goal',
                style: AppTypography.goalTitle.copyWith(
                  color: AppColors.getTextColor(isDark),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              _SavingsTextField(
                controller: _nameController,
                label: 'Goal name',
                hint: 'Vacation, emergency fund, new car',
                icon: Symbols.flag_rounded,
                textCapitalization: TextCapitalization.sentences,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _SavingsTextField(
                controller: _targetAmountController,
                label: 'Target amount',
                hint: '0.00',
                icon: Symbols.attach_money_rounded,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) {
                  final amount = _parseAmount(value);
                  if (amount == null || amount <= 0) {
                    return 'Enter a target greater than 0';
                  }
                  return null;
                },
              ),
              if (_isEditing) ...[
                const SizedBox(height: 12),
                _SavingsTextField(
                  controller: _currentAmountController,
                  label: 'Saved so far',
                  hint: '0.00',
                  icon: Symbols.savings_rounded,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (value) {
                    final amount = _parseAmount(value);
                    if (amount == null || amount < 0) {
                      return 'Enter 0 or more';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 16),
              _DatePickerTile(
                label: 'Target date',
                value: widget.dateFormat.format(_targetDate),
                onTap: _pickTargetDate,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: PillButton(
                      label: 'Cancel',
                      color: AppColors.getTextSecondaryColor(isDark),
                      height: 44,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PillButton(
                      label: _isEditing ? 'Update' : 'Add',
                      icon: _isEditing
                          ? Symbols.check_rounded
                          : Symbols.add_rounded,
                      color: accent,
                      filled: true,
                      height: 44,
                      onPressed: _submit,
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

  Future<void> _pickTargetDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 20),
    );

    if (picked != null && mounted) {
      MicroInteractions.selectionClick();
      setState(() {
        _targetDate = picked;
      });
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    Navigator.of(context).pop(
      _GoalFormResult(
        name: _nameController.text.trim(),
        targetAmount: _parseAmount(_targetAmountController.text)!,
        currentAmount: _isEditing
            ? _parseAmount(_currentAmountController.text)!
            : widget.goal?.currentAmount ?? 0.0,
        targetDate: _targetDate,
      ),
    );
  }
}

class _AllocationDialog extends StatefulWidget {
  final SavingsGoal goal;
  final NumberFormat currency;

  const _AllocationDialog({
    required this.goal,
    required this.currency,
  });

  @override
  State<_AllocationDialog> createState() => _AllocationDialogState();
}

class _AllocationDialogState extends State<_AllocationDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = AppColors.getAccent(isDark);

    return _DarkDialog(
      maxWidth: 460,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Add money',
              style: AppTypography.goalTitle.copyWith(
                color: AppColors.getTextColor(isDark),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              widget.goal.name,
              style: AppTypography.rowSubtitle.copyWith(
                fontSize: 13,
                color: AppColors.getTextSecondaryColor(isDark),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            _SavingsTextField(
              controller: _amountController,
              label: 'Allocation amount',
              hint: '0.00',
              icon: Symbols.attach_money_rounded,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              autofocus: true,
              validator: (value) {
                final amount = _parseAmount(value);
                if (amount == null || amount <= 0) {
                  return 'Enter an amount greater than 0';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _QuickAmountChip(
                  label: widget.currency.format(25),
                  amount: 25,
                  onSelected: _setAmount,
                ),
                _QuickAmountChip(
                  label: widget.currency.format(100),
                  amount: 100,
                  onSelected: _setAmount,
                ),
                if (widget.goal.remainingAmount > 0)
                  _QuickAmountChip(
                    label: 'Finish goal',
                    amount: widget.goal.remainingAmount,
                    onSelected: _setAmount,
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: PillButton(
                    label: 'Cancel',
                    color: AppColors.getTextSecondaryColor(isDark),
                    height: 44,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PillButton(
                    label: 'Add money',
                    icon: Symbols.add_rounded,
                    color: accent,
                    filled: true,
                    height: 44,
                    onPressed: _submit,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _setAmount(double amount) {
    setState(() {
      _amountController.text = _formatInputAmount(amount);
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    Navigator.of(context).pop(_parseAmount(_amountController.text));
  }
}

class _QuickAmountChip extends StatelessWidget {
  final String label;
  final double amount;
  final ValueChanged<double> onSelected;

  const _QuickAmountChip({
    required this.label,
    required this.amount,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        MicroInteractions.selectionClick();
        onSelected(amount);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.getChipSurface(isDark),
          border: Border.all(color: AppColors.getCardBorder(isDark)),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: AppTypography.rowSubtitle.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.getTextColor(isDark),
          ),
        ),
      ),
    );
  }
}

class _SavingsTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final TextCapitalization textCapitalization;
  final bool autofocus;

  const _SavingsTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.validator,
    this.textCapitalization = TextCapitalization.none,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = AppColors.getAccent(isDark);
    final secondary = AppColors.getTextSecondaryColor(isDark);

    OutlineInputBorder outline(Color color, double width) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: color, width: width),
        );

    return TextFormField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      style: AppTypography.rowTitle.copyWith(
        color: AppColors.getTextColor(isDark),
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: AppTypography.rowSubtitle.copyWith(
          fontSize: 13,
          color: secondary,
        ),
        hintStyle: AppTypography.rowSubtitle.copyWith(
          fontSize: 13,
          color: AppColors.getTextTertiaryColor(isDark),
        ),
        prefixIcon: Icon(icon, size: 20, weight: 500, color: secondary),
        filled: true,
        fillColor: AppColors.getChipSurface(isDark),
        border: outline(AppColors.getCardBorder(isDark), 1),
        enabledBorder: outline(AppColors.getCardBorder(isDark), 1),
        focusedBorder: outline(accent, 1.5),
      ),
      validator: validator,
    );
  }
}

class _DatePickerTile extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _DatePickerTile({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondary = AppColors.getTextSecondaryColor(isDark);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        MicroInteractions.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.getChipSurface(isDark),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.getCardBorder(isDark)),
        ),
        child: Row(
          children: [
            Icon(Symbols.event_rounded,
                size: 20, weight: 500, color: secondary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTypography.rowSubtitle.copyWith(
                      fontSize: 12,
                      color: secondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: AppTypography.rowTitle.copyWith(
                      color: AppColors.getTextColor(isDark),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Symbols.chevron_right_rounded,
              size: 20,
              weight: 500,
              color: secondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalFormResult {
  final String name;
  final double targetAmount;
  final double currentAmount;
  final DateTime targetDate;

  const _GoalFormResult({
    required this.name,
    required this.targetAmount,
    required this.currentAmount,
    required this.targetDate,
  });
}

class _CompletionCelebration extends StatelessWidget {
  final Animation<double> animation;
  final String goalName;

  const _CompletionCelebration({
    required this.animation,
    required this.goalName,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final success = AppColors.getSuccess(isDark);
    final accent = AppColors.getAccent(isDark);

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          final curved = Curves.easeOutBack.transform(
            animation.value.clamp(0.0, 0.8) / 0.8,
          );
          final fade = animation.value < 0.75
              ? 1.0
              : (1.0 - ((animation.value - 0.75) / 0.25)).clamp(0.0, 1.0);

          return Opacity(
            opacity: fade,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.34 * fade),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    painter: _CelebrationPainter(
                      progress: animation.value,
                      color: success,
                      secondaryColor: accent,
                    ),
                    size: Size.infinite,
                  ),
                  Transform.scale(
                    scale: 0.7 + (0.3 * curved),
                    child: GlowCard(
                      padding: const EdgeInsets.all(24),
                      boxShadow: AppColors.glow(
                        success,
                        blurRadius: 40,
                        alpha: 0.35,
                        isDark: isDark,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: success,
                              shape: BoxShape.circle,
                              boxShadow: AppColors.glow(
                                success,
                                blurRadius: 28,
                                alpha: 0.55,
                                isDark: isDark,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              Symbols.check_rounded,
                              size: 34,
                              weight: 500,
                              fill: 1,
                              color: AppColors.getOnAccent(isDark),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Goal complete',
                            style: AppTypography.goalTitle.copyWith(
                              color: AppColors.getTextColor(isDark),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            goalName,
                            style: AppTypography.rowSubtitle.copyWith(
                              fontSize: 13,
                              color: AppColors.getTextSecondaryColor(isDark),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CelebrationPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color secondaryColor;

  const _CelebrationPainter({
    required this.progress,
    required this.color,
    required this.secondaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()..style = PaintingStyle.fill;

    for (var i = 0; i < 18; i++) {
      final angle = (math.pi * 2 / 18) * i;
      final distance = 44 + (progress * 180);
      final x = center.dx + math.cos(angle) * distance;
      final y = center.dy + math.sin(angle) * distance;
      final alpha = (1 - progress).clamp(0.0, 1.0);
      final radius = 3.0 + ((i % 3) * 1.5);
      paint.color = (i.isEven ? color : secondaryColor).withValues(
        alpha: alpha,
      );
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(_CelebrationPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.secondaryColor != secondaryColor;
  }
}

double? _parseAmount(String? value) {
  if (value == null) {
    return null;
  }

  final normalized = value.replaceAll(',', '').replaceAll(r'$', '').trim();
  if (normalized.isEmpty) {
    return null;
  }
  return double.tryParse(normalized);
}

String _formatInputAmount(double value) {
  return value.toStringAsFixed(2);
}
