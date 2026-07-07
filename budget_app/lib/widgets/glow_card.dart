import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/micro_interactions.dart';

/// Signature card of the dark redesign: `#13131F` surface, 26px radius,
/// 1px white/7% border. Pressed state scales to 0.98 when [onTap] is set.
///
/// Use `radius: 22` for small stat chips and `padding: EdgeInsets.all(8)`
/// for list-style cards (see [GlowListCard]).
class GlowCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  /// Overrides the surface color (e.g. the completed-goal green tint).
  final Color? color;

  /// Overrides the border (e.g. green 30% on the completed goal card).
  final BoxBorder? border;

  /// Optional gradient background (e.g. Settings brand card).
  final Gradient? gradient;

  /// Optional glow/shadow around the card.
  final List<BoxShadow>? boxShadow;

  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const GlowCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 26,
    this.color,
    this.border,
    this.gradient,
    this.boxShadow,
    this.onTap,
    this.onLongPress,
  });

  @override
  State<GlowCard> createState() => _GlowCardState();
}

class _GlowCardState extends State<GlowCard> {
  bool _pressed = false;

  bool get _interactive => widget.onTap != null || widget.onLongPress != null;

  void _setPressed(bool value) {
    if (_interactive && _pressed != value) {
      setState(() => _pressed = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = widget.color ?? AppColors.getCard(isDark);

    Widget card = AnimatedScale(
      scale: _pressed ? 0.98 : 1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: Container(
        decoration: BoxDecoration(
          color: widget.gradient == null ? surface : null,
          gradient: widget.gradient,
          borderRadius: BorderRadius.circular(widget.radius),
          border: widget.border ??
              Border.all(color: AppColors.getCardBorder(isDark)),
          boxShadow: widget.boxShadow,
        ),
        padding: widget.padding,
        child: widget.child,
      ),
    );

    if (!_interactive) return card;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // Press feedback only for actual tap actions — a long-press-only card
      // must not suggest tappability on a quick tap.
      onTapDown: widget.onTap == null ? null : (_) => _setPressed(true),
      onTapUp: widget.onTap == null ? null : (_) => _setPressed(false),
      onTapCancel: widget.onTap == null ? null : () => _setPressed(false),
      onTap: widget.onTap == null
          ? null
          : () {
              MicroInteractions.lightImpact();
              widget.onTap!();
            },
      onLongPress: widget.onLongPress == null
          ? null
          : () {
              MicroInteractions.mediumImpact();
              widget.onLongPress!();
            },
      child: card,
    );
  }
}

/// List-style [GlowCard]: 8px outer padding with hairline dividers inset 12px
/// between children.
class GlowListCard extends StatelessWidget {
  final List<Widget> children;
  final double radius;

  const GlowListCard({super.key, required this.children, this.radius = 26});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GlowCard(
      radius: radius,
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < children.length; i++) ...[
            if (i > 0)
              Container(
                height: 1,
                margin: const EdgeInsets.symmetric(horizontal: 12),
                color: AppColors.getHairline(isDark),
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Tinted rounded-square icon container: category color at 12–14% opacity.
/// 40×40 radius 14 by default; use `size: 44` (radius 16) on Net Worth rows.
class IconTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final double? radius;
  final double iconSize;

  /// Overrides the tinted background (e.g. white/6% for the gray tail row).
  final Color? background;

  const IconTile({
    super.key,
    required this.icon,
    required this.color,
    this.size = 40,
    this.radius,
    this.iconSize = 20,
    this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background ?? color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(radius ?? (size >= 44 ? 16 : 14)),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: iconSize, color: color, weight: 500),
    );
  }
}
