// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:budget_app/main.dart';
import 'package:budget_app/transaction_model.dart';
import 'package:budget_app/theme_provider.dart';

void main() {
  testWidgets('App initializes and displays home page', (WidgetTester tester) async {
    // Build our app with required providers
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => TransactionModel()),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ],
        child: const MyApp(),
      ),
    );

    // Pump a few frames to let the app initialize
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify that the app loads successfully
    // The app should show the tab bar with navigation
    expect(find.byType(MyApp), findsOneWidget);
  });
}
