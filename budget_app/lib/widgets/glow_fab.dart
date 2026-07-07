import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/app_colors.dart';
import '../utils/micro_interactions.dart';

/// 54px accent circle FAB with strong accent glow + drop shadow, floating
/// above the dock at bottom-right. Scales in on page entry and presses to
/// 0.95. Tapping fires a one-shot burst: a ping ring expands outward while
/// the glow flares and the icon pops. Skipped under reduced motion.
class GlowFab extends StatefulWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String? semanticLabel;

  const GlowFab({
    super.key,
    required this.onPressed,
    this.icon = Symbols.add_rounded,
    this.semanticLabel,
  });

  @override
  State<GlowFab> createState() => _GlowFabState();
}

class _GlowFabState extends State<GlowFab> with TickerProviderStateMixin {
  late final AnimationController _entry;
  late final AnimationController _burst;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _entry = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    )..forward();
    _burst = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _entry.dispose();
    _burst.dispose();
    super.dispose();
  }

  void _handleTap() {
    MicroInteractions.lightImpact();
    if (!MediaQuery.disableAnimationsOf(context)) {
      _burst.forward(from: 0);
    }
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = AppColors.getAccent(isDark);

    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: ScaleTransition(
        scale: CurvedAnimation(parent: _entry, curve: Curves.easeOutBack),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          onTap: _handleTap,
          child: AnimatedScale(
            scale: _pressed ? 0.95 : 1.0,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _burst,
                builder: (context, child) {
                  final bursting = _burst.isAnimating;
                  final ping = Curves.easeOut.transform(_burst.value);
                  // Glow flare rises and falls over the burst.
                  final flare = math.sin(math.pi * _burst.value);
                  // Quick icon pop with a slight overshoot mid-burst.
                  final iconPop = 1 + 0.22 * flare;

                  return Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      if (bursting)
                        IgnorePointer(
                          child: Transform.scale(
                            scale: 1 + 0.7 * ping,
                            child: Container(
                              width: 54,
                              height: 54,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: accent.withValues(
                                    alpha: 0.55 * (1 - ping),
                                  ),
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ),
                      Container(
                        width: 54,
                        height: 54,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: accent,
                          shape: BoxShape.circle,
                          boxShadow: [
                            ...AppColors.glow(
                              accent,
                              blurRadius: 32 + 14 * flare,
                              alpha: 0.55 + 0.25 * flare,
                              isDark: isDark,
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.5),
                              blurRadius: 28,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Transform.scale(
                          scale: iconPop,
                          child: child,
                        ),
                      ),
                    ],
                  );
                },
                child: Icon(
                  widget.icon,
                  size: 26,
                  weight: 500,
                  color: AppColors.getOnAccent(isDark),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
