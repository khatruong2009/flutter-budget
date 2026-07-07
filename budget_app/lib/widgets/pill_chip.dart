import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../utils/micro_interactions.dart';

/// Small pill badge, e.g. `$61 over` (tinted) or `Set limit` (outlined).
class PillChip extends StatelessWidget {
  final String label;
  final Color color;

  /// Tinted (color@14% background) when false; outlined (color@40% border)
  /// when true.
  final bool outlined;

  /// Optional leading icon (e.g. `trending_up` on the Net Worth delta pill).
  final IconData? icon;

  /// Use `AppTypography.badgeSmall` for the 11px goal badges.
  final TextStyle? textStyle;

  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const PillChip({
    super.key,
    required this.label,
    required this.color,
    this.outlined = false,
    this.icon,
    this.textStyle,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: outlined ? null : color.withValues(alpha: 0.14),
        border: outlined
            ? Border.all(color: color.withValues(alpha: 0.4))
            : null,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, weight: 500, color: color),
            const SizedBox(width: 6),
          ],
          Text(label, style: (textStyle ?? AppTypography.badge).copyWith(color: color)),
        ],
      ),
    );

    if (onTap == null) return chip;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        MicroInteractions.lightImpact();
        onTap!();
      },
      child: chip,
    );
  }
}

/// 52px outlined pill button, e.g. `− Expense` / `+ Income` on Home, and the
/// filled accent variant (`+ Add money` on Goals, 44px).
class PillButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final Color color;
  final VoidCallback onPressed;

  /// Filled accent pill (dark label, accent glow) instead of tinted outline.
  final bool filled;

  final double height;

  const PillButton({
    super.key,
    required this.label,
    required this.color,
    required this.onPressed,
    this.icon,
    this.filled = false,
    this.height = 52,
  });

  @override
  State<PillButton> createState() => _PillButtonState();
}

class _PillButtonState extends State<PillButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground =
        widget.filled ? AppColors.getOnAccent(isDark) : widget.color;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () {
        MicroInteractions.lightImpact();
        widget.onPressed();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          height: widget.height,
          decoration: BoxDecoration(
            color: widget.filled
                ? widget.color
                : widget.color.withValues(alpha: 0.1),
            border: widget.filled
                ? null
                : Border.all(color: widget.color.withValues(alpha: 0.35)),
            borderRadius: BorderRadius.circular(999),
            boxShadow: widget.filled
                ? AppColors.glow(widget.color,
                    blurRadius: 20, alpha: 0.45, isDark: isDark)
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: widget.filled ? 18 : 20,
                    weight: 500, color: foreground),
                SizedBox(width: widget.filled ? 6 : 8),
              ],
              Text(
                widget.label,
                style: AppTypography.rowTitle.copyWith(
                  fontSize: widget.filled ? 14 : 15,
                  fontWeight: FontWeight.w700,
                  color: foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Segmented pill control (`Light / Dark / Auto` in Settings; `6M / 1Y / ALL`
/// range pills use [mono] = true and no track).
class SegmentedPillControl extends StatelessWidget {
  final List<String> segments;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  /// Mono typography, transparent track, accent-tint active segment
  /// (chart range pills). Default is the Settings theme control style.
  final bool mono;

  const SegmentedPillControl({
    super.key,
    required this.segments,
    required this.selectedIndex,
    required this.onChanged,
    this.mono = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = AppColors.getAccent(isDark);
    final inactiveText =
        isDark ? AppColors.dockInactiveIcon : AppColors.textSecondary;

    return Container(
      padding: mono ? EdgeInsets.zero : const EdgeInsets.all(3),
      decoration: mono
          ? null
          : BoxDecoration(
              color: AppColors.getTrack(isDark),
              borderRadius: BorderRadius.circular(999),
            ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < segments.length; i++)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (i != selectedIndex) {
                  MicroInteractions.selectionClick();
                  onChanged(i);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                margin: EdgeInsets.only(left: mono && i > 0 ? 4 : 0),
                padding: mono
                    ? const EdgeInsets.symmetric(horizontal: 11, vertical: 5)
                    : const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: i != selectedIndex
                      ? Colors.transparent
                      : mono
                          ? accent.withValues(alpha: 0.18)
                          : accent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  segments[i],
                  style: mono
                      ? AppTypography.monoLink.copyWith(
                          letterSpacing: 0,
                          color: i == selectedIndex ? accent : inactiveText,
                        )
                      : AppTypography.rowSubtitle.copyWith(
                          fontWeight: i == selectedIndex
                              ? FontWeight.w700
                              : FontWeight.w600,
                          color: i == selectedIndex
                              ? AppColors.getOnAccent(isDark)
                              : inactiveText,
                        ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
