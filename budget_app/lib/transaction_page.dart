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
      builder: (context, TransactionModel, child) {
        return Material(
          child: ListView.builder(
            itemCount: TransactionModel.transactions.length,
            itemBuilder: (context, index) {
              final transaction = TransactionModel.transactions[index];
              return Dismissible(
                key: UniqueKey(),
                direction: DismissDirection.endToStart,
                onDismissed: (direction) {
                  TransactionModel.deleteTransaction(index);
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
                  leading: Icon(transaction.type == TransactionType.EXPENSE
                      ? CupertinoIcons.money_dollar_circle
                      : CupertinoIcons.money_dollar_circle_fill),
                  iconColor: transaction.type == TransactionType.EXPENSE
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
