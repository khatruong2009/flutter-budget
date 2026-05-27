import 'package:budget_app/net_worth_page.dart';
import 'package:budget_app/net_worth_entry.dart';
import 'package:budget_app/transaction_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('can open and cancel the add account dialog', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => TransactionModel(),
        child: const MaterialApp(
          home: NetWorthPage(),
        ),
      ),
    );

    await tester.tap(find.text('Add Account'));
    await tester.pumpAndSettle();

    expect(find.text('Add Account'), findsWidgets);
    expect(find.text('Balance Month'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Cancel'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('account rows separate allocation percentage from percent change',
      (tester) async {
    final model = TransactionModel();
    final month = DateTime(2026, 3);

    await model.selectNetWorthMonth(month);
    await model.addNetWorthEntry(
      name: 'Brokerage',
      type: NetWorthEntryType.asset,
      amount: 1000,
      month: month,
      recordedAt: DateTime(2026, 3, 1, 9),
    );
    final brokerage = model.netWorthEntries.single;
    await model.updateNetWorthEntry(
      id: brokerage.id,
      name: brokerage.name,
      type: brokerage.type,
      amount: 1500,
      month: month,
      recordedAt: DateTime(2026, 3, 20, 9),
    );
    await model.addNetWorthEntry(
      name: 'Savings',
      type: NetWorthEntryType.asset,
      amount: 400,
      month: month,
      recordedAt: DateTime(2026, 3, 20, 9),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: model,
        child: const MaterialApp(
          home: NetWorthPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('78.9%'), findsOneWidget);
    expect(find.text('+78.9%'), findsNothing);
    expect(find.text('+50.0% vs prior'), findsOneWidget);
  });
}
