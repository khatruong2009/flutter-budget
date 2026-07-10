import 'package:budget_app/onboarding_tutorial.dart';
import 'package:budget_app/storage/storage_keys.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<void> pumpTutorial(WidgetTester tester) {
    return tester.pumpWidget(
      const MaterialApp(
        home: OnboardingTutorialGate(
          child: Scaffold(body: Center(child: Text('Budget app'))),
        ),
      ),
    );
  }

  testWidgets('shows a concise tour on first launch and saves completion',
      (tester) async {
    SharedPreferences.setMockInitialValues({});

    await pumpTutorial(tester);
    await tester.pumpAndSettle();

    expect(find.text('Your money, made clearer.'), findsOneWidget);
    expect(find.text('Budget app'), findsNothing);
    expect(find.text('Skip'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Track what comes and goes.'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Plan ahead, then look back.'), findsOneWidget);

    await tester.tap(find.text('Start budgeting'));
    await tester.pumpAndSettle();

    expect(find.text('Budget app'), findsOneWidget);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool(StorageKeys.onboardingCompleted), isTrue);
  });

  testWidgets('does not show the tour again once it has been completed',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      StorageKeys.onboardingCompleted: true,
    });

    await pumpTutorial(tester);
    await tester.pumpAndSettle();

    expect(find.text('Budget app'), findsOneWidget);
    expect(find.text('Your money, made clearer.'), findsNothing);
  });

  testWidgets('skip dismisses the tour and persists completion',
      (tester) async {
    SharedPreferences.setMockInitialValues({});

    await pumpTutorial(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(find.text('Budget app'), findsOneWidget);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool(StorageKeys.onboardingCompleted), isTrue);
  });

  testWidgets('keeps the first page clear and tappable in dark mode',
      (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: const OnboardingTutorialGate(
          child: Scaffold(body: Center(child: Text('Budget app'))),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Tutorial page 1 of 3'), findsOneWidget);
    expect(find.text('Your money, made clearer.'), findsOneWidget);
    expect(tester.getSize(find.byType(FilledButton)).height,
        greaterThanOrEqualTo(48));
  });
}
