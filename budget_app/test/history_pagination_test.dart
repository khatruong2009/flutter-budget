import 'package:budget_app/categorization_provider.dart';
import 'package:budget_app/history_page.dart';
import 'package:budget_app/storage/atomic_financial_store.dart';
import 'package:budget_app/transaction.dart';
import 'package:budget_app/transaction_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    await AtomicFinancialStore.instance.resetForTesting();
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('history can reveal matches beyond the first fifty',
      (tester) async {
    final model = TransactionModel();
    model.transactions = List.generate(
      60,
      (index) => Transaction(
        type: TransactionTyp.expense,
        description: 'Expense $index',
        amount: 1,
        category: 'General',
        date: DateTime(2026, 7, 1).add(Duration(days: index)),
      ),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<TransactionModel>.value(value: model),
          ChangeNotifierProvider(create: (_) => CategorizationProvider()),
        ],
        child: const MaterialApp(home: HistoryPage()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.ensureVisible(find.text('SEE ALL'));
    await tester.tap(find.text('SEE ALL'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Results'), findsOneWidget);
    expect(find.text('60 of 60'), findsOneWidget);

    expect(find.text('Expense 0'), findsNothing);
    expect(find.text('Load more transactions'), findsOneWidget);
    await tester.ensureVisible(find.text('Load more transactions'));
    await tester.tap(find.text('Load more transactions'));
    await tester.pump();

    expect(find.text('Expense 0'), findsOneWidget);
    expect(find.text('Load more transactions'), findsNothing);
  });
}
