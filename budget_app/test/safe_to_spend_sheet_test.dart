import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:budget_app/app_settings_provider.dart';
import 'package:budget_app/categorization_provider.dart';
import 'package:budget_app/category_provider.dart';
import 'package:budget_app/main.dart';
import 'package:budget_app/recurring_transaction_model.dart';
import 'package:budget_app/spending_page.dart';
import 'package:budget_app/storage/storage_keys.dart';
import 'package:budget_app/theme_provider.dart';
import 'package:budget_app/transaction_model.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      StorageKeys.onboardingCompleted: true,
    });
  });

  testWidgets(
    'safe-to-spend breakdown opens above the dock and scrolls on small screens',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 500));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => TransactionModel()),
            ChangeNotifierProvider(create: (_) => RecurringTransactionModel()),
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
            ChangeNotifierProvider(create: (_) => AppSettingsProvider()),
            ChangeNotifierProvider(create: (_) => CategoryProvider()),
            ChangeNotifierProvider(create: (_) => CategorizationProvider()),
          ],
          child: const AppContainer(child: MyApp()),
        ),
      );

      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(SpendingPage), findsOneWidget);

      await tester.tap(find.text('TAP FOR BREAKDOWN'));
      await tester.pumpAndSettle();

      final sheetTitle = find.text('Safe to spend').first;
      final sheetRoute = ModalRoute.of(tester.element(sheetTitle))!;
      final rootNavigator =
          tester.state<NavigatorState>(find.byType(Navigator).first);
      expect(sheetRoute.navigator, same(rootNavigator));

      final dailyAllowance = find.textContaining('days remaining');
      expect(dailyAllowance, findsOneWidget);
      expect(
        find.ancestor(
          of: dailyAllowance,
          matching: find.byType(SingleChildScrollView),
        ),
        findsOneWidget,
      );

      await tester.ensureVisible(dailyAllowance);
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(tester.getBottomRight(dailyAllowance).dy, lessThanOrEqualTo(500));
    },
  );
}
