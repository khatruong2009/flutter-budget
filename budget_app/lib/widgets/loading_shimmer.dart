import 'package:flutter/material.dart';
import '../design_system.dart';
import '../utils/accessibility_utils.dart';

/// LoadingShimmer is a reusable component for displaying loading states
/// with an animated shimmer effect that provides visual feedback while
/// content is being loaded.
/// 
/// Supports different skeleton layouts for various content types:
/// - list: For list items with icon and text
/// - card: For card-based content
/// - text: For text-only content
/// - custom: For custom skeleton layouts
class LoadingShimmer extends StatefulWidget {
  /// The type of skeleton layout to display
  final ShimmerType type;
  
  /// Number of skeleton items to display (for list/card types)
  final int itemCount;
  
  /// Optional custom child widget for custom skeleton layouts
  final Widget? child;
  
  /// Optional height for the shimmer container
  final double? height;
  
  /// Optional width for the shimmer container
  final double? width;
  
  /// Whether to show the shimmer animation (default: true)
  final bool enabled;
  
  /// Base color for the shimmer effect
  final Color? baseColor;
  
  /// Highlight color for the shimmer effect
  final Color? highlightColor;

  const LoadingShimmer({
    super.key,
    required this.type,
    this.itemCount = 3,
    this.child,
    this.height,
    this.width,
    this.enabled = true,
    this.baseColor,
    this.highlightColor,
  });

  /// Factory constructor for list skeleton
  factory LoadingShimmer.list({
    int itemCount = 3,
    bool enabled = true,
  }) {
    return LoadingShimmer(
      type: ShimmerType.list,
      itemCount: itemCount,
      enabled: enabled,
    );
  }

  /// Factory constructor for card skeleton
  factory LoadingShimmer.card({
    int itemCount = 2,
    bool enabled = true,
  }) {
    return LoadingShimmer(
      type: ShimmerType.card,
      itemCount: itemCount,
      enabled: enabled,
    );
  }

  /// Factory constructor for text skeleton
  factory LoadingShimmer.text({
    int itemCount = 3,
    bool enabled = true,
  }) {
    return LoadingShimmer(
      type: ShimmerType.text,
      itemCount: itemCount,
      enabled: enabled,
    );
  }

  /// Factory constructor for custom skeleton
  factory LoadingShimmer.custom({
    required Widget child,
    double? height,
    double? width,
    bool enabled = true,
  }) {
    return LoadingShimmer(
      type: ShimmerType.custom,
      child: child,
      height: height,
      width: width,
      enabled: enabled,
    );
  }

  @override
  State<LoadingShimmer> createState() => _LoadingShimmerState();
}

