import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../money_formatter.dart';
import 'pill_chip.dart';

/// Data class representing a single slice in the donut chart.
class CategorySlice {
  final String label;
  final double value;
  final Color color;

  const CategorySlice({
    required this.label,
    required this.value,
    required this.color,
  });
}

/// Conic donut hero for the Categories tab: hard-stop segments separated by
/// thin dark gaps (~0.5% of the circle), accent-tinted drop shadow, animated
/// sweep on mount and month change. Tap a slice to select it; tap again (or
/// tap empty space) to deselect. Selection state is owned by the caller via
/// [selectedIndex] / [onSliceSelected].
class CategoryDonutChart extends StatefulWidget {
  /// Slices to render. Values must be > 0 and already ordered by the caller.
  final List<CategorySlice> slices;

  /// Full month total used to compute percentage labels. May exceed the
  /// sum of [slices] when the caller groups smaller categories.
  final double totalAmount;

  /// Index of the currently selected slice, or -1 for no selection.
  final int selectedIndex;

  /// Called when the user taps a slice (passes its index) or deselects
  /// (passes -1). The parent is responsible for updating [selectedIndex].
  final ValueChanged<int> onSliceSelected;

  /// When this changes (by year + month), the sweep animation restarts.
  final DateTime month;

  /// Prior month's total spend; null hides the delta pill (no prior data).
  final double? previousMonthTotal;

  /// Short label for the prior month, e.g. "June" (used in the delta pill).
  final String previousMonthLabel;

  /// Diameter of the donut (design: 240).
  final double size;

  const CategoryDonutChart({
    super.key,
    required this.slices,
    required this.totalAmount,
    required this.selectedIndex,
    required this.onSliceSelected,
    required this.month,
    this.previousMonthTotal,
    this.previousMonthLabel = '',
    this.size = 240,
  });

  @override
  State<CategoryDonutChart> createState() => _CategoryDonutChartState();
}

