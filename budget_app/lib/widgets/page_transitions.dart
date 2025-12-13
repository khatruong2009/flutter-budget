import 'package:flutter/material.dart';
import '../design_system.dart';

/// Custom page route with slide transition animation
class SlidePageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  final AxisDirection direction;

  SlidePageRoute({
    required this.page,
    this.direction = AxisDirection.left,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            Offset begin;
            switch (direction) {
              case AxisDirection.up:
                begin = const Offset(0.0, 1.0);
                break;
              case AxisDirection.down:
                begin = const Offset(0.0, -1.0);
                break;
              case AxisDirection.left:
                begin = const Offset(1.0, 0.0);
                break;
              case AxisDirection.right:
                begin = const Offset(-1.0, 0.0);
                break;
            }

            const end = Offset.zero;

            final tween = Tween(begin: begin, end: end);
            final curvedAnimation = CurvedAnimation(
              parent: animation,
              curve: AppAnimations.easeOut,
            );

            // Wrap in RepaintBoundary to optimize animation performance
            return RepaintBoundary(
              child: SlideTransition(
                position: tween.animate(curvedAnimation),
                child: child,
              ),
            );
          },
          transitionDuration: AppAnimations.normal,
        );
}

/// Custom page route with fade transition animation
class FadePageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  FadePageRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // Wrap in RepaintBoundary to optimize animation performance
            return RepaintBoundary(
              child: FadeTransition(
                opacity: CurvedAnimation(
                  parent: animation,
                  curve: AppAnimations.easeInOut,
                ),
                child: child,
              ),
            );
          },
          transitionDuration: AppAnimations.normal,
        );
}

/// Custom page route with scale transition animation
class ScalePageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  ScalePageRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // Wrap in RepaintBoundary to optimize animation performance
            return RepaintBoundary(
              child: ScaleTransition(
                scale: Tween<double>(
                  begin: 0.8,
                  end: 1.0,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: AppAnimations.easeOut,
                  ),
                ),
                child: FadeTransition(
                  opacity: animation,
                  child: child,
                ),
              ),
            );
          },
          transitionDuration: AppAnimations.normal,
        );
}

/// Custom page route with slide and fade transition animation
class SlideAndFadePageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  final AxisDirection direction;

  SlideAndFadePageRoute({
    required this.page,
    this.direction = AxisDirection.left,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            Offset begin;
            switch (direction) {
              case AxisDirection.up:
                begin = const Offset(0.0, 0.3);
                break;
              case AxisDirection.down:
                begin = const Offset(0.0, -0.3);
                break;
              case AxisDirection.left:
                begin = const Offset(0.3, 0.0);
                break;
              case AxisDirection.right:
                begin = const Offset(-0.3, 0.0);
                break;
            }

            const end = Offset.zero;

            final tween = Tween(begin: begin, end: end);
            final curvedAnimation = CurvedAnimation(
              parent: animation,
              curve: AppAnimations.easeOut,
            );

            // Wrap in RepaintBoundary to optimize animation performance
            return RepaintBoundary(
              child: SlideTransition(
                position: tween.animate(curvedAnimation),
                child: FadeTransition(
                  opacity: animation,
                  child: child,
                ),
              ),
            );
          },
          transitionDuration: AppAnimations.normal,
        );
}

/// Helper extension for easy navigation with custom transitions
extension NavigationExtensions on BuildContext {
  /// Navigate to a page with slide transition
  Future<T?> pushWithSlide<T>(Widget page, {AxisDirection direction = AxisDirection.left}) {
    return Navigator.of(this).push<T>(
      SlidePageRoute(page: page, direction: direction),
    );
  }

  /// Navigate to a page with fade transition
  Future<T?> pushWithFade<T>(Widget page) {
    return Navigator.of(this).push<T>(
      FadePageRoute(page: page),
    );
  }

  /// Navigate to a page with scale transition
  Future<T?> pushWithScale<T>(Widget page) {
    return Navigator.of(this).push<T>(
      ScalePageRoute(page: page),
    );
  }

  /// Navigate to a page with slide and fade transition
  Future<T?> pushWithSlideAndFade<T>(Widget page, {AxisDirection direction = AxisDirection.left}) {
    return Navigator.of(this).push<T>(
      SlideAndFadePageRoute(page: page, direction: direction),
    );
  }

  /// Replace current page with slide transition
  Future<T?> replaceWithSlide<T>(Widget page, {AxisDirection direction = AxisDirection.left}) {
    return Navigator.of(this).pushReplacement<T, void>(
      SlidePageRoute(page: page, direction: direction),
    );
  }

  /// Replace current page with fade transition
  Future<T?> replaceWithFade<T>(Widget page) {
    return Navigator.of(this).pushReplacement<T, void>(
      FadePageRoute(page: page),
    );
  }
}
