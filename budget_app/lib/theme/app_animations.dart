import 'package:flutter/material.dart';

/// AppAnimations defines the animation system for the application
/// including durations, curves, and common transition builders
class AppAnimations {
  // Animation Durations
  static const Duration instant = Duration(milliseconds: 0);
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);
  static const Duration verySlow = Duration(milliseconds: 800);

  // Animation Curves
  static const Curve easeIn = Curves.easeIn;
  static const Curve easeOut = Curves.easeOut;
  static const Curve easeInOut = Curves.easeInOut;
  static const Curve easeInOutCubic = Curves.easeInOutCubic;
  static const Curve spring = Curves.elasticOut;
  static const Curve bounce = Curves.bounceOut;
  static const Curve decelerate = Curves.decelerate;
  static const Curve fastOutSlowIn = Curves.fastOutSlowIn;

  // Page Transition Builders
  
  /// Slide transition from right to left
  static Widget slideTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(1.0, 0.0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: easeOut,
      )),
      child: child,
    );
  }

  /// Fade transition
  static Widget fadeTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: animation,
        curve: easeInOut,
      ),
      child: child,
    );
  }

  /// Scale transition
  static Widget scaleTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return ScaleTransition(
      scale: Tween<double>(
        begin: 0.8,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: easeOut,
      )),
      child: FadeTransition(
        opacity: animation,
        child: child,
      ),
    );
  }

  /// Slide and fade transition
  static Widget slideAndFadeTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0.0, 0.3),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: easeOut,
      )),
      child: FadeTransition(
        opacity: animation,
        child: child,
      ),
    );
  }

  // Shimmer Animation Configuration
  static const Duration shimmerDuration = Duration(milliseconds: 1500);
  static const Curve shimmerCurve = Curves.easeInOut;

  // List Animation Configuration
  static const Duration listItemDelay = Duration(milliseconds: 50);
  static const Duration listItemDuration = Duration(milliseconds: 300);

  // Button Press Animation
  static const Duration buttonPressDuration = Duration(milliseconds: 100);
  static const double buttonPressScale = 0.95;

  // Chart Animation Configuration
  static const Duration chartAnimationDuration = Duration(milliseconds: 1200);
  static const Curve chartAnimationCurve = Curves.easeInOutCubic;

  // Micro-interaction Durations
  static const Duration hoverDuration = Duration(milliseconds: 200);
  static const Duration rippleDuration = Duration(milliseconds: 300);
  static const Duration tooltipDuration = Duration(milliseconds: 150);

  // Helper method to create a delayed animation
  static Animation<double> createDelayedAnimation({
    required AnimationController controller,
    required Duration delay,
    Curve curve = Curves.easeOut,
  }) {
    final delaySeconds = delay.inMilliseconds / controller.duration!.inMilliseconds;
    return CurvedAnimation(
      parent: controller,
      curve: Interval(
        delaySeconds,
        1.0,
        curve: curve,
      ),
    );
  }

  // Helper method to create staggered list animations
  static Animation<double> createStaggeredAnimation({
    required AnimationController controller,
    required int index,
    required int totalItems,
    Curve curve = Curves.easeOut,
  }) {
    const staggerDelay = 0.05; // 5% delay between items
    final start = (index * staggerDelay).clamp(0.0, 0.5);
    final end = (start + 0.5).clamp(0.0, 1.0);
    
    return CurvedAnimation(
      parent: controller,
      curve: Interval(
        start,
        end,
        curve: curve,
      ),
    );
  }
}
