import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../utils/micro_interactions.dart';

/// Layout constants shared by the floating dock, the per-page FABs, and the
/// bottom padding every scrollable page needs to clear the dock.
class DockMetrics {
  DockMetrics._();

  /// Distance from the bottom screen edge to the dock (design: 20).
  static double bottomOffset(BuildContext context) {
    return math.max(20.0, MediaQuery.paddingOf(context).bottom);
  }

  /// FAB bottom offset (design: 92 → 72 above the dock's bottom edge).
  static double fabBottomOffset(BuildContext context) {
    return bottomOffset(context) + 72;
  }

  /// Bottom padding for page scroll views so content clears the dock
  /// (design keeps 116px under the last card).
  static double contentBottomPadding(BuildContext context) {
    return bottomOffset(context) + 96;
  }
}

class DockItem {
  final IconData icon;
  final IconData filledIcon;
  final String label;

  const DockItem({
    required this.icon,
    required this.filledIcon,
    required this.label,
  });
}

/// Floating pill navigation dock: blurred `rgba(19,19,31,0.88)` container,
/// white/10% border. The active tab morphs from a 44px icon circle into a
/// labeled accent pill (~250ms ease-out) with an accent glow.
class FloatingDock extends StatelessWidget {
  final List<DockItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  const FloatingDock({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = AppColors.getAccent(isDark);
    final background = isDark
        ? AppColors.dockBackground
        : Colors.white.withValues(alpha: 0.88);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.black.withValues(alpha: 0.08);

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.15),
                blurRadius: 40,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < items.length; i++)
                Padding(
                  padding: EdgeInsets.only(left: i == 0 ? 0 : 2),
                  child: _DockButton(
                    item: items[i],
                    active: i == currentIndex,
                    accent: accent,
                    isDark: isDark,
                    onTap: () {
                      if (i != currentIndex) {
                        MicroInteractions.selectionClick();
                        onTap(i);
                      }
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DockButton extends StatelessWidget {
  final DockItem item;
  final bool active;
  final Color accent;
  final bool isDark;
  final VoidCallback onTap;

  const _DockButton({
    required this.item,
    required this.active,
    required this.accent,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final onAccent = AppColors.getOnAccent(isDark);
    final inactiveColor =
        isDark ? AppColors.dockInactiveIcon : AppColors.textSecondary;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        height: 44,
        padding: EdgeInsets.symmetric(horizontal: active ? 16 : 12),
        decoration: BoxDecoration(
          color: active ? accent : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          boxShadow: active
              ? AppColors.glow(accent, alpha: 0.6, isDark: isDark)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              active ? item.filledIcon : item.icon,
              size: 20,
              weight: 500,
              fill: active ? 1 : 0,
              color: active ? onAccent : inactiveColor,
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              child: active
                  ? Padding(
                      padding: const EdgeInsets.only(left: 7),
                      child: Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        // The dock is a fixed-width pill row with no room to
                        // grow; cap the label's accessibility scaling so six
                        // buttons never overflow the screen.
                        textScaler: MediaQuery.textScalerOf(context)
                            .clamp(maxScaleFactor: 1.2),
                        style: AppTypography.badgeSmall.copyWith(
                          fontSize: 13,
                          color: onAccent,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
