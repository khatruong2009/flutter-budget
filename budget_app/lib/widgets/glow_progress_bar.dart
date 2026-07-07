import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Pill progress bar with a glowing fill that animates from 0 to [value] on
/// entry. Heights per design: 8 (budgets), 6 (categories), 12–16 (comparisons).
class GlowProgressBar extends StatelessWidget {
  /// Fill fraction 0..1 (values beyond 1 are clamped).
  final double value;
  final double height;
  final Color color;

  /// Track color; defaults to the theme inset track (`#1B1B2C`).
  final Color? trackColor;

  /// Gradient fill (e.g. the Home spend gauge). Overrides [color] for fill.
  final Gradient? gradient;

  /// White thumb dot at the end of the fill (Home spend gauge).
  final bool showThumb;

  /// 1px border around the track (Home spend gauge uses white/6%).
  final BoxBorder? trackBorder;

  /// Inset between track edge and fill (Home spend gauge uses 2).
  final double fillInset;

  final bool animate;

  const GlowProgressBar({
    super.key,
    required this.value,
    required this.color,
    this.height = 8,
    this.trackColor,
    this.gradient,
    this.showThumb = false,
    this.trackBorder,
    this.fillInset = 0,
    this.animate = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final track = trackColor ?? AppColors.getTrack(isDark);
    final clamped = value.isNaN ? 0.0 : value.clamp(0.0, 1.0).toDouble();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: animate && !reduceMotion ? 0 : clamped, end: clamped),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOutCubic,
      builder: (context, t, _) {
        return Container(
          height: height,
          decoration: BoxDecoration(
            color: track,
            borderRadius: BorderRadius.circular(999),
            border: trackBorder,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final innerWidth = constraints.maxWidth - fillInset * 2;
              final innerHeight =
                  height - fillInset * 2 - (trackBorder == null ? 0 : 2);
              final fillWidth = innerWidth * t;
              // Keep the thumb footprint inside the track's inner bounds.
              final thumbMin = fillInset;
              final thumbMax = innerWidth + fillInset - height;
              if (t <= 0) return const SizedBox.expand();
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: fillInset,
                    top: fillInset,
                    width: fillWidth,
                    height: innerHeight,
                    child: Container(
                      decoration: BoxDecoration(
                        color: gradient == null ? color : null,
                        gradient: gradient,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: AppColors.glow(color,
                            blurRadius: 12, alpha: 0.6, isDark: isDark),
                      ),
                    ),
                  ),
                  if (showThumb && thumbMax > thumbMin)
                    Positioned(
                      // Clamp so the thumb never overhangs the rounded track
                      // caps (value 1, or the entry animation passing near 0).
                      left: (fillInset + fillWidth - height / 2)
                          .clamp(thumbMin, thumbMax)
                          .toDouble(),
                      top: (height - (trackBorder == null ? 0 : 2)) / 2 -
                          height / 2,
                      child: Container(
                        width: height,
                        height: height,
                        decoration: BoxDecoration(
                          color:
                              isDark ? const Color(0xFFF2F2FA) : Colors.white,
                          shape: BoxShape.circle,
                          border: isDark
                              ? null
                              : Border.all(
                                  color: color.withValues(alpha: 0.6),
                                  width: 2,
                                ),
                          boxShadow: AppColors.glow(color,
                              blurRadius: 12, alpha: 0.8, isDark: isDark),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

/// Split assets/liabilities pill bar: green portion left, rose right, 3px gap,
/// both glowing. [assetsFraction] is assets / (assets + liabilities).
class SplitGlowBar extends StatelessWidget {
  final double assetsFraction;
  final double height;

  const SplitGlowBar(
      {super.key, required this.assetsFraction, this.height = 16});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fraction =
        assetsFraction.isNaN ? 0.0 : assetsFraction.clamp(0.0, 1.0).toDouble();
    const green = AppColors.incomeDarkTheme;
    final rose = AppColors.getDanger(isDark);

    Widget segment(Color color, {Gradient? gradient}) => Container(
          height: height,
          decoration: BoxDecoration(
            color: gradient == null ? color : null,
            gradient: gradient,
            borderRadius: BorderRadius.circular(999),
            boxShadow: AppColors.glow(color,
                blurRadius: 14, alpha: 0.5, isDark: isDark),
          ),
        );

    // Degenerate cases: a single full-width bar.
    if (fraction >= 1.0 || fraction <= 0.0) {
      return segment(fraction >= 1.0 ? green : rose,
          gradient: fraction >= 1.0
              ? const LinearGradient(
                  colors: [Color(0xFF2AB98A), Color(0xFF34D399)])
              : null);
    }

    return Row(
      children: [
        Expanded(
          flex: (fraction * 1000).round(),
          child: segment(green,
              gradient: const LinearGradient(
                  colors: [Color(0xFF2AB98A), Color(0xFF34D399)])),
        ),
        const SizedBox(width: 3),
        Expanded(
          flex: ((1 - fraction) * 1000).round(),
          child: segment(rose),
        ),
      ],
    );
  }
}
