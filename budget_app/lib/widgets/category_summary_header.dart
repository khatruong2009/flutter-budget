import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:animated_digit/animated_digit.dart';
import '../design_system.dart';

/// Displays the total-spent header for the Categories tab.
///
/// Shows the month label, the animated total amount, and — when
/// [previousMonthTotal] is provided — a delta chip indicating how spending
/// changed relative to last month. Spending DOWN is semantically positive
/// (green) and spending UP is negative (red).
class CategorySummaryHeader extends StatelessWidget {
  /// The total amount spent in the selected month.
  final double totalSpent;

  /// Total from the prior month. When null the delta chip is hidden.
  final double? previousMonthTotal;

  /// Human-readable month label, e.g. "June 2026". Displayed in uppercase.
  final String monthLabel;

  const CategorySummaryHeader({
    super.key,
    required this.totalSpent,
    this.previousMonthTotal,
    required this.monthLabel,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ElevatedCard(
      elevation: AppDesign.elevationS,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Caption line: "TOTAL SPENT · JUNE 2026"
          Text(
            'TOTAL SPENT · ${monthLabel.toUpperCase()}',
            style: AppTypography.labelSmall.copyWith(
              color: AppDesign.getTextSecondary(context),
              letterSpacing: 0.8,
            ),
          ),

          const SizedBox(height: AppDesign.spacingS),

          // Amount row: "$" prefix + animated digits
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '\$',
                style: AppTypography.numericLarge.copyWith(
                  color: AppDesign.getTextPrimary(context),
                ),
              ),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: AnimatedDigitWidget(
                    value: totalSpent,
                    fractionDigits: 2,
                    enableSeparator: true,
                    textStyle: AppTypography.numericLarge.copyWith(
                      color: AppDesign.getTextPrimary(context),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Delta chip — only shown when previous month data is available
          if (previousMonthTotal != null && previousMonthTotal! != 0.0)
            _buildDeltaChip(context, isDark),
        ],
      ),
    );
  }

  Widget _buildDeltaChip(BuildContext context, bool isDark) {
    final prev = previousMonthTotal!;
    final pctChange = (totalSpent - prev) / prev * 100;
    final absChange = pctChange.abs();

    // Within ±0.5% is treated as neutral
    final isNeutral = absChange < 0.5;
    // Spending increase is bad (error color); decrease is good (success color)
    final isIncrease = pctChange >= 0.5;

    final Color chipColor;
    final IconData chipIcon;

    if (isNeutral) {
      chipColor = AppDesign.getTextSecondary(context);
      chipIcon = CupertinoIcons.minus;
    } else if (isIncrease) {
      chipColor = AppDesign.getErrorColor(context);
      chipIcon = CupertinoIcons.arrow_up_right;
    } else {
      chipColor = AppDesign.getSuccessColor(context);
      chipIcon = CupertinoIcons.arrow_down_right;
    }

    return Padding(
      padding: const EdgeInsets.only(top: AppDesign.spacingS),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDesign.spacingS,
          vertical: AppDesign.spacingXS,
        ),
        decoration: BoxDecoration(
          color: chipColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppDesign.radiusRound),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              chipIcon,
              size: AppDesign.iconXS,
              color: chipColor,
            ),
            const SizedBox(width: AppDesign.spacingXXS),
            Text(
              '${absChange.toStringAsFixed(0)}% vs last month',
              style: AppTypography.labelMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: chipColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
