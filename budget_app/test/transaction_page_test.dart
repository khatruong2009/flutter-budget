import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:budget_app/transaction_model.dart';
import 'package:budget_app/transaction.dart';
import 'package:budget_app/transaction_page.dart';
import 'package:budget_app/widgets/modern_transaction_list_item.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('transaction page lists transactions for the selected month',
      (tester) async {
    final model = TransactionModel();
    model.addTransaction(TransactionTyp.income, 'Paycheck', 4120, 'Salary',
        DateTime(2026, 7, 1, 9));
    model.addTransaction(TransactionTyp.expense, 'Rent', 2150, 'Housing',
        DateTime(2026, 7, 1, 10));
    model.addTransaction(TransactionTyp.expense, 'Whole Foods Market', 86.20,
        'Groceries', DateTime(2026, 7, 2, 18));

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: model,
        child: const MaterialApp(home: TransactionPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Transactions'), findsOneWidget);
    expect(find.byType(ModernTransactionListItem), findsNWidgets(3),
        reason: 'all three July transactions should be listed');
    expect(find.text('Rent'), findsOneWidget);
  });
}
