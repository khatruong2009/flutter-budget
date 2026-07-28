import 'package:budget_app/app_settings_provider.dart';
import 'package:budget_app/widgets/app_privacy_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'app switcher preview is covered only when App Lock is enabled',
    (tester) async {
      final settings = AppSettingsProvider();
      await settings.load();

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: settings,
          child: MaterialApp(
            home: AppPrivacyGate(
              authentication: _FakeLocalAuthentication(),
              child: const ColoredBox(
                color: Colors.blue,
                child: Text('Budget content'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();

      expect(find.byKey(const Key('app-privacy-cover')), findsNothing);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await settings.setAppLockEnabled(true);
      await tester.pump();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();

      expect(find.byKey(const Key('app-privacy-cover')), findsOneWidget);
      expect(find.text('App preview hidden'), findsOneWidget);
    },
  );
}

class _FakeLocalAuthentication implements LocalAuthentication {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #isDeviceSupported) {
      return Future<bool>.value(true);
    }
    if (invocation.memberName == #authenticate) {
      return Future<bool>.value(false);
    }
    return super.noSuchMethod(invocation);
  }
}
