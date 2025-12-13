import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../transaction.dart';
import '../design_system.dart';
import 'modern_transaction_list_item.dart';

/// Example page demonstrating the ModernTransactionListItem component
class TransactionListItemExamplesPage extends StatefulWidget {
  const TransactionListItemExamplesPage({super.key});

  @override
  State<TransactionListItemExamplesPage> createState() =>
      _TransactionListItemExamplesPageState();
}

class _TransactionListItemExamplesPageState
    extends State<TransactionListItemExamplesPage> {
  List<Transaction> _transactions = [];

  @override
  void initState() {
    super.initState();
    _transactions = _createSampleTransactions();
  }

  List<Transaction> _createSampleTransactions() {
    return [
      Transaction(
        type: TransactionTyp.EXPENSE,
        description: 'Grocery Shopping',
        amount: 125.50,
        category: 'Groceries',
        date: DateTime.now().subtract(const Duration(days: 1)),
      ),
      Transaction(
        type: TransactionTyp.INCOME,
        description: 'Monthly Salary',
        amount: 5000.00,
        category: 'Salary',
        date: DateTime.now().subtract(const Duration(days: 2)),
      ),
      Transaction(
        type: TransactionTyp.EXPENSE,
        description: 'Restaurant Dinner',
        amount: 85.00,
        category: 'Eating Out',
        date: DateTime.now().subtract(const Duration(days: 3)),
      ),
      Transaction(
        type: TransactionTyp.EXPENSE,
        description: 'Gas Station',
        amount: 45.00,
        category: 'Transportation',
        date: DateTime.now().subtract(const Duration(days: 4)),
      ),
      Transaction(
        type: TransactionTyp.INCOME,
        description: 'Freelance Project',
        amount: 750.00,
        category: 'Other',
        date: DateTime.now().subtract(const Duration(days: 5)),
      ),
      Transaction(
        type: TransactionTyp.EXPENSE,
        description: 'Movie Tickets',
        amount: 30.00,
        category: 'Entertainment',
        date: DateTime.now().subtract(const Duration(days: 6)),
      ),
    ];
  }

  void _handleTransactionTap(Transaction transaction) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Tapped: ${transaction.description}'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _handleTransactionDelete(Transaction transaction) {
    setState(() {
      _transactions.remove(transaction);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Deleted: ${transaction.description}'),
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            setState(() {
              _transactions.add(transaction);
              _transactions.sort((a, b) => b.date.compareTo(a.date));
            });
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction List Item Examples'),
        centerTitle: true,
      ),
      body: Container(
        color: AppDesign.getBackgroundColor(context),
        child: SafeArea(
          child: _transactions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        CupertinoIcons.doc_text,
                        size: AppDesign.iconXXL,
                        color: AppDesign.getTextSecondary(context),
                      ),
                      const SizedBox(height: AppDesign.spacingM),
                      Text(
                        'No transactions',
                        style: AppTypography.headingMedium.copyWith(
                          color: AppDesign.getTextSecondary(context),
                        ),
                      ),
                      const SizedBox(height: AppDesign.spacingS),
                      Text(
                        'All transactions have been deleted',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppDesign.getTextTertiary(context),
                        ),
                      ),
                      const SizedBox(height: AppDesign.spacingL),
                      AppButton.primary(
                        label: 'Reset',
                        onPressed: () {
                          setState(() {
                            _transactions = _createSampleTransactions();
                          });
                        },
                        icon: CupertinoIcons.refresh,
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(AppDesign.spacingM),
                  itemCount: _transactions.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: AppDesign.spacingM),
                  itemBuilder: (context, index) {
                    final transaction = _transactions[index];
                    return ModernTransactionListItem(
                      transaction: transaction,
                      onTap: () => _handleTransactionTap(transaction),
                      onDelete: () => _handleTransactionDelete(transaction),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
