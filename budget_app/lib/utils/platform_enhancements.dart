import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'platform_utils.dart';

/// Mixin that provides platform-specific enhancements to widgets
mixin PlatformEnhancements<T extends StatefulWidget> on State<T> {
  /// Handles keyboard shortcuts for desktop platforms
  void handleKeyboardShortcut(RawKeyEvent event) {
    if (!PlatformUtils.supportsKeyboardShortcuts) return;

    // Ctrl/Cmd + N: New transaction
    if (event.isControlPressed || event.isMetaPressed) {
      if (event.logicalKey == LogicalKeyboardKey.keyN) {
        onNewTransaction();
      }
      // Ctrl/Cmd + S: Save/Settings
      else if (event.logicalKey == LogicalKeyboardKey.keyS) {
        onSave();
      }
      // Ctrl/Cmd + F: Search/Filter
      else if (event.logicalKey == LogicalKeyboardKey.keyF) {
        onSearch();
      }
      // Ctrl/Cmd + W: Close
      else if (event.logicalKey == LogicalKeyboardKey.keyW) {
        onClose();
      }
    }
    // Escape: Cancel/Close
    else if (event.logicalKey == LogicalKeyboardKey.escape) {
      onCancel();
    }
  }

  /// Override these methods in your widget to handle shortcuts
  void onNewTransaction() {}
  void onSave() {}
  void onSearch() {}
  void onClose() {}
  void onCancel() {}

  /// Returns platform-appropriate scroll behavior
  ScrollBehavior getPlatformScrollBehavior() {
    if (PlatformUtils.isDesktop || PlatformUtils.isWeb) {
      return const MaterialScrollBehavior().copyWith(
        scrollbars: true,
        dragDevices: {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.trackpad,
        },
      );
    }
    return const MaterialScrollBehavior();
  }

  /// Returns platform-appropriate text selection controls
  TextSelectionControls getPlatformTextSelectionControls() {
    if (PlatformUtils.isIOS || PlatformUtils.isMacOS) {
      return cupertinoTextSelectionControls;
    }
    return materialTextSelectionControls;
  }
}

/// Platform-specific scroll behavior with visible scrollbars on desktop
class PlatformScrollBehavior extends MaterialScrollBehavior {
  const PlatformScrollBehavior();

  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) {
    if (PlatformUtils.isDesktop || PlatformUtils.isWeb) {
      return Scrollbar(
        controller: details.controller,
        thumbVisibility: false,
        trackVisibility: false,
        child: child,
      );
    }
    return child;
  }

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}

/// Platform-specific text field configuration
class PlatformTextFieldConfig {
  /// Returns appropriate keyboard type for amount input
  static TextInputType getAmountKeyboardType() {
    if (PlatformUtils.isIOS) {
      return const TextInputType.numberWithOptions(decimal: true, signed: false);
    }
    return TextInputType.number;
  }

  /// Returns appropriate text input action
  static TextInputAction getTextInputAction({bool isLastField = false}) {
    if (isLastField) {
      return TextInputAction.done;
    }
    return TextInputAction.next;
  }

  /// Returns appropriate autocorrect setting
  static bool shouldAutocorrect() {
    // Disable autocorrect for financial data
    return false;
  }

  /// Returns appropriate capitalization
  static TextCapitalization getCapitalization({bool isDescription = false}) {
    if (isDescription) {
      return TextCapitalization.sentences;
    }
    return TextCapitalization.none;
  }
}

/// Platform-specific animation configurations
class PlatformAnimationConfig {
  /// Returns appropriate animation duration based on platform
  static Duration getAnimationDuration({bool isShort = false}) {
    if (PlatformUtils.isWeb) {
      // Slightly faster animations on web
      return isShort ? const Duration(milliseconds: 120) : const Duration(milliseconds: 250);
    }
    return isShort ? const Duration(milliseconds: 150) : const Duration(milliseconds: 300);
  }

  /// Returns appropriate curve based on platform
  static Curve getAnimationCurve() {
    if (PlatformUtils.isIOS || PlatformUtils.isMacOS) {
      return Curves.easeInOut;
    }
    return Curves.fastOutSlowIn;
  }

  /// Checks if reduced motion is preferred
  static bool shouldReduceMotion(BuildContext context) {
    return MediaQuery.of(context).disableAnimations;
  }
}

/// Platform-specific UI constants
class PlatformUIConstants {
  /// Returns appropriate list tile height
  static double getListTileHeight() {
    if (PlatformUtils.isDesktop) {
      return 60; // Slightly smaller on desktop
    }
    return 72; // Standard mobile height
  }

  /// Returns appropriate button height
  static double getButtonHeight() {
    if (PlatformUtils.isDesktop) {
      return 40; // Smaller on desktop
    }
    return 48; // Larger touch target on mobile
  }

  /// Returns appropriate spacing multiplier
  static double getSpacingMultiplier() {
    if (PlatformUtils.isDesktop) {
      return 0.9; // Slightly tighter spacing on desktop
    }
    return 1.0;
  }

  /// Returns appropriate border radius
  static double getBorderRadius() {
    if (PlatformUtils.isIOS || PlatformUtils.isMacOS) {
      return 12; // More rounded on Apple platforms
    }
    return 8; // Standard Material radius
  }
}
