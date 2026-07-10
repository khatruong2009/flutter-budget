import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:material_symbols_icons/symbols.dart';

import 'package:budget_app/main.dart';
import 'package:budget_app/net_worth_page.dart';
import 'package:budget_app/recurring_transaction_model.dart';
import 'package:budget_app/spending_page.dart';
import 'package:budget_app/storage/storage_keys.dart';
import 'package:budget_app/theme_provider.dart';
import 'package:budget_app/transaction_model.dart';
import 'package:budget_app/widgets/floating_dock.dart';
import 'package:budget_app/widgets/voice_recording_sheet.dart';

/// Denies mic permission so the sheet lands in its error state without
/// touching platform channels; the layering assertions only need the sheet
/// to be visible.
class _FakeRecordPlatform extends RecordPlatform {
  @override
  Future<void> create(String recorderId) async {}

  @override
  Future<bool> hasPermission(String recorderId, {bool request = true}) async =>
      false;

  @override
  Future<void> start(String recorderId, RecordConfig config,
      {required String path}) async {}

  @override
  Future<Stream<Uint8List>> startStream(
          String recorderId, RecordConfig config) async =>
      const Stream<Uint8List>.empty();

  @override
  Future<String?> stop(String recorderId) async => null;

  @override
  Future<void> pause(String recorderId) async {}

  @override
  Future<void> resume(String recorderId) async {}

  @override
  Future<bool> isRecording(String recorderId) async => false;

  @override
  Future<bool> isPaused(String recorderId) async => false;

  @override
  Future<void> dispose(String recorderId) async {}

  @override
  Future<Amplitude> getAmplitude(String recorderId) async =>
      Amplitude(current: 0, max: 0);

  @override
  Future<bool> isEncoderSupported(
          String recorderId, AudioEncoder encoder) async =>
      true;

  @override
  Future<List<InputDevice>> listInputDevices(String recorderId) async => [];

  @override
  Future<void> cancel(String recorderId) async {}

  @override
  Stream<RecordState> onStateChanged(String recorderId) => const Stream.empty();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      StorageKeys.onboardingCompleted: true,
    });
    RecordPlatform.instance = _FakeRecordPlatform();
  });

  testWidgets('voice sheet is hosted on the root navigator, above the dock',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => TransactionModel()),
          ChangeNotifierProvider(create: (_) => RecurringTransactionModel()),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
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

    final errorText =
        find.text('Microphone access is off. Enable it in Settings > Budgie.');
    expect(errorText, findsOneWidget);

    // The sheet's route must live on the root navigator; on a nested tab
    // navigator it would paint below the FloatingDock.
    final sheetRoute = ModalRoute.of(tester.element(errorText))!;
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
    expect(errorText, findsOneWidget);

    // A tap outside the sheet still dismisses it through the barrier.
    await tester.tapAt(const Offset(400, 100));
    await tester.pump(const Duration(milliseconds: 400));
    expect(errorText, findsNothing);
    expect(find.byType(SpendingPage), findsOneWidget);
  });
}
