import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'money_formatter.dart';
import 'storage/atomic_financial_store.dart';
import 'storage/storage_keys.dart';

class AppSettingsProvider extends ChangeNotifier {
  String _baseCurrencyCode = 'USD';
  String? _localeOverride;
  bool _appLockEnabled = false;
  int _autoLockTimeoutSeconds = 60;
  bool _hideBalances = false;
  bool _isLoaded = false;

  String get baseCurrencyCode => _baseCurrencyCode;
  String? get localeOverride => _localeOverride;
  bool get isLoaded => _isLoaded;
  bool get appLockEnabled => _appLockEnabled;
  int get autoLockTimeoutSeconds => _autoLockTimeoutSeconds;
  bool get hideBalances => _hideBalances;

  Locale? get locale {
    final value = _localeOverride;
    if (value == null || value.isEmpty) return null;
    final pieces = value.split(RegExp('[-_]'));
    return Locale(pieces.first, pieces.length > 1 ? pieces[1] : null);
  }

  Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    final snapshot = await AtomicFinancialStore.instance.read();
    final stored = snapshot.sections[FinancialSections.appSettings];
    final settings =
        stored is Map<String, dynamic> ? stored : const <String, dynamic>{};
    _baseCurrencyCode = settings['baseCurrencyCode'] as String? ??
        preferences.getString(StorageKeys.baseCurrencyCode) ??
        'USD';
    _localeOverride = settings['localeOverride'] as String? ??
        preferences.getString(StorageKeys.localeOverride);
    _appLockEnabled = settings['appLockEnabled'] as bool? ??
        preferences.getBool(StorageKeys.appLockEnabled) ??
        false;
    _autoLockTimeoutSeconds =
        (settings['autoLockTimeoutSeconds'] as num?)?.toInt() ??
            preferences.getInt(StorageKeys.autoLockTimeoutSeconds) ??
            60;
    _hideBalances = settings['hideBalances'] as bool? ??
        preferences.getBool(StorageKeys.hideBalances) ??
        false;
    _isLoaded = true;
    _syncFormatter();
    notifyListeners();
  }

  Future<void> setBaseCurrencyCode(String value) async {
    final normalized = value.trim().toUpperCase();
    if (normalized.length != 3 || normalized == _baseCurrencyCode) return;
    _baseCurrencyCode = normalized;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(StorageKeys.baseCurrencyCode, normalized);
    await _persistAtomic();
    _syncFormatter();
    notifyListeners();
  }

  Future<void> setLocaleOverride(String? value) async {
    final normalized = value?.trim();
    _localeOverride =
        normalized == null || normalized.isEmpty ? null : normalized;
    final preferences = await SharedPreferences.getInstance();
    if (_localeOverride == null) {
      await preferences.remove(StorageKeys.localeOverride);
    } else {
      await preferences.setString(StorageKeys.localeOverride, _localeOverride!);
    }
    await _persistAtomic();
    _syncFormatter();
    notifyListeners();
  }

  Future<void> setAppLockEnabled(bool value) async {
    if (_appLockEnabled == value) return;
    _appLockEnabled = value;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(StorageKeys.appLockEnabled, value);
    await _persistAtomic();
    notifyListeners();
  }

  Future<void> setAutoLockTimeoutSeconds(int value) async {
    if (value < 0 || _autoLockTimeoutSeconds == value) return;
    _autoLockTimeoutSeconds = value;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(StorageKeys.autoLockTimeoutSeconds, value);
    await _persistAtomic();
    notifyListeners();
  }

  Future<void> setHideBalances(bool value) async {
    if (_hideBalances == value) return;
    _hideBalances = value;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(StorageKeys.hideBalances, value);
    await _persistAtomic();
    _syncFormatter();
    notifyListeners();
  }

  Future<void> restoreFromBackup({
    required String baseCurrencyCode,
    required String? localeOverride,
    required bool appLockEnabled,
    required int autoLockTimeoutSeconds,
    required bool hideBalances,
  }) async {
    final currency = baseCurrencyCode.trim().toUpperCase();
    if (currency.length != 3 || autoLockTimeoutSeconds < 0) {
      throw const FormatException('Backup contains invalid app settings');
    }
    _baseCurrencyCode = currency;
    _localeOverride = localeOverride == null || localeOverride.trim().isEmpty
        ? null
        : localeOverride.trim();
    _appLockEnabled = appLockEnabled;
    _autoLockTimeoutSeconds = autoLockTimeoutSeconds;
    _hideBalances = hideBalances;

    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(StorageKeys.baseCurrencyCode, currency);
    if (_localeOverride == null) {
      await preferences.remove(StorageKeys.localeOverride);
    } else {
      await preferences.setString(StorageKeys.localeOverride, _localeOverride!);
    }
    await preferences.setBool(StorageKeys.appLockEnabled, _appLockEnabled);
    await preferences.setInt(
      StorageKeys.autoLockTimeoutSeconds,
      _autoLockTimeoutSeconds,
    );
    await preferences.setBool(StorageKeys.hideBalances, _hideBalances);
    await _persistAtomic();
    _isLoaded = true;
    _syncFormatter();
    notifyListeners();
  }

  void _syncFormatter() {
    MoneyFormatter.configure(
      currencyCode: _baseCurrencyCode,
      locale: _localeOverride,
      hideBalances: _hideBalances,
    );
  }

  Future<void> _persistAtomic() {
    return AtomicFinancialStore.instance.updateSection(
      FinancialSections.appSettings,
      <String, dynamic>{
        'baseCurrencyCode': _baseCurrencyCode,
        'localeOverride': _localeOverride,
        'appLockEnabled': _appLockEnabled,
        'autoLockTimeoutSeconds': _autoLockTimeoutSeconds,
        'hideBalances': _hideBalances,
      },
    );
  }
}
