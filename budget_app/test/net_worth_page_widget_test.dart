import 'package:budget_app/net_worth_page.dart';
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
    expect(find.text('Cancel'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Cancel'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
