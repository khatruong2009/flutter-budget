import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../utils/micro_interactions.dart';

/// Page header row: title (or the Budgie logo mark on Home) on the left,
/// optional pill on the right. When there is no trailing pill a 36px spacer
/// keeps the layout symmetric — add buttons live in the FAB, never here.
class BudgieHeader extends StatelessWidget {
  /// Page title. Ignored when [showLogo] is true.
  final String? title;

  /// Budgie logo mark (36px, radius 12) instead of a title — Home only.
  final bool showLogo;

  /// Trailing widget, typically a [MonthPill]. Null renders a 36px spacer.
  final Widget? trailing;

  /// Centers [trailing] between logo and spacer (Home month pill).
  final bool centerTrailing;

  const BudgieHeader({
    super.key,
    this.title,
    this.showLogo = false,
    this.trailing,
    this.centerTrailing = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final leading = showLogo
        ? ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              'assets/budgie_mark.png',
              width: 36,
              height: 36,
              fit: BoxFit.cover,
            ),
          )
        : Text(
            title ?? '',
            style: AppTypography.pageTitle.copyWith(
              color: AppColors.getTextColor(isDark),
            ),
          );

    if (centerTrailing) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        child: Row(
          children: [
            leading,
            Expanded(child: Center(child: trailing ?? const SizedBox())),
            const SizedBox(width: 36, height: 36),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          leading,
          trailing ?? const SizedBox(width: 36, height: 36),
        ],
      ),
    );
  }
}

/// Month/range pill: surface `#15151F`, white/8% border, label + expand_more.
class MonthPill extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const MonthPill({super.key, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.getChipSurface(isDark),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.08),
        ),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppTypography.rowTitle.copyWith(
              fontSize: 14,
              color: AppColors.getTextColor(isDark),
            ),
          ),
          const SizedBox(width: 6),
          Icon(
            Symbols.expand_more_rounded,
            size: 16,
            weight: 500,
            color: AppColors.getTextSecondaryColor(isDark),
          ),
        ],
      ),
    );

    if (onTap == null) return pill;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        MicroInteractions.lightImpact();
        onTap!();
      },
      child: pill,
    );
  }
}

/// Section header row: `Budgets` left + optional mono accent link (`EDIT`,
/// `SEE ALL`) right, inset 4px like the design.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? linkLabel;
  final VoidCallback? onLinkTap;

  const SectionHeader({
    super.key,
    required this.title,
    this.linkLabel,
    this.onLinkTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Text(
              title,
              style: AppTypography.sectionHeader.copyWith(
                color: AppColors.getTextColor(isDark),
              ),
            ),
          ),
          if (linkLabel != null)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onLinkTap == null
                  ? null
                  : () {
                      MicroInteractions.lightImpact();
                      onLinkTap!();
                    },
              child: Text(
                linkLabel!,
                style: AppTypography.monoLink.copyWith(
                  color: AppColors.getAccent(isDark),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
