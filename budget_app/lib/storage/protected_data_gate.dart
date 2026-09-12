import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../utils/platform_utils.dart';

/// Holds app initialization until the device's protected data is readable.
///
/// iOS may prewarm the app (run `main` in the background) before the device
/// has been unlocked after a reboot. In that state every file in the app
/// container is still encrypted: reads come back empty or fail, and any
/// write made from that empty view replaces the real data once the device
/// unlocks. The native side reports `isProtectedDataAvailable` and pushes a
/// message when it flips to true; this gate simply waits for it.
class ProtectedDataGate {
  ProtectedDataGate._();

  static const MethodChannel channel =
      MethodChannel('budget_app/protected_data');

  static Completer<void>? _available;

  /// Completes immediately on platforms without file protection, or once iOS
  /// reports that protected data can be read.
  static Future<void> waitUntilAvailable() async {
    if (kIsWeb || !PlatformUtils.isIOS) return;

    final completer = _available ??= Completer<void>();
    if (completer.isCompleted) return;

    channel.setMethodCallHandler((call) async {
      if (call.method == 'protectedDataDidBecomeAvailable' &&
          !completer.isCompleted) {
        completer.complete();
      }
    });

    bool available;
    try {
      available = await channel.invokeMethod<bool>('isAvailable') ?? true;
    } on MissingPluginException {
      // Native handler absent (stale binary during development): do not
      // block launch on a signal that will never arrive.
      available = true;
    } on PlatformException catch (error) {
      debugPrint('Protected data query failed, continuing: ${error.message}');
      available = true;
    }

    if (available) {
      if (!completer.isCompleted) completer.complete();
      return;
    }

    debugPrint(
      'Protected data unavailable (prewarmed or locked launch); '
      'deferring storage access until the device unlocks',
    );
    await completer.future;
  }

  @visibleForTesting
  static void resetForTesting() {
    _available = null;
  }
}
