import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../design_system.dart';

/// InteractiveWrapper enhances any widget with micro-interactions including:
/// - Haptic feedback on tap
/// - Hover states for desktop platforms
/// - Long press gesture handling
/// - Scale animations on press
/// - Optional custom feedback types
class InteractiveWrapper extends StatefulWidget {
  /// The child widget to wrap with interactions
  final Widget child;

  /// Callback when the widget is tapped
  final VoidCallback? onTap;

  /// Callback when the widget is long pressed
  final VoidCallback? onLongPress;

  /// Whether to enable haptic feedback on tap (default: true)
  final bool enableHapticFeedback;

  /// Type of haptic feedback to use (default: light)
  final HapticFeedbackType hapticType;

  /// Whether to enable hover effects on desktop (default: true)
  final bool enableHover;

  /// Whether to enable scale animation on press (default: true)
  final bool enableScaleAnimation;

  /// Scale factor when pressed (default: 0.95)
  final double pressedScale;

  /// Border radius for hover and ink effects
  final BorderRadius? borderRadius;

  /// Whether to show ink splash effect (default: true)
  final bool showInkSplash;

  /// Custom hover color (default: semi-transparent white/black)
  final Color? hoverColor;

  /// Duration for scale animation (default: AppAnimations.fast)
  final Duration? animationDuration;

  const InteractiveWrapper({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.enableHapticFeedback = true,
    this.hapticType = HapticFeedbackType.light,
    this.enableHover = true,
    this.enableScaleAnimation = true,
    this.pressedScale = 0.95,
    this.borderRadius,
    this.showInkSplash = true,
    this.hoverColor,
    this.animationDuration,
  });

  @override
  State<InteractiveWrapper> createState() => _InteractiveWrapperState();
}

class _InteractiveWrapperState extends State<InteractiveWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;
  bool _isHovering = false;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: widget.animationDuration ?? AppAnimations.fast,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.pressedScale,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: AppAnimations.easeOut,
    ));
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.onTap != null && widget.enableScaleAnimation) {
      _scaleController.forward();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (widget.onTap != null && widget.enableScaleAnimation) {
      _scaleController.reverse();
    }
  }

  void _handleTapCancel() {
    if (widget.onTap != null && widget.enableScaleAnimation) {
      _scaleController.reverse();
    }
  }

  Future<void> _handleTap() async {
    if (widget.onTap != null) {
      // Trigger haptic feedback
      if (widget.enableHapticFeedback) {
        await _triggerHapticFeedback();
      }
      
      // Call the tap callback
      widget.onTap!();
    }
  }

  Future<void> _handleLongPress() async {
    if (widget.onLongPress != null) {
      // Trigger medium haptic feedback for long press
      if (widget.enableHapticFeedback) {
        await MicroInteractions.mediumImpact();
      }
      
      // Call the long press callback
      widget.onLongPress!();
    }
  }

  Future<void> _triggerHapticFeedback() async {
    switch (widget.hapticType) {
      case HapticFeedbackType.light:
        await MicroInteractions.lightImpact();
        break;
      case HapticFeedbackType.medium:
        await MicroInteractions.mediumImpact();
        break;
      case HapticFeedbackType.heavy:
        await MicroInteractions.heavyImpact();
        break;
      case HapticFeedbackType.selection:
        await MicroInteractions.selectionClick();
        break;
    }
  }

  void _handleHoverEnter(PointerEnterEvent event) {
    if (widget.enableHover && MicroInteractions.shouldEnableHover()) {
      setState(() => _isHovering = true);
    }
  }

  void _handleHoverExit(PointerExitEvent event) {
    if (widget.enableHover && MicroInteractions.shouldEnableHover()) {
      setState(() => _isHovering = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget result = widget.child;

    // Wrap with scale animation if enabled
    if (widget.enableScaleAnimation) {
      // Wrap in RepaintBoundary to optimize animation performance
      result = RepaintBoundary(
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: result,
        ),
      );
    }

    // Wrap with Material and InkWell for tap effects
    if (widget.onTap != null || widget.onLongPress != null) {
      final effectiveBorderRadius = widget.borderRadius ?? BorderRadius.circular(AppDesign.radiusM);
      
      result = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap != null ? _handleTap : null,
          onLongPress: widget.onLongPress != null ? _handleLongPress : null,
          onTapDown: _handleTapDown,
          onTapUp: _handleTapUp,
          onTapCancel: _handleTapCancel,
          borderRadius: effectiveBorderRadius,
          splashColor: widget.showInkSplash ? null : Colors.transparent,
          highlightColor: widget.showInkSplash ? null : Colors.transparent,
          child: result,
        ),
      );
    }

    // Wrap with MouseRegion for hover effects on desktop
    if (widget.enableHover && MicroInteractions.shouldEnableHover()) {
      result = MouseRegion(
        onEnter: _handleHoverEnter,
        onExit: _handleHoverExit,
        cursor: (widget.onTap != null || widget.onLongPress != null)
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        child: AnimatedContainer(
          duration: AppAnimations.fast,
          decoration: BoxDecoration(
            color: _isHovering
                ? (widget.hoverColor ?? 
                   (Theme.of(context).brightness == Brightness.dark
                       ? Colors.white.withValues(alpha: 0.05)
                       : Colors.black.withValues(alpha: 0.03)))
                : Colors.transparent,
            borderRadius: widget.borderRadius ?? BorderRadius.circular(AppDesign.radiusM),
          ),
          child: result,
        ),
      );
    }

    return result;
  }
}

/// Types of haptic feedback available
enum HapticFeedbackType {
  /// Light impact for subtle interactions
  light,
  
  /// Medium impact for standard interactions
  medium,
  
  /// Heavy impact for significant interactions
  heavy,
  
  /// Selection click for picker/selector interactions
  selection,
}
