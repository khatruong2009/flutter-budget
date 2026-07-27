import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:material_symbols_icons/symbols.dart';

import 'package:budget_app/main.dart';
import 'package:budget_app/app_settings_provider.dart';
import 'package:budget_app/category_provider.dart';
import 'package:budget_app/categorization_provider.dart';
import 'package:budget_app/net_worth_page.dart';
import 'package:budget_app/recurring_transaction_model.dart';
import 'package:budget_app/spending_page.dart';
import 'package:budget_app/storage/storage_keys.dart';
import 'package:budget_app/theme_provider.dart';
import 'package:budget_app/transaction_model.dart';
import 'package:budget_app/widgets/floating_dock.dart';
import 'package:budget_app/widgets/voice_recording_sheet.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      StorageKeys.onboardingCompleted: true,
    });
  });

  testWidgets('quick-entry sheet is hosted on root navigator above the dock',
      (WidgetTester tester) async {
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

    // Let initialization and the opening-screen switcher finish.
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(SpendingPage), findsOneWidget);

    // Same call the Spending page mic FAB makes; the FAB itself only
    // renders on mobile platforms, so invoke the flow with the page's
    // context (which lives inside the nested tab navigator).
    final pageContext = tester.element(find.byType(SpendingPage));
    unawaited(startVoiceExpenseFlow(pageContext));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final sheetTitle = find.text('Quick entry');
    expect(sheetTitle, findsOneWidget);

    // The sheet's route must live on the root navigator; on a nested tab
    // navigator it would paint below the FloatingDock.
    final sheetRoute = ModalRoute.of(tester.element(sheetTitle))!;
    final rootNavigator =
        tester.state<NavigatorState>(find.byType(Navigator).first);
    expect(sheetRoute.navigator, same(rootNavigator));

    // The sheet must cover the dock: tapping a dock item's location goes to
    // the sheet, not the dock, so the tab does not switch. Before the fix
    // this tap reached the dock and navigated to the Worth tab.
    await tester.tap(
      find.byIcon(Symbols.donut_small_rounded),
      warnIfMissed: false,
    );
    await tester.pump(const Duration(milliseconds: 400));
    final dock = tester.widget<FloatingDock>(find.byType(FloatingDock));
    expect(dock.currentIndex, 0);
    expect(find.byType(NetWorthPage), findsNothing);
    expect(sheetTitle, findsOneWidget);
  });
}