class _LoadingShimmerState extends State<LoadingShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AppAnimations.shimmerDuration,
      vsync: this,
    );
    
    _animation = Tween<double>(
      begin: -2.0,
      end: 2.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: AppAnimations.shimmerCurve,
    ));

    if (widget.enabled) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(LoadingShimmer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled != oldWidget.enabled) {
      if (widget.enabled) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.child ?? const SizedBox.shrink();
    }

    // Add semantic label for screen readers
    final semanticLabel = AccessibilityUtils.formatLoadingStateForScreenReader(null);

    // Wrap in RepaintBoundary to optimize animation performance
    return Semantics(
      label: semanticLabel,
      liveRegion: true,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return ExcludeSemantics(
              // Exclude shimmer boxes from semantics tree
              child: _buildShimmerContent(context),
            );
          },
        ),
      ),
    );
  }

  Widget _buildShimmerContent(BuildContext context) {
    switch (widget.type) {
      case ShimmerType.list:
        return _buildListSkeleton(context);
      case ShimmerType.card:
        return _buildCardSkeleton(context);
      case ShimmerType.text:
        return _buildTextSkeleton(context);
      case ShimmerType.custom:
        return _buildCustomSkeleton(context);
    }
  }

  Widget _buildListSkeleton(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: widget.itemCount,
      separatorBuilder: (context, index) => const SizedBox(height: AppDesign.spacingM),
      itemBuilder: (context, index) {
        return _ShimmerBox(
          animation: _animation,
          baseColor: widget.baseColor,
          highlightColor: widget.highlightColor,
          child: Padding(
            padding: const EdgeInsets.all(AppDesign.spacingM),
            child: Row(
              children: [
                // Icon placeholder
                _ShimmerBox(
                  animation: _animation,
                  baseColor: widget.baseColor,
                  highlightColor: widget.highlightColor,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _getBaseColor(context),
                      borderRadius: BorderRadius.circular(AppDesign.radiusM),
                    ),
                  ),
                ),
                const SizedBox(width: AppDesign.spacingM),
                // Text placeholders
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ShimmerBox(
                        animation: _animation,
                        baseColor: widget.baseColor,
                        highlightColor: widget.highlightColor,
                        child: Container(
                          height: 16,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: _getBaseColor(context),
                            borderRadius: BorderRadius.circular(AppDesign.radiusS),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppDesign.spacingS),
                      _ShimmerBox(
                        animation: _animation,
                        baseColor: widget.baseColor,
                        highlightColor: widget.highlightColor,
                        child: Container(
                          height: 12,
                          width: 120,
                          decoration: BoxDecoration(
                            color: _getBaseColor(context),
                            borderRadius: BorderRadius.circular(AppDesign.radiusS),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppDesign.spacingM),
                // Amount placeholder
                _ShimmerBox(
                  animation: _animation,
                  baseColor: widget.baseColor,
                  highlightColor: widget.highlightColor,
                  child: Container(
                    height: 20,
                    width: 80,
                    decoration: BoxDecoration(
                      color: _getBaseColor(context),
                      borderRadius: BorderRadius.circular(AppDesign.radiusS),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCardSkeleton(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: AppDesign.spacingM,
        mainAxisSpacing: AppDesign.spacingM,
        childAspectRatio: 1.5,
      ),
      itemCount: widget.itemCount,
      itemBuilder: (context, index) {
        return _ShimmerBox(
          animation: _animation,
          baseColor: widget.baseColor,
          highlightColor: widget.highlightColor,
          child: Container(
            padding: const EdgeInsets.all(AppDesign.spacingM),
            decoration: BoxDecoration(
              color: _getBaseColor(context),
              borderRadius: BorderRadius.circular(AppDesign.radiusL),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _ShimmerBox(
                      animation: _animation,
                      baseColor: widget.baseColor,
                      highlightColor: widget.highlightColor,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: _getHighlightColor(context),
                          borderRadius: BorderRadius.circular(AppDesign.radiusS),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppDesign.spacingS),
                    Expanded(
                      child: _ShimmerBox(
                        animation: _animation,
                        baseColor: widget.baseColor,
                        highlightColor: widget.highlightColor,
                        child: Container(
                          height: 12,
                          decoration: BoxDecoration(
                            color: _getHighlightColor(context),
                            borderRadius: BorderRadius.circular(AppDesign.radiusS),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                _ShimmerBox(
                  animation: _animation,
                  baseColor: widget.baseColor,
                  highlightColor: widget.highlightColor,
                  child: Container(
                    height: 24,
                    width: 100,
                    decoration: BoxDecoration(
                      color: _getHighlightColor(context),
                      borderRadius: BorderRadius.circular(AppDesign.radiusS),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTextSkeleton(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(widget.itemCount, (index) {
        final width = index == widget.itemCount - 1 ? 0.6 : 1.0;
        return Padding(
          padding: const EdgeInsets.only(bottom: AppDesign.spacingS),
          child: _ShimmerBox(
            animation: _animation,
            baseColor: widget.baseColor,
            highlightColor: widget.highlightColor,
            child: Container(
              height: 16,
              width: MediaQuery.of(context).size.width * width,
              decoration: BoxDecoration(
                color: _getBaseColor(context),
                borderRadius: BorderRadius.circular(AppDesign.radiusS),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildCustomSkeleton(BuildContext context) {
    return _ShimmerBox(
      animation: _animation,
      baseColor: widget.baseColor,
      highlightColor: widget.highlightColor,
      child: widget.child ?? const SizedBox.shrink(),
    );
  }

  Color _getBaseColor(BuildContext context) {
    if (widget.baseColor != null) return widget.baseColor!;
    
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.grey[800]!
        : Colors.grey[300]!;
  }

  Color _getHighlightColor(BuildContext context) {
    if (widget.highlightColor != null) return widget.highlightColor!;
    
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.grey[700]!
        : Colors.grey[100]!;
  }
}

/// Internal widget that applies the shimmer gradient effect
class _ShimmerBox extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;
  final Color? baseColor;
  final Color? highlightColor;

  const _ShimmerBox({
    required this.animation,
    required this.child,
    this.baseColor,
    this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBaseColor = baseColor ?? _getBaseColor(context);
    final effectiveHighlightColor = highlightColor ?? _getHighlightColor(context);

    // Wrap in RepaintBoundary to isolate shimmer repaints
    return RepaintBoundary(
      child: ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (bounds) {
          return LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              effectiveBaseColor,
              effectiveHighlightColor,
              effectiveBaseColor,
            ],
            stops: const [
              0.0,
              0.5,
              1.0,
            ],
            transform: _SlidingGradientTransform(slidePercent: animation.value),
          ).createShader(bounds);
        },
        child: child,
      ),
    );
  }

  Color _getBaseColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.grey[800]!
        : Colors.grey[300]!;
  }

  Color _getHighlightColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.grey[700]!
        : Colors.grey[100]!;
  }
}

/// Custom gradient transform for the sliding shimmer effect
class _SlidingGradientTransform extends GradientTransform {
  final double slidePercent;

  const _SlidingGradientTransform({
    required this.slidePercent,
  });

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * slidePercent, 0.0, 0.0);
  }
}

/// Enum defining the different types of shimmer skeletons
enum ShimmerType {
  /// List item skeleton with icon and text
  list,
  
  /// Card skeleton for metric cards
  card,
  
  /// Text-only skeleton
  text,
  
  /// Custom skeleton layout
  custom,
}

