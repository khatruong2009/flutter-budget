import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import 'Transaction.dart';
import 'transaction_model.dart';
import 'transaction_form.dart';
import 'package:provider/provider.dart';

class SpendingPage extends StatefulWidget {
  final List<Transaction> transactions = [];
  final Function addTransaction;

  SpendingPage({
    Key? key,
    required this.addTransaction,
  }) : super(key: key);

  @override
  SpendingPageState createState() => SpendingPageState();
}

class SpendingPageState extends State<SpendingPage> {
  // calculate total income
  double calculateTotalIncome(List<Transaction> transactions) {
    return transactions
        .where((transaction) => transaction.type == TransactionType.INCOME)
        .map((transaction) => transaction.amount)
        .fold(0, (previousValue, amount) => previousValue + amount);
  }

  // calculate total expenses
  double calculateTotalExpenses(List<Transaction> transactions) {
    return transactions
        .where((transaction) => transaction.type == TransactionType.EXPENSE)
        .map((transaction) => transaction.amount)
        .fold(0, (previousValue, amount) => previousValue + amount);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TransactionModel>(
      builder: (context, transactionModel, child) {
        double totalIncome = transactionModel.totalIncome;
        double totalExpenses = transactionModel.totalExpenses;
        double netDifference = totalIncome - totalExpenses;

        return CupertinoPageScaffold(
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: <Widget>[
                        Text(
                          'Income: \$${totalIncome.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                              decoration: TextDecoration.none),
                        ),
                        Text(
                          'Expenses: \$${totalExpenses.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                              decoration: TextDecoration.none),
                        ),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text("Cash Flow:",
                                  style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                      decoration: TextDecoration.none)),
                              Text(
                                '\$${netDifference.toStringAsFixed(2)}',
                                style: TextStyle(
                                    fontSize: 48,
                                    fontWeight: FontWeight.bold,
                                    color: netDifference < 0
                                        ? Colors.red
                                        : Colors.green,
                                    decoration: TextDecoration.none),
                              ),
                            ],
                          ),
                        )
                        // const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
                Center(
                    child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Container(
                      margin: const EdgeInsets.all(10.0),
                      child: CupertinoButton(
                        color: Colors.red,
                        minSize: 50,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 25, vertical: 10),
                        onPressed: () {
                          showTransactionForm(context, TransactionType.EXPENSE,
                              transactionModel.addTransaction);
                        },
                        child: const Text('Add Expense',
                            style: TextStyle(fontSize: 20)),
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.all(10.0),
                      child: CupertinoButton(
                        color: Colors.green,
                        minSize: 50,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 25, vertical: 10),
                        onPressed: () {
                          showTransactionForm(context, TransactionType.INCOME,
                              transactionModel.addTransaction);
                        },
                        child: const Text('Add Income',
                            style: TextStyle(fontSize: 20)),
                      ),
                    ),
                  ],
                )),
              ],
            ),
          ),
        );
      },
    );
  }
}
