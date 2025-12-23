import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../design_system.dart';

class HomeQuickActionWidget extends StatelessWidget {
  final VoidCallback onAddIncome;
  final VoidCallback onAddExpense;

  const HomeQuickActionWidget({
    super.key,
    required this.onAddIncome,
    required this.onAddExpense,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      height: 160,
      child: AspectRatio(
        aspectRatio: 1,
        child: ElevatedCard(
          padding: EdgeInsets.zero,
          elevation: AppDesign.elevationM,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppDesign.radiusM),
            child: Column(
              children: [
                _QuickActionButton(
                  label: 'Add Income',
                  icon: CupertinoIcons.plus_circle_fill,
                  gradient: AppDesign.getIncomeGradient(context),
                  textColor:
                      isDark ? AppColors.textOnPrimaryDark : AppColors.textOnPrimary,
                  onPressed: onAddIncome,
                  showDivider: true,
                ),
                _QuickActionButton(
                  label: 'Add Expense',
                  icon: CupertinoIcons.minus_circle_fill,
                  gradient: AppDesign.getExpenseGradient(context),
                  textColor:
                      isDark ? AppColors.textOnPrimaryDark : AppColors.textOnPrimary,
                  onPressed: onAddExpense,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Gradient gradient;
  final Color textColor;
  final VoidCallback onPressed;
  final bool showDivider;

  const _QuickActionButton({
    required this.label,
    required this.icon,
    required this.gradient,
    required this.textColor,
    required this.onPressed,
    this.showDivider = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onPressed,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: gradient,
          ),
          child: Stack(
            children: [
              if (showDivider)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 1,
                    color: Colors.white.withOpacity(0.15),
                  ),
                ),
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: AppDesign.iconM,
                      color: textColor,
                    ),
                    const SizedBox(width: AppDesign.spacingS),
                    Text(
                      label,
                      style: AppTypography.bodyLarge.copyWith(
                        color: textColor,
                        fontWeight: FontWeight.w700,
                      ),
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
}
