import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

/// Platform-specific utilities for handling cross-platform UI differences
class PlatformUtils {
  /// Checks if the current platform is iOS
  static bool get isIOS {
    if (kIsWeb) return false;
    try {
      return Platform.isIOS;
    } catch (e) {
      return false;
    }
  }

  /// Checks if the current platform is Android
  static bool get isAndroid {
    if (kIsWeb) return false;
    try {
      return Platform.isAndroid;
    } catch (e) {
      return false;
    }
  }

  /// Checks if the current platform is macOS
  static bool get isMacOS {
    if (kIsWeb) return false;
    try {
      return Platform.isMacOS;
    } catch (e) {
      return false;
    }
  }

  /// Checks if the current platform is Windows
  static bool get isWindows {
    if (kIsWeb) return false;
    try {
      return Platform.isWindows;
    } catch (e) {
      return false;
    }
  }

  /// Checks if the current platform is Linux
  static bool get isLinux {
    if (kIsWeb) return false;
    try {
      return Platform.isLinux;
    } catch (e) {
      return false;
    }
  }

  /// Checks if the current platform is web
  static bool get isWeb => kIsWeb;

  /// Checks if the current platform is mobile (iOS or Android)
  static bool get isMobile => isIOS || isAndroid;

  /// Checks if the current platform is desktop (macOS, Windows, or Linux)
  static bool get isDesktop => isMacOS || isWindows || isLinux;

  /// Returns the appropriate dialog for the platform
  static Future<T?> showPlatformDialog<T>({
    required BuildContext context,
    required String title,
    required String content,
    String? confirmText,
    String? cancelText,
    bool isDestructive = false,
  }) {
    if (isIOS || isMacOS) {
      return showCupertinoDialog<T>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            if (cancelText != null)
              CupertinoDialogAction(
                child: Text(cancelText),
                onPressed: () => Navigator.of(context).pop(false as T),
              ),
            if (confirmText != null)
              CupertinoDialogAction(
                isDestructiveAction: isDestructive,
                child: Text(confirmText),
                onPressed: () => Navigator.of(context).pop(true as T),
              ),
          ],
        ),
      );
    } else {
      return showDialog<T>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            if (cancelText != null)
              TextButton(
                child: Text(cancelText),
                onPressed: () => Navigator.of(context).pop(false as T),
              ),
            if (confirmText != null)
              TextButton(
                style: isDestructive
                    ? TextButton.styleFrom(
                        foregroundColor: Colors.red,
                      )
                    : null,
                child: Text(confirmText),
                onPressed: () => Navigator.of(context).pop(true as T),
              ),
          ],
        ),
      );
    }
  }

  /// Returns platform-appropriate button widget
  static Widget platformButton({
    required String label,
    required VoidCallback? onPressed,
    bool isPrimary = true,
    IconData? icon,
  }) {
    if (isIOS || isMacOS) {
      return CupertinoButton(
        onPressed: onPressed,
        color: isPrimary ? CupertinoColors.activeBlue : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20),
              const SizedBox(width: 8),
            ],
            Text(label),
          ],
        ),
      );
    } else {
      if (isPrimary) {
        return ElevatedButton.icon(
          onPressed: onPressed,
          icon: icon != null ? Icon(icon) : const SizedBox.shrink(),
          label: Text(label),
        );
      } else {
        return OutlinedButton.icon(
          onPressed: onPressed,
          icon: icon != null ? Icon(icon) : const SizedBox.shrink(),
          label: Text(label),
        );
      }
    }
  }

  /// Returns platform-appropriate switch widget
  static Widget platformSwitch({
    required bool value,
    required ValueChanged<bool> onChanged,
    Color? activeColor,
  }) {
    if (isIOS || isMacOS) {
      return CupertinoSwitch(
        value: value,
        onChanged: onChanged,
        activeColor: activeColor,
      );
    } else {
      return Switch(
        value: value,
        onChanged: onChanged,
        activeColor: activeColor,
      );
    }
  }

  /// Returns platform-appropriate loading indicator
  static Widget platformLoadingIndicator({
    Color? color,
    double? size,
  }) {
    if (isIOS || isMacOS) {
      return CupertinoActivityIndicator(
        color: color,
        radius: size != null ? size / 2 : 10,
      );
    } else {
      return SizedBox(
        width: size ?? 20,
        height: size ?? 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: color != null ? AlwaysStoppedAnimation(color) : null,
        ),
      );
    }
  }

  /// Returns platform-appropriate scroll physics
  static ScrollPhysics get platformScrollPhysics {
    if (isIOS || isMacOS) {
      return const BouncingScrollPhysics();
    } else {
      return const ClampingScrollPhysics();
    }
  }

  /// Returns platform-appropriate page route
  static PageRoute<T> platformPageRoute<T>({
    required WidgetBuilder builder,
    RouteSettings? settings,
  }) {
    if (isIOS || isMacOS) {
      return CupertinoPageRoute<T>(
        builder: builder,
        settings: settings,
      );
    } else {
      return MaterialPageRoute<T>(
        builder: builder,
        settings: settings,
      );
    }
  }

  /// Returns appropriate padding for safe areas based on platform
  static EdgeInsets getPlatformPadding(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    
    if (isMobile) {
      // Mobile devices need safe area padding
      return EdgeInsets.only(
        top: mediaQuery.padding.top,
        bottom: mediaQuery.padding.bottom,
      );
    } else if (isWeb) {
      // Web needs responsive padding based on screen width
      final width = mediaQuery.size.width;
      if (width > 1200) {
        return const EdgeInsets.symmetric(horizontal: 120);
      } else if (width > 800) {
        return const EdgeInsets.symmetric(horizontal: 60);
      } else {
        return const EdgeInsets.symmetric(horizontal: 20);
      }
    } else {
      // Desktop platforms
      return const EdgeInsets.all(20);
    }
  }

  /// Returns appropriate content width for the platform
  static double getMaxContentWidth(BuildContext context) {
    if (isWeb) {
      final width = MediaQuery.of(context).size.width;
      if (width > 1400) return 1200;
      if (width > 1000) return 900;
      return width * 0.9;
    } else if (isDesktop) {
      return 800;
    } else {
      return double.infinity;
    }
  }

  /// Returns whether keyboard shortcuts should be enabled
  static bool get supportsKeyboardShortcuts => isDesktop || isWeb;

  /// Returns whether hover effects should be shown
  static bool get supportsHover => isDesktop || isWeb;

  /// Returns appropriate icon size for platform
  static double getIconSize(BuildContext context) {
    if (isMobile) {
      return 24;
    } else {
      return 20; // Slightly smaller on desktop
    }
  }

  /// Returns appropriate font scale for platform
  static double getFontScale(BuildContext context) {
    if (isWeb) {
      final width = MediaQuery.of(context).size.width;
      if (width < 600) return 0.9; // Smaller on mobile web
      return 1.0;
    }
    return 1.0;
  }
}