class _CategoryDonutChartState extends State<CategoryDonutChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _sweep;
  bool _sweepStarted = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _sweep = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // MediaQuery is not available in initState; start the entry sweep here.
    if (!_sweepStarted) {
      _sweepStarted = true;
      if (MediaQuery.disableAnimationsOf(context)) {
        _controller.value = 1.0;
      } else {
        _controller.forward();
      }
    }
  }

  @override
  void didUpdateWidget(CategoryDonutChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Restart the sweep animation when the month changes.
    if (oldWidget.month.year != widget.month.year ||
        oldWidget.month.month != widget.month.month) {
      _controller.reset();
      if (MediaQuery.disableAnimationsOf(context)) {
        _controller.value = 1.0;
      } else {
        _controller.forward();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapUp(TapUpDetails details, bool isDark) {
    final index = _hitTest(details.localPosition);
    if (index < 0) {
      if (widget.selectedIndex != -1) {
        HapticFeedback.selectionClick();
        widget.onSliceSelected(-1);
      }
      return;
    }
    HapticFeedback.selectionClick();
    if (index == widget.selectedIndex) {
      widget.onSliceSelected(-1);
    } else {
      widget.onSliceSelected(index);
    }
  }

  /// Hit-tests a tap point against the ring geometry (annulus between the
  /// center hole and the outer edge), returning the slice index or -1.
  int _hitTest(Offset localPosition) {
    final center = Offset(widget.size / 2, widget.size / 2);
    final outerRadius = widget.size / 2;
    final centerHole = outerRadius - _ringThickness;
    final dx = localPosition.dx - center.dx;
    final dy = localPosition.dy - center.dy;
    final distance = math.sqrt(dx * dx + dy * dy);
    if (distance < centerHole || distance > outerRadius) return -1;

    final total = widget.slices.fold(0.0, (sum, s) => sum + s.value);
    if (total <= 0) return -1;

    // Angle measured clockwise from 12 o'clock (matches the painter).
    var angle = math.atan2(dy, dx) + math.pi / 2;
    if (angle < 0) angle += 2 * math.pi;
    final fraction = angle / (2 * math.pi);

    double cursor = 0;
    for (int i = 0; i < widget.slices.length; i++) {
      final share = widget.slices[i].value / total;
      if (fraction >= cursor && fraction < cursor + share) {
        return i;
      }
      cursor += share;
    }
    return -1;
  }

  static const double _ringThickness = 30;
  static const double _gapFraction = 0.005; // ~0.5% dark gap between slices

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = AppColors.getAccent(isDark);
    final background = AppColors.getBackground(isDark);

    return GestureDetector(
      onTapUp: (details) => _handleTapUp(details, isDark),
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _sweep,
          builder: (context, _) {
            return Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: AppColors.glow(accent,
                    blurRadius: 24, alpha: 0.25, isDark: isDark),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: Size(widget.size, widget.size),
                    painter: _DonutPainter(
                      slices: widget.slices,
                      sweep: _sweep.value,
                      selectedIndex: widget.selectedIndex,
                      backgroundColor: background,
                      thickness: _ringThickness,
                      gapFraction: _gapFraction,
                    ),
                  ),
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.all(_ringThickness + 8),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: background,
                          shape: BoxShape.circle,
                        ),
                        child: IgnorePointer(
                          // The inner disc gives tight constraints, so the
                          // label column must be explicitly centered.
                          child: Center(
                            child: _CenterLabel(
                              slices: widget.slices,
                              totalAmount: widget.totalAmount,
                              selectedIndex: widget.selectedIndex,
                              previousMonthTotal: widget.previousMonthTotal,
                              previousMonthLabel: widget.previousMonthLabel,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<CategorySlice> slices;
  final double sweep;
  final int selectedIndex;
  final Color backgroundColor;
  final double thickness;
  final double gapFraction;

  _DonutPainter({
    required this.slices,
    required this.sweep,
    required this.selectedIndex,
    required this.backgroundColor,
    required this.thickness,
    required this.gapFraction,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final total = slices.fold(0.0, (sum, s) => sum + s.value);
    if (total <= 0) return;

    final center = size.center(Offset.zero);
    final outerRadius = size.shortestSide / 2;
    final baseRect = Rect.fromCircle(
      center: center,
      radius: outerRadius - thickness / 2,
    );
    final selectedRect = Rect.fromCircle(
      center: center,
      radius: outerRadius - thickness / 2 - 3,
    );

    const startAngle = -math.pi / 2; // 12 o'clock
    final gapAngle = 2 * math.pi * gapFraction;

    double cursor = 0;
    for (int i = 0; i < slices.length; i++) {
      final slice = slices[i];
      final share = slice.value / total;
      final sweepAngle = 2 * math.pi * share * sweep;
      final isSelected = i == selectedIndex;

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? thickness + 6 : thickness
        ..strokeCap = StrokeCap.butt
        ..color = slice.color;

      final drawSweep = math.max(sweepAngle - gapAngle, 0.0);
      if (drawSweep > 0) {
        canvas.drawArc(
          isSelected ? selectedRect : baseRect,
          startAngle + 2 * math.pi * cursor,
          drawSweep,
          false,
          paint,
        );
      }
      cursor += share * sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) {
    return oldDelegate.slices != slices ||
        oldDelegate.sweep != sweep ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.thickness != thickness;
  }
}

class _CenterLabel extends StatelessWidget {
  final List<CategorySlice> slices;
  final double totalAmount;
  final int selectedIndex;
  final double? previousMonthTotal;
  final String previousMonthLabel;

  const _CenterLabel({
    required this.slices,
    required this.totalAmount,
    required this.selectedIndex,
    this.previousMonthTotal,
    this.previousMonthLabel = '',
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSliceSelected = selectedIndex >= 0 && selectedIndex < slices.length;

    if (isSliceSelected) {
      final slice = slices[selectedIndex];
      final pct = totalAmount > 0 ? (slice.value / totalAmount * 100) : 0.0;

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                slice.label.toUpperCase(),
                style: AppTypography.eyebrow.copyWith(
                  color: AppColors.getTextSecondaryColor(isDark),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                _formatWhole(slice.value),
                style: AppTypography.heroSmall.copyWith(
                  color: AppColors.getTextColor(isDark),
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${pct.toStringAsFixed(0)}%',
              style: AppTypography.rowSubtitle.copyWith(
                color: AppColors.getTextSecondaryColor(isDark),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'SPENT',
          style: AppTypography.eyebrow.copyWith(
            color: AppColors.getTextSecondaryColor(isDark),
          ),
        ),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            _formatWhole(totalAmount),
            style: AppTypography.heroSmall.copyWith(
              color: AppColors.getTextColor(isDark),
            ),
            textAlign: TextAlign.center,
          ),
        ),
        if (_deltaPct != null) ...[
          const SizedBox(height: 6),
          _buildDeltaPill(context, isDark, _deltaPct!),
        ],
      ],
    );
  }

  /// Percent change vs. the previous month (positive = spending increased),
  /// or null when there is no prior-month data to compare against.
  double? get _deltaPct {
    final prev = previousMonthTotal;
    if (prev == null || prev == 0.0) return null;
    return (totalAmount - prev) / prev * 100;
  }

  Widget _buildDeltaPill(BuildContext context, bool isDark, double pct) {
    // Deltas below display resolution are neutral — never render an
    // alarm-colored "0%" pill (matches the pre-redesign threshold).
    final isNeutral = pct.abs() < 0.5;
    final color = isNeutral
        ? AppColors.getTextSecondaryColor(isDark)
        : pct > 0
            ? AppColors.getDanger(isDark)
            : AppColors.getIncome(isDark);
    final icon = isNeutral
        ? Symbols.remove_rounded
        : pct > 0
            ? Symbols.north_east_rounded
            : Symbols.south_west_rounded;
    final monthWord =
        previousMonthLabel.isEmpty ? 'last month' : previousMonthLabel;

    return PillChip(
      label: '${pct.abs().toStringAsFixed(0)}% vs $monthWord',
      color: color,
      icon: icon,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      textStyle: AppTypography.badge.copyWith(fontSize: 12),
    );
  }

  String _formatWhole(double value) {
    return MoneyFormatter.format(value, decimalDigits: 0);
  }
}
