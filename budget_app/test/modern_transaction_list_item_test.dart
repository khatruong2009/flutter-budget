import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:budget_app/widgets/modern_transaction_list_item.dart';
import 'package:budget_app/transaction.dart';

void main() {
  group('ModernTransactionListItem', () {
    testWidgets('renders expense transaction correctly', (tester) async {
      // Create a test expense transaction
      final transaction = Transaction(
        type: TransactionTyp.expense,
        description: 'Test Expense',
        amount: 50.00,
        category: 'Groceries',
        date: DateTime(2024, 1, 15),
      );

      bool tapCalled = false;

      // Build the widget
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ModernTransactionListItem(
              transaction: transaction,
              onTap: () => tapCalled = true,
              onDelete: () {},
            ),
          ),
        ),
      );

      // Verify the transaction description is displayed
      expect(find.text('Test Expense'), findsOneWidget);

      // Verify the amount is displayed with proper formatting
      expect(find.text('\$50.00'), findsOneWidget);

      // Verify the category is displayed
      expect(find.textContaining('Groceries'), findsOneWidget);

      // Tap the item
      await tester.tap(find.byType(ModernTransactionListItem));
      await tester.pumpAndSettle();

      // Verify tap callback was called
      expect(tapCalled, true);
    });

    testWidgets('renders income transaction correctly', (tester) async {
      // Create a test income transaction
      final transaction = Transaction(
        type: TransactionTyp.income,
        description: 'Test Income',
        amount: 1000.00,
        category: 'Salary',
        date: DateTime(2024, 1, 1),
      );

      // Build the widget
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ModernTransactionListItem(
              transaction: transaction,
              onTap: () {},
              onDelete: () {},
            ),
          ),
        ),
      );

      // Verify the transaction description is displayed
      expect(find.text('Test Income'), findsOneWidget);

      // Verify the amount is displayed with proper formatting
      expect(find.text('\$1,000.00'), findsOneWidget);

      // Verify the category is displayed
      expect(find.textContaining('Salary'), findsOneWidget);
    });

    testWidgets('displays category icon with gradient background', (tester) async {
      final transaction = Transaction(
        type: TransactionTyp.expense,
        description: 'Test',
        amount: 25.00,
        category: 'Groceries',
        date: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ModernTransactionListItem(
              transaction: transaction,
              onTap: () {},
              onDelete: () {},
            ),
          ),
        ),
      );

      // Verify icon container exists
      final containerFinder = find.descendant(
        of: find.byType(ModernTransactionListItem),
        matching: find.byWidgetPredicate(
          (widget) => widget is Container && widget.decoration is BoxDecoration,
        ),
      );

      expect(containerFinder, findsWidgets);
    });

    testWidgets('formats date correctly', (tester) async {
      final transaction = Transaction(
        type: TransactionTyp.expense,
        description: 'Test',
        amount: 25.00,
        category: 'General',
        date: DateTime(2024, 3, 15),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ModernTransactionListItem(
              transaction: transaction,
              onTap: () {},
              onDelete: () {},
            ),
          ),
        ),
      );

      // Verify date is formatted (Mar 15)
      expect(find.textContaining('Mar'), findsOneWidget);
    });
  });
}
