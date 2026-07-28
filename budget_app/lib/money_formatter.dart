import 'package:intl/intl.dart';

/// One formatting source for every monetary amount in Budgie.
///
/// It defaults to USD for backward compatibility. `AppSettingsProvider`
/// updates it once preferences have loaded.
class MoneyFormatter {
  MoneyFormatter._();

  static String _currencyCode = 'USD';
  static String? _locale;
  static bool _hideBalances = false;

  static String get currencyCode => _currencyCode;
  static String? get locale => _locale;
  static bool get hideBalances => _hideBalances;

  static void configure({
    required String currencyCode,
    String? locale,
    bool hideBalances = false,
  }) {
    _currencyCode = currencyCode;
    _locale = locale;
    _hideBalances = hideBalances;
  }

  static String format(
    num value, {
    int decimalDigits = 2,
    bool compact = false,
  }) {
    if (_hideBalances) return '••••';
    if (compact) {
      return NumberFormat.compactSimpleCurrency(
        locale: _locale,
        name: _currencyCode,
        decimalDigits: decimalDigits,
      ).format(value);
    }
    return NumberFormat.simpleCurrency(
      locale: _locale,
      name: _currencyCode,
      decimalDigits: decimalDigits,
    ).format(value);
  }

  static String formatSigned(
    num value, {
    int decimalDigits = 2,
    bool plusForPositive = false,
  }) {
    if (_hideBalances) return '••••';
    final sign = value < 0 ? '-' : (plusForPositive && value > 0 ? '+' : '');
    return '$sign${format(value.abs(), decimalDigits: decimalDigits)}';
  }

  static String formatNumber(num value, {int decimalDigits = 2}) {
    return NumberFormat.decimalPatternDigits(
      locale: _locale,
      decimalDigits: decimalDigits,
    ).format(value);
  }
}
