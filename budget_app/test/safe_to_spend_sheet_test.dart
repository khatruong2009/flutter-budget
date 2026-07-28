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
import 'package:budget_app/transaction.dart';
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

      await tester.scrollUntilVisible(
        find.text('DETAILS'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('DETAILS'));
      await tester.pumpAndSettle();

      // The card behind the sheet also says "Safe to spend", so key off the
      // sheet's own description line.
      final sheetTitle = find.textContaining('A forward-looking estimate');
      final sheetRoute = ModalRoute.of(tester.element(sheetTitle))!;
      final rootNavigator =
          tester.state<NavigatorState>(find.byType(Navigator).first);
      expect(sheetRoute.navigator, same(rootNavigator));

      final dailyAllowance = find.textContaining('remaining');
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

  testWidgets('negative cash flow does not suggest an impossible daily trim',
      (tester) async {
    final now = DateTime.now();
    final transactionModel = TransactionModel()
      ..transactions = [
        Transaction(
          type: TransactionTyp.income,
          description: 'Income',
          amount: 4400,
          category: 'Salary',
          date: DateTime(now.year, now.month, 1),
        ),
        Transaction(
          type: TransactionTyp.expense,
          description: 'Expenses',
          amount: 7176.93,
          category: 'General',
          date: DateTime(now.year, now.month, 2),
        ),
      ];

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: transactionModel),
          ChangeNotifierProvider(create: (_) => RecurringTransactionModel()),
        ],
        child: const MaterialApp(home: SpendingPage()),
      ),
    );
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('Projected shortfall'), findsOneWidget);
    expect(find.text('Add income or reduce planned spending'), findsOneWidget);
    expect(find.textContaining('Trim'), findsNothing);
  });
}
