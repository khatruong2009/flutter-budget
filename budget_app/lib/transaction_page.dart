import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'transaction.dart';

import 'package:provider/provider.dart';
import 'transaction_model.dart';
import 'package:intl/intl.dart';

class TransactionPage extends StatelessWidget {
  const TransactionPage({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Consumer<TransactionModel>(
      builder: (context, transactionModel, child) {
        return Material(
          child: ListView.builder(
            itemCount: transactionModel.currentMonthTransactions.length,
            itemBuilder: (context, index) {
              final transaction =
                  transactionModel.currentMonthTransactions[index];
              return Dismissible(
                key: UniqueKey(),
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
                        onPressed: () => Navigator.of(context).pop(false),
                      ),
                      CupertinoDialogAction(
                        child: const Text('Delete'),
                        onPressed: () => Navigator.of(context).pop(true),
                      ),
                    ],
                  ),
                ),
                onDismissed: (direction) {
                  transactionModel.deleteTransaction(index);
                },
                background: Container(
                  color: Colors.red,
                  padding: const EdgeInsets.only(right: 20),
                  alignment: Alignment.centerRight,
                  child: const Text(
                    'Delete',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
                child: ListTile(
                  title: Text(transaction.description),
                  subtitle: Text(
                      'Category: ${transaction.category}\nDate: ${DateFormat.yMMMd().format(transaction.date)}'),
                  trailing: Text('\$${transaction.amount.toStringAsFixed(2)}'),
                  leading: Icon(transaction.type == TransactionTyp.EXPENSE
                      ? CupertinoIcons.money_dollar_circle
                      : CupertinoIcons.money_dollar_circle_fill),
                  iconColor: transaction.type == TransactionTyp.EXPENSE
                      ? Colors.red
                      : Colors.green,
                ),
              );
            },
          ),
        );
      },
    );
  }
}
