import 'package:budget_app/app_settings_provider.dart';
import 'package:budget_app/money_formatter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    MoneyFormatter.configure(currencyCode: 'USD');
  });

  tearDown(() {
    MoneyFormatter.configure(currencyCode: 'USD');
  });

  test('existing users default to USD and device locale', () async {
    final settings = AppSettingsProvider();
    await settings.load();

    expect(settings.baseCurrencyCode, 'USD');
    expect(settings.localeOverride, isNull);
    expect(settings.locale, isNull);
  });

  test('currency and locale persist and reconfigure money formatting',
      () async {
    final settings = AppSettingsProvider();
    await settings.load();
    await settings.setBaseCurrencyCode('eur');
    await settings.setLocaleOverride('de_DE');

    final reloaded = AppSettingsProvider();
    await reloaded.load();

    expect(reloaded.baseCurrencyCode, 'EUR');
    expect(reloaded.localeOverride, 'de_DE');
    expect(reloaded.locale?.languageCode, 'de');
    expect(MoneyFormatter.format(1234.5), contains('€'));
  });

  test('privacy preferences persist and hide balances immediately', () async {
    final settings = AppSettingsProvider();
    await settings.load();
    await settings.setAppLockEnabled(true);
    await settings.setAutoLockTimeoutSeconds(300);
    await settings.setHideBalances(true);

    expect(MoneyFormatter.format(42), '••••');
    expect(MoneyFormatter.formatSigned(-42), '••••');

    final reloaded = AppSettingsProvider();
    await reloaded.load();
    expect(reloaded.appLockEnabled, isTrue);
    expect(reloaded.autoLockTimeoutSeconds, 300);
    expect(reloaded.hideBalances, isTrue);
  });
}
