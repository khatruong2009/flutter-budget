import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:io' show Platform;

/// MicroInteractions provides utility methods for enhancing user interactions
/// with haptic feedback, platform detection, and interaction helpers
class MicroInteractions {
  /// Triggers light haptic feedback for subtle interactions
  /// (e.g., button taps, selection changes)
  static Future<void> lightImpact() async {
    if (_isHapticSupported()) {
      await HapticFeedback.lightImpact();
    }
  }

  /// Triggers medium haptic feedback for standard interactions
  /// (e.g., confirmations, toggles)
  static Future<void> mediumImpact() async {
    if (_isHapticSupported()) {
      await HapticFeedback.mediumImpact();
    }
  }

  /// Triggers heavy haptic feedback for significant interactions
  /// (e.g., deletions, important actions)
  static Future<void> heavyImpact() async {
    if (_isHapticSupported()) {
      await HapticFeedback.heavyImpact();
    }
  }

  /// Triggers selection click feedback for picker/selector interactions
  /// (e.g., scrolling through options, chart interactions)
  static Future<void> selectionClick() async {
    if (_isHapticSupported()) {
      await HapticFeedback.selectionClick();
    }
  }

  /// Triggers vibration feedback for errors or warnings
  static Future<void> vibrate() async {
    if (_isHapticSupported()) {
      await HapticFeedback.vibrate();
    }
  }

  /// Checks if haptic feedback is supported on the current platform
  static bool _isHapticSupported() {
    // Haptic feedback is supported on iOS and Android
    // Web and desktop platforms don't support haptic feedback
    if (kIsWeb) return false;
    
    try {
      return Platform.isIOS || Platform.isAndroid;
    } catch (e) {
      // If Platform is not available (e.g., on web), return false
      return false;
    }
  }

  /// Checks if the current platform is desktop (macOS, Windows, Linux)
  static bool isDesktop() {
    if (kIsWeb) return false;
    
    try {
      return Platform.isMacOS || Platform.isWindows || Platform.isLinux;
    } catch (e) {
      return false;
    }
  }

  /// Checks if the current platform is mobile (iOS, Android)
  static bool isMobile() {
    if (kIsWeb) return false;
    
    try {
      return Platform.isIOS || Platform.isAndroid;
    } catch (e) {
      return false;
    }
  }

  /// Checks if the current platform is web
  static bool isWeb() {
    return kIsWeb;
  }

  /// Checks if hover interactions should be enabled
  /// (desktop and web platforms)
  static bool shouldEnableHover() {
    return isDesktop() || isWeb();
  }
}
