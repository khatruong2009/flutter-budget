import 'dart:async';

import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';

import '../app_settings_provider.dart';
import '../design_system.dart';

/// Covers financial data whenever the app is backgrounded and, when enabled,
/// requires the device owner to authenticate after the configured timeout.
class AppPrivacyGate extends StatefulWidget {
  final Widget child;
  final LocalAuthentication? authentication;

  const AppPrivacyGate({
    super.key,
    required this.child,
    this.authentication,
  });

  @override
  State<AppPrivacyGate> createState() => _AppPrivacyGateState();
}

class _AppPrivacyGateState extends State<AppPrivacyGate>
    with WidgetsBindingObserver {
  late final LocalAuthentication _authentication =
      widget.authentication ?? LocalAuthentication();
  DateTime? _backgroundedAt;
  bool _locked = false;
  bool _obscured = false;
  bool _authenticating = false;
  bool _unsupported = false;
  bool? _previousLockEnabled;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final settings = context.read<AppSettingsProvider>();
      if (settings.appLockEnabled) {
        setState(() => _locked = true);
        unawaited(_unlock());
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _backgroundedAt ??= DateTime.now();
        if (mounted) setState(() => _obscured = true);
        return;
      case AppLifecycleState.resumed:
        final settings = context.read<AppSettingsProvider>();
        final backgroundedAt = _backgroundedAt;
        final elapsed = backgroundedAt == null
            ? Duration.zero
            : DateTime.now().difference(backgroundedAt);
        final shouldLock = settings.appLockEnabled &&
            elapsed.inSeconds >= settings.autoLockTimeoutSeconds;
        _backgroundedAt = null;
        if (!mounted) return;
        setState(() {
          _obscured = false;
          if (shouldLock) _locked = true;
        });
        if (shouldLock) unawaited(_unlock());
        return;
    }
  }

  Future<void> _unlock() async {
    if (_authenticating || !_locked) return;
    setState(() {
      _authenticating = true;
      _error = null;
      _unsupported = false;
    });
    try {
      final supported = await _authentication.isDeviceSupported();
      if (!supported) {
        throw StateError(
          'Set up a device passcode or biometrics to use App Lock.',
        );
      }
      final authenticated = await _authentication.authenticate(
        localizedReason: 'Unlock Budgie to view your financial data',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
          useErrorDialogs: true,
        ),
      );
      if (!mounted) return;
      setState(() {
        _locked = !authenticated;
        _error = authenticated ? null : 'Authentication was not completed.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _unsupported = error is StateError;
        _error = error is StateError
            ? error.message
            : 'Budgie could not authenticate on this device.';
      });
    } finally {
      if (mounted) setState(() => _authenticating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsProvider>();
    final wasEnabled = _previousLockEnabled;
    _previousLockEnabled = settings.appLockEnabled;
    if (settings.appLockEnabled && wasEnabled == false && !_locked) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _locked) return;
        setState(() => _locked = true);
        unawaited(_unlock());
      });
    }
    if (!settings.appLockEnabled && _locked) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _locked = false);
      });
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        AbsorbPointer(
          absorbing: _obscured || _locked,
          child: ExcludeSemantics(
            excluding: _obscured || _locked,
            child: widget.child,
          ),
        ),
        if (_obscured)
          const ColoredBox(color: AppColors.backgroundDark)
        else if (_locked)
          _LockScreen(
            authenticating: _authenticating,
            error: _error,
            unsupported: _unsupported,
            onUnlock: _unlock,
            onDisable: () async {
              await settings.setAppLockEnabled(false);
              if (mounted) {
                setState(() {
                  _locked = false;
                  _unsupported = false;
                });
              }
            },
          ),
      ],
    );
  }
}

class _LockScreen extends StatelessWidget {
  final bool authenticating;
  final String? error;
  final bool unsupported;
  final VoidCallback onUnlock;
  final Future<void> Function() onDisable;

  const _LockScreen({
    required this.authenticating,
    required this.error,
    required this.unsupported,
    required this.onUnlock,
    required this.onDisable,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: AppColors.getBackground(isDark),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppDesign.spacingXL),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lock_rounded,
                    size: 54,
                    color: AppColors.getAccent(isDark),
                  ),
                  const SizedBox(height: AppDesign.spacingL),
                  Text(
                    'Budgie is locked',
                    style: AppTypography.headingLarge.copyWith(
                      color: AppColors.getTextColor(isDark),
                    ),
                  ),
                  const SizedBox(height: AppDesign.spacingS),
                  Text(
                    error ?? 'Authenticate to view your financial data.',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyMedium.copyWith(
                      color: error == null
                          ? AppColors.getTextSecondaryColor(isDark)
                          : AppColors.getDanger(isDark),
                    ),
                  ),
                  const SizedBox(height: AppDesign.spacingL),
                  AppButton.primary(
                    label: authenticating ? 'Authenticating…' : 'Unlock',
                    icon: Icons.fingerprint_rounded,
                    isLoading: authenticating,
                    onPressed: authenticating ? null : onUnlock,
                  ),
                  if (unsupported) ...[
                    const SizedBox(height: AppDesign.spacingM),
                    AppButton.secondary(
                      label: 'Disable App Lock',
                      onPressed: () => unawaited(onDisable()),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
