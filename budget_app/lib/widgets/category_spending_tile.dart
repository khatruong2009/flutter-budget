import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../design_system.dart';

/// A tappable card that shows a single category's spending summary.
///
/// Displays an icon chip, category name, transaction count, share percentage,
/// formatted amount, optional budget-limit status, and a relative progress bar.
/// When [isSelected] is true the card lifts and tints with the category color.
class CategorySpendingTile extends StatelessWidget {
  /// The category name.
  final String category;

  /// Optional icon. Falls back to [CupertinoIcons.square_grid_2x2].
  final IconData? icon;

  /// Accent color used for the icon chip, progress bar, and selected tint.
  final Color color;

  /// Total amount spent in this category for the month.
  final double amount;

  /// Share of the month total expressed as a percentage (0–100).
  final double percentage;

  /// Bar fill factor relative to the largest category (0–1).
  final double barFraction;

  /// Number of transactions in this category.
  final int transactionCount;

  /// When set, shows a "of $X limit" line with color-coded warning.
  final double? budgetLimit;

  /// Whether this tile is currently selected.
  final bool isSelected;

  /// Called when the user taps the tile.
  final VoidCallback onTap;

  const CategorySpendingTile({
    super.key,
    required this.category,
    this.icon,
    required this.color,
    required this.amount,
    required this.percentage,
    required this.barFraction,
    required this.transactionCount,
    this.budgetLimit,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final moneyFmt = NumberFormat('#,##0.00', 'en_US');
    final limitFmt = NumberFormat('#,##0', 'en_US');

    return ElevatedCard(
      onTap: onTap,
      elevation: isSelected ? AppDesign.elevationM : AppDesign.elevationS,
      color: isSelected
          ? color.withValues(alpha: isDark ? 0.15 : 0.08)
          : null,
      padding: const EdgeInsets.all(AppDesign.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: icon chip + name/meta + amount + chevron
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Icon chip
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppDesign.radiusM),
                ),
                child: Icon(
                  icon ?? CupertinoIcons.square_grid_2x2,
                  color: color,
                  size: AppDesign.iconM,
                ),
              ),

              const SizedBox(width: AppDesign.spacingM),

              // Category name + transaction count / percentage
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category,
                      style: AppTypography.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppDesign.getTextPrimary(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppDesign.spacingXXS),
                    Text(
                      '$transactionCount transaction${transactionCount == 1 ? '' : 's'}'
                      ' · ${percentage.toStringAsFixed(1)}%',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppDesign.getTextSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: AppDesign.spacingS),

              // Amount + optional budget limit
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '\$${moneyFmt.format(amount)}',
                    style: AppTypography.numericSmall.copyWith(
                      color: AppDesign.getTextPrimary(context),
                    ),
                  ),
                  if (budgetLimit != null)
                    _buildLimitLine(context, limitFmt),
                ],
              ),

              const SizedBox(width: AppDesign.spacingS),

              // Chevron
              Icon(
                CupertinoIcons.chevron_right,
                size: AppDesign.iconXS,
                color: AppDesign.getTextTertiary(context),
              ),
            ],
          ),

          const SizedBox(height: AppDesign.spacingS + AppDesign.spacingXS),

          // Row 2: relative progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(AppDesign.radiusRound),
            child: Stack(
              children: [
                // Track
                Container(
                  height: 6,
                  width: double.infinity,
                  color: AppDesign.getBorderColor(context)
                      .withValues(alpha: 0.5),
                ),
                // Fill
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: barFraction.clamp(0.0, 1.0),
                  child: Container(
                    height: 6,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLimitLine(BuildContext context, NumberFormat fmt) {
    final limit = budgetLimit!;
    final ratio = limit > 0 ? amount / limit : 0.0;

    final Color limitColor;
    final FontWeight limitWeight;

    if (ratio >= 1.0) {
      limitColor = AppDesign.getErrorColor(context);
      limitWeight = FontWeight.w600;
    } else if (ratio >= 0.8) {
      limitColor = AppDesign.getWarningColor(context);
      limitWeight = FontWeight.w400;
    } else {
      limitColor = AppDesign.getTextSecondary(context);
      limitWeight = FontWeight.w400;
    }

    return Text(
      'of \$${fmt.format(limit)} limit',
      style: AppTypography.caption.copyWith(
        color: limitColor,
        fontWeight: limitWeight,
      ),
    );
  }
}
