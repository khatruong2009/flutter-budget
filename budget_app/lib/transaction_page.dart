import 'package:budget_app/transaction_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'transaction.dart';
import 'package:provider/provider.dart';
import 'transaction_model.dart';
import 'package:intl/intl.dart';
import 'common.dart';

class TransactionPage extends StatelessWidget {
  const TransactionPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<TransactionModel>(
      builder: (context, transactionModel, child) {
        final sortedTransactions =
            List.from(transactionModel.currentMonthTransactions)
              ..sort((a, b) => b.date.compareTo(a.date));
        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'Transactions',
              textAlign: TextAlign.center,
            ),
            centerTitle: true,
          ),
          body: Material(
            child: Padding(
              padding: const EdgeInsets.all(8.0), // Added global padding
              child: ListView.separated(
                separatorBuilder: (context, index) =>
                    Divider(color: Colors.grey.shade300),
                itemCount: sortedTransactions.length,
                itemBuilder: (context, index) {
                  final transaction =
                      sortedTransactions[index]; // Get transaction
                  return Dismissible(
                    key: ValueKey(
                        transaction.description + transaction.date.toString()),
                    direction: DismissDirection.endToStart,
                    confirmDismiss: (direction) => showDialog(
                      context: context,
                      builder: (context) => CupertinoAlertDialog(
                        title: const Text('Delete Transaction'),
                        content: const Text(
                            'Are you sure you want to delete this transaction?'),
                        actions: <Widget>[
                          CupertinoDialogAction(
                            child: const Text('Cancel'),
                            onPressed: () {
                              Navigator.of(context).pop(false);
                            },
                          ),
                          CupertinoDialogAction(
                            child: const Text('Delete',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            onPressed: () {
                              Navigator.of(context).pop(true);
                            },
                          ),
                        ],
                      ),
                    ),
                    onDismissed: (direction) {
                      transactionModel.deleteTransaction(transaction);
                      ScaffoldMessenger.of(context).showSnackBar(
                        // Provide feedback
                        const SnackBar(
                          content: Text('Transaction deleted'),
                        ),
                      );
                    },
                    background: Container(
                      color: Colors.red,
                      padding: const EdgeInsets.only(right: 20),
                      alignment: Alignment.centerRight,
                      child: const Icon(CupertinoIcons.delete,
                          color: Colors.white), // Use intuitive icon
                    ),
                    child: ListTile(
                      onTap: () {
                        showTransactionForm(context, transaction.type,
                            transactionModel.addTransaction, transaction);
                      },
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 10.0,
                          horizontal: 15.0), // Added padding for each list item
                      title: Text(transaction.description,
                          style: const TextStyle(
                              fontWeight: FontWeight
                                  .bold)), // Make description prominent
                      subtitle: Text(
                        'Category: ${transaction.category}\nDate: ${DateFormat.yMMMd().format(transaction.date)}',
                        style: const TextStyle(
                            fontSize:
                                12), // Decreased font size for secondary info
                      ),
                      trailing: Text(
                        '\$${NumberFormat("#,##0.00", "en_US").format(transaction.amount)}',
                        style: TextStyle(
                          fontSize: 16,
                          color: transaction.type == TransactionTyp.EXPENSE
                              ? (Theme.of(context).brightness ==
                                      Brightness.light
                                  ? Colors.red
                                  : Colors.red[300])
                              : (Theme.of(context).brightness ==
                                      Brightness.light
                                  ? Colors.green
                                  : Colors.green[300]),
                        ),
                      ), // Make the amount prominent
                      leading: Icon(
                        transaction.type == TransactionTyp.EXPENSE
                            ? expenseCategories[transaction.category] ??
                                CupertinoIcons.down_arrow
                            : incomeCategories[transaction.category] ??
                                CupertinoIcons.up_arrow, // Use arrow icons
                        color: transaction.type == TransactionTyp.EXPENSE
                            ? Colors.red
                            : Colors.green,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
