import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../design_system.dart';

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

/// An animated donut chart for category spending breakdowns.
///
/// The sweep animation plays on mount and is restarted whenever [month]
/// changes. Tap a slice to select it — the center label updates to show
/// the slice detail. Tap the same slice again to deselect. Selection state
/// is owned by the caller via [selectedIndex] / [onSliceSelected].
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

  const CategoryDonutChart({
    super.key,
    required this.slices,
    required this.totalAmount,
    required this.selectedIndex,
    required this.onSliceSelected,
    required this.month,
  });

  @override
  State<CategoryDonutChart> createState() => _CategoryDonutChartState();
}

class _CategoryDonutChartState extends State<CategoryDonutChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _sweep;

  // Ring thickness constants
  static const double _baseRadius = 30.0;
  static const double _selectedRadius = 38.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AppAnimations.slow,
      vsync: this,
    );
    _sweep = CurvedAnimation(parent: _controller, curve: AppAnimations.easeOut);
    _controller.forward();
  }

  @override
  void didUpdateWidget(CategoryDonutChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Restart the sweep animation when the month changes
    if (oldWidget.month.year != widget.month.year ||
        oldWidget.month.month != widget.month.month) {
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Clamp diameter to a sensible range for phone / tablet widths
        final diameter = (constraints.maxWidth - AppDesign.spacingL * 2)
            .clamp(200.0, 280.0);

        // The center hole must comfortably contain the label column
        final centerRadius = diameter / 2 - 44;

        return SizedBox(
          height: diameter + AppDesign.spacingM * 2,
          child: Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Donut chart — wrapped in RepaintBoundary to isolate repaints
                RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: _sweep,
                    builder: (context, _) {
                      return SizedBox(
                        width: diameter,
                        height: diameter,
                        child: PieChart(
                          PieChartData(
                            sections: _buildSections(),
                            sectionsSpace: 2,
                            centerSpaceRadius: centerRadius,
                            pieTouchData: PieTouchData(
                              enabled: true,
                              touchCallback: _handleTouch,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Center label — does not intercept touch events
                IgnorePointer(
                  child: SizedBox(
                    width: diameter - 120,
                    child: _buildCenterLabel(context),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Section data
  // ---------------------------------------------------------------------------

  List<PieChartSectionData> _buildSections() {
    return widget.slices.asMap().entries.map((entry) {
      final idx = entry.key;
      final slice = entry.value;
      final isSelected = idx == widget.selectedIndex;

      return PieChartSectionData(
        value: slice.value * _sweep.value,
        color: slice.color,
        radius: isSelected ? _selectedRadius : _baseRadius,
        // Keep slices clean — no in-slice titles
        title: '',
        showTitle: false,
      );
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // Touch handling
  // ---------------------------------------------------------------------------

  void _handleTouch(FlTouchEvent event, PieTouchResponse? response) {
    // Only act on confirmed tap-up events to avoid spurious drag triggers
    if (event is! FlTapUpEvent) return;

    final touchedIndex = response?.touchedSection?.touchedSectionIndex ?? -1;

    if (touchedIndex < 0) {
      // Tapped empty space — clear selection if one exists
      if (widget.selectedIndex != -1) {
        HapticFeedback.selectionClick();
        widget.onSliceSelected(-1);
      }
      return;
    }

    if (touchedIndex == widget.selectedIndex) {
      // Tap selected slice again → toggle off
      HapticFeedback.selectionClick();
      widget.onSliceSelected(-1);
    } else {
      // Select a new slice
      HapticFeedback.selectionClick();
      widget.onSliceSelected(touchedIndex);
    }
  }

  // ---------------------------------------------------------------------------
  // Center label
  // ---------------------------------------------------------------------------

  Widget _buildCenterLabel(BuildContext context) {
    final moneyFmt = NumberFormat('#,##0.00', 'en_US');
    final isSliceSelected =
        widget.selectedIndex >= 0 && widget.selectedIndex < widget.slices.length;

    if (isSliceSelected) {
      final slice = widget.slices[widget.selectedIndex];
      final pct = widget.totalAmount > 0
          ? (slice.value / widget.totalAmount * 100)
          : 0.0;

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Slice label
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              slice.label,
              style: AppTypography.bodyMedium.copyWith(
                color: AppDesign.getTextSecondary(context),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: AppDesign.spacingXXS),
          // Slice amount
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '\$${moneyFmt.format(slice.value)}',
              style: AppTypography.numericMedium.copyWith(
                color: AppDesign.getTextPrimary(context),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: AppDesign.spacingXXS),
          // Percentage of total
          Text(
            '${pct.toStringAsFixed(1)}%',
            style: AppTypography.caption.copyWith(
              color: AppDesign.getTextSecondary(context),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    // No selection — show the month total
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Total',
          style: AppTypography.caption.copyWith(
            color: AppDesign.getTextSecondary(context),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppDesign.spacingXXS),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '\$${moneyFmt.format(widget.totalAmount)}',
            style: AppTypography.numericMedium.copyWith(
              color: AppDesign.getTextPrimary(context),
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
