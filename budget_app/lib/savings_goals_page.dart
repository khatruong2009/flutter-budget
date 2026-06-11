import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'design_system.dart';
import 'savings_goal.dart';
import 'widgets/empty_state.dart';

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
  final DateFormat _dateFormat = DateFormat.yMMMd();

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
    final goals = _goals;

    return Scaffold(
      backgroundColor: AppDesign.getBackgroundColor(context),
      appBar: ModernAppBar(
        title: 'Savings Goals',
        showGradient: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add savings goal',
            onPressed: _isBusy ? null : () => _showGoalForm(context),
          ),
        ],
      ),
      body: Stack(
        children: [
          goals.isEmpty ? _buildEmptyState(context) : _buildGoalsList(goals),
          if (_celebrationGoalName != null)
            Positioned.fill(
              child: _CompletionCelebration(
                animation: _celebrationController,
                goalName: _celebrationGoalName!,
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isBusy ? null : () => _showGoalForm(context),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
        tooltip: 'Add savings goal',
        child: const Icon(Icons.add),
      ),
    );
  }

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

  Widget _buildEmptyState(BuildContext context) {
    return EmptyState.noData(
      icon: Icons.savings_outlined,
      title: 'No Savings Goals Yet',
      message:
          'Create a goal, set a target date, and track progress as you set money aside.',
      actionLabel: 'Add Goal',
      onAction: _isBusy ? null : () => _showGoalForm(context),
    );
  }

  Widget _buildGoalsList(List<SavingsGoal> goals) {
    final sortedGoals = List<SavingsGoal>.from(goals)
      ..sort((a, b) {
        if (a.isCompleted != b.isCompleted) {
          return a.isCompleted ? 1 : -1;
        }
        return a.targetDate.compareTo(b.targetDate);
      });

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = AppDesign.getResponsiveSpacing(
          context,
          phone: AppDesign.spacingM,
          tablet: AppDesign.spacingL,
          desktop: AppDesign.spacingXL,
        );

        return ListView.separated(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            AppDesign.spacingM,
            horizontalPadding,
            AppDesign.spacingXXL,
          ),
          itemCount: sortedGoals.length + 1,
          separatorBuilder: (context, index) =>
              const SizedBox(height: AppDesign.spacingM),
          itemBuilder: (context, index) {
            if (index == 0) {
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppDesign.maxContentWidth,
                  ),
                  child: _SavingsGoalsSummary(
                    goals: sortedGoals,
                    currency: _currency,
                  ),
                ),
              );
            }

            final goal = sortedGoals[index - 1];
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppDesign.maxContentWidth,
                ),
                child: _SavingsGoalCard(
                  goal: goal,
                  currency: _currency,
                  dateFormat: _dateFormat,
                  onAllocate: () => _showAllocationForm(context, goal),
                  onEdit: () => _showGoalForm(context, goal: goal),
                  onDelete: () => _confirmDelete(context, goal),
                ),
              ),
            );
          },
        );
      },
    );
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
          currency: _currency,
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

    if (willComplete && mounted) {
      HapticFeedback.mediumImpact();
      setState(() {
        _celebrationGoalName = goal.name;
      });
      _celebrationController.forward(from: 0);
    }
  }

  Future<void> _confirmDelete(BuildContext context, SavingsGoal goal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppDesign.getCardColor(context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDesign.radiusL),
          ),
          title: Text(
            'Delete Savings Goal?',
            style: AppTypography.headingMedium.copyWith(
              color: AppDesign.getTextPrimary(context),
            ),
          ),
          content: Text(
            'This removes "${goal.name}" and its saved progress from your goals.',
            style: AppTypography.bodyMedium.copyWith(
              color: AppDesign.getTextSecondary(context),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                'Cancel',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppDesign.getTextSecondary(context),
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                'Delete',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppDesign.getErrorColor(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
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
          AppDesign.getSuccessColor(context),
        );
      }
    } catch (error) {
      if (context.mounted) {
        _showSnackBar(
          context,
          'Savings goal action failed',
          AppDesign.getErrorColor(context),
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

class _SavingsGoalsSummary extends StatelessWidget {
  final List<SavingsGoal> goals;
  final NumberFormat currency;

  const _SavingsGoalsSummary({
    required this.goals,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final totalSaved = goals.fold<double>(
      0,
      (sum, goal) => sum + goal.currentAmount,
    );
    final totalTarget = goals.fold<double>(
      0,
      (sum, goal) => sum + goal.targetAmount,
    );
    final completedCount = goals.where((goal) => goal.isCompleted).length;
    final totalProgress = totalTarget <= 0 ? 0.0 : totalSaved / totalTarget;

    return ElevatedCard(
      elevation: AppDesign.elevationS,
      padding: const EdgeInsets.all(AppDesign.spacingM),
      child: Row(
        children: [
          _ProgressRing(
            progress: totalProgress.clamp(0.0, 1.0),
            color: AppDesign.getIncomeColor(context),
            size: 72,
            strokeWidth: 8,
            label: '${(totalProgress.clamp(0.0, 1.0) * 100).round()}%',
          ),
          const SizedBox(width: AppDesign.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total saved',
                  style: AppTypography.caption.copyWith(
                    color: AppDesign.getTextSecondary(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppDesign.spacingXS),
                Text(
                  currency.format(totalSaved),
                  style: AppTypography.numericMedium.copyWith(
                    color: AppDesign.getTextPrimary(context),
                  ),
                ),
                const SizedBox(height: AppDesign.spacingXS),
                Text(
                  '${currency.format(totalTarget)} target • $completedCount of ${goals.length} complete',
                  style: AppTypography.caption.copyWith(
                    color: AppDesign.getTextSecondary(context),
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

class _SavingsGoalCard extends StatelessWidget {
  final SavingsGoal goal;
  final NumberFormat currency;
  final DateFormat dateFormat;
  final VoidCallback onAllocate;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SavingsGoalCard({
    required this.goal,
    required this.currency,
    required this.dateFormat,
    required this.onAllocate,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = goal.isCompleted
        ? AppDesign.getSuccessColor(context)
        : goal.isOverdue
            ? AppDesign.getWarningColor(context)
            : AppColors.primary;

    return ElevatedCard(
      elevation: AppDesign.elevationS,
      padding: const EdgeInsets.all(AppDesign.spacingM),
      onTap: onAllocate,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ProgressRing(
                progress: goal.progress,
                color: accentColor,
                size: 76,
                strokeWidth: 8,
                label: '${goal.progressPercent}%',
              ),
              const SizedBox(width: AppDesign.spacingM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            goal.name,
                            style: AppTypography.headingSmall.copyWith(
                              color: AppDesign.getTextPrimary(context),
                            ),
                          ),
                        ),
                        _StatusPill(goal: goal),
                      ],
                    ),
                    const SizedBox(height: AppDesign.spacingS),
                    Text(
                      '${currency.format(goal.currentAmount)} saved of ${currency.format(goal.targetAmount)}',
                      style: AppTypography.numericSmall.copyWith(
                        color: AppDesign.getTextPrimary(context),
                      ),
                    ),
                    const SizedBox(height: AppDesign.spacingXS),
                    Text(
                      _supportingText,
                      style: AppTypography.caption.copyWith(
                        color: AppDesign.getTextSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDesign.spacingM),
          _GoalDetailRow(
            icon: Icons.flag_outlined,
            label: 'Remaining',
            value: currency.format(goal.remainingAmount),
          ),
          const SizedBox(height: AppDesign.spacingS),
          _GoalDetailRow(
            icon: Icons.event_outlined,
            label: 'Target date',
            value: dateFormat.format(goal.targetDate),
          ),
          const SizedBox(height: AppDesign.spacingM),
          Row(
            children: [
              Expanded(
                child: AppButton.primary(
                  label: 'Allocate',
                  icon: Icons.add_card_outlined,
                  size: AppButtonSize.small,
                  onPressed: goal.isCompleted ? null : onAllocate,
                  gradient: AppDesign.getIncomeGradient(context),
                ),
              ),
              const SizedBox(width: AppDesign.spacingS),
              _IconActionButton(
                icon: Icons.edit_outlined,
                tooltip: 'Edit goal',
                onPressed: onEdit,
              ),
              const SizedBox(width: AppDesign.spacingS),
              _IconActionButton(
                icon: Icons.delete_outline,
                tooltip: 'Delete goal',
                color: AppDesign.getErrorColor(context),
                onPressed: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String get _supportingText {
    if (goal.isCompleted) {
      return 'Completed goal';
    }
    if (goal.isOverdue) {
      return '${goal.daysRemaining.abs()} days past target';
    }
    if (goal.daysRemaining == 0) {
      return 'Due today';
    }
    return '${goal.daysRemaining} days left • ${currency.format(goal.suggestedMonthlyContribution)}/mo suggested';
  }
}

class _StatusPill extends StatelessWidget {
  final SavingsGoal goal;

  const _StatusPill({required this.goal});

  @override
  Widget build(BuildContext context) {
    final color = goal.isCompleted
        ? AppDesign.getSuccessColor(context)
        : goal.isOverdue
            ? AppDesign.getWarningColor(context)
            : AppDesign.getInfoColor(context);
    final label = goal.isCompleted
        ? 'Done'
        : goal.isOverdue
            ? 'Overdue'
            : 'Active';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDesign.spacingS,
        vertical: AppDesign.spacingXS,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppDesign.radiusRound),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: AppTypography.captionSmall.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _GoalDetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _GoalDetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: AppDesign.iconS,
          color: AppDesign.getTextSecondary(context),
        ),
        const SizedBox(width: AppDesign.spacingS),
        Text(
          label,
          style: AppTypography.caption.copyWith(
            color: AppDesign.getTextSecondary(context),
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: AppTypography.labelSmall.copyWith(
            color: AppDesign.getTextPrimary(context),
          ),
        ),
      ],
    );
  }
}

class _IconActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color? color;
  final VoidCallback onPressed;

  const _IconActionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = color ?? AppDesign.getTextPrimary(context);

    return SizedBox(
      width: AppDesign.touchTargetS,
      height: AppDesign.touchTargetS,
      child: Tooltip(
        message: tooltip,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDesign.radiusM),
            border: Border.all(
              color: AppDesign.getBorderColor(context),
              width: AppDesign.borderThin,
            ),
          ),
          child: IconButton(
            icon: Icon(icon),
            iconSize: AppDesign.iconS,
            color: iconColor,
            tooltip: tooltip,
            onPressed: onPressed,
          ),
        ),
      ),
    );
  }
}

class _ProgressRing extends StatelessWidget {
  final double progress;
  final Color color;
  final double size;
  final double strokeWidth;
  final String label;

  const _ProgressRing({
    required this.progress,
    required this.color,
    required this.size,
    required this.strokeWidth,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final normalizedProgress = progress.clamp(0.0, 1.0);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: normalizedProgress),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _ProgressRingPainter(
              progress: value,
              color: color,
              trackColor: AppDesign.getBorderColor(context),
              strokeWidth: strokeWidth,
            ),
            child: Center(
              child: Text(
                label,
                style: AppTypography.labelSmall.copyWith(
                  color: AppDesign.getTextPrimary(context),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ProgressRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  const _ProgressRingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final trackPaint = Paint()
      ..color = trackColor.withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      progress * math.pi * 2,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_ProgressRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

class _GoalFormDialog extends StatefulWidget {
  final SavingsGoal? goal;
  final NumberFormat currency;
  final DateFormat dateFormat;

  const _GoalFormDialog({
    required this.goal,
    required this.currency,
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
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppDesign.spacingL,
        vertical: AppDesign.spacingXL,
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        decoration: BoxDecoration(
          color: AppDesign.getCardColor(context),
          borderRadius: BorderRadius.circular(AppDesign.radiusXL),
          boxShadow: AppDesign.shadowXL,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDesign.spacingM),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _isEditing ? 'Edit Savings Goal' : 'Add Savings Goal',
                  style: AppTypography.headingMedium.copyWith(
                    color: AppDesign.getTextPrimary(context),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppDesign.spacingM),
                _SavingsTextField(
                  controller: _nameController,
                  label: 'Goal name',
                  hint: 'Vacation, emergency fund, new car',
                  icon: Icons.flag_outlined,
                  textCapitalization: TextCapitalization.sentences,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppDesign.spacingS),
                _SavingsTextField(
                  controller: _targetAmountController,
                  label: 'Target amount',
                  hint: '0.00',
                  icon: Icons.attach_money,
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
                  const SizedBox(height: AppDesign.spacingS),
                  _SavingsTextField(
                    controller: _currentAmountController,
                    label: 'Saved so far',
                    hint: '0.00',
                    icon: Icons.savings_outlined,
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
                const SizedBox(height: AppDesign.spacingM),
                _DatePickerTile(
                  label: 'Target date',
                  value: widget.dateFormat.format(_targetDate),
                  onTap: _pickTargetDate,
                ),
                const SizedBox(height: AppDesign.spacingL),
                Row(
                  children: [
                    Expanded(
                      child: AppButton.secondary(
                        label: 'Cancel',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    const SizedBox(width: AppDesign.spacingM),
                    Expanded(
                      child: AppButton.primary(
                        label: _isEditing ? 'Update' : 'Add',
                        icon: _isEditing
                            ? Icons.check_outlined
                            : Icons.add_outlined,
                        onPressed: _submit,
                        gradient: AppDesign.getPrimaryGradient(context),
                      ),
                    ),
                  ],
                ),
              ],
            ),
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
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppDesign.spacingL,
        vertical: AppDesign.spacingXL,
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 460),
        decoration: BoxDecoration(
          color: AppDesign.getCardColor(context),
          borderRadius: BorderRadius.circular(AppDesign.radiusXL),
          boxShadow: AppDesign.shadowXL,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppDesign.spacingM),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Allocate to Goal',
                  style: AppTypography.headingMedium.copyWith(
                    color: AppDesign.getTextPrimary(context),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppDesign.spacingS),
                Text(
                  widget.goal.name,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppDesign.getTextSecondary(context),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppDesign.spacingM),
                _SavingsTextField(
                  controller: _amountController,
                  label: 'Allocation amount',
                  hint: '0.00',
                  icon: Icons.attach_money,
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
                const SizedBox(height: AppDesign.spacingS),
                Wrap(
                  spacing: AppDesign.spacingS,
                  runSpacing: AppDesign.spacingS,
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
                const SizedBox(height: AppDesign.spacingL),
                Row(
                  children: [
                    Expanded(
                      child: AppButton.secondary(
                        label: 'Cancel',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    const SizedBox(width: AppDesign.spacingM),
                    Expanded(
                      child: AppButton.primary(
                        label: 'Allocate',
                        icon: Icons.add_card_outlined,
                        onPressed: _submit,
                        gradient: AppDesign.getIncomeGradient(context),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
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
    return ActionChip(
      label: Text(label),
      onPressed: () => onSelected(amount),
      backgroundColor: AppDesign.getSurfaceColor(context),
      side: BorderSide(color: AppDesign.getBorderColor(context)),
      labelStyle: AppTypography.caption.copyWith(
        color: AppDesign.getTextPrimary(context),
        fontWeight: FontWeight.w600,
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
    return TextFormField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      style: AppTypography.bodyMedium.copyWith(
        color: AppDesign.getTextPrimary(context),
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: AppDesign.getTextSecondary(context)),
        filled: true,
        fillColor: AppDesign.getSurfaceColor(context),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDesign.radiusM),
          borderSide: BorderSide(
            color: AppDesign.getBorderColor(context),
            width: AppDesign.borderThin,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDesign.radiusM),
          borderSide: BorderSide(
            color: AppDesign.getBorderColor(context),
            width: AppDesign.borderThin,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDesign.radiusM),
          borderSide: const BorderSide(
            color: AppColors.primary,
            width: AppDesign.borderMedium,
          ),
        ),
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
    return Material(
      color: AppDesign.getSurfaceColor(context),
      borderRadius: BorderRadius.circular(AppDesign.radiusM),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDesign.radiusM),
        child: Container(
          padding: const EdgeInsets.all(AppDesign.spacingM),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDesign.radiusM),
            border: Border.all(
              color: AppDesign.getBorderColor(context),
              width: AppDesign.borderThin,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.event_outlined,
                color: AppDesign.getTextSecondary(context),
              ),
              const SizedBox(width: AppDesign.spacingM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppTypography.caption.copyWith(
                        color: AppDesign.getTextSecondary(context),
                      ),
                    ),
                    const SizedBox(height: AppDesign.spacingXXS),
                    Text(
                      value,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppDesign.getTextPrimary(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: AppDesign.getTextSecondary(context),
              ),
            ],
          ),
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
                color: Colors.black.withValues(alpha: 0.22 * fade),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    painter: _CelebrationPainter(
                      progress: animation.value,
                      color: AppDesign.getSuccessColor(context),
                    ),
                    size: Size.infinite,
                  ),
                  Transform.scale(
                    scale: 0.7 + (0.3 * curved),
                    child: Container(
                      width: 260,
                      padding: const EdgeInsets.all(AppDesign.spacingL),
                      decoration: BoxDecoration(
                        color: AppDesign.getCardColor(context),
                        borderRadius: BorderRadius.circular(AppDesign.radiusXL),
                        boxShadow: AppDesign.shadowXL,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              gradient: AppDesign.getIncomeGradient(context),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check,
                              color: AppColors.textOnPrimary,
                              size: AppDesign.iconL,
                            ),
                          ),
                          const SizedBox(height: AppDesign.spacingM),
                          Text(
                            'Goal Complete',
                            style: AppTypography.headingMedium.copyWith(
                              color: AppDesign.getTextPrimary(context),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppDesign.spacingS),
                          Text(
                            goalName,
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppDesign.getTextSecondary(context),
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

  const _CelebrationPainter({
    required this.progress,
    required this.color,
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
      paint.color = (i.isEven ? color : AppColors.primary).withValues(
        alpha: alpha,
      );
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(_CelebrationPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
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
