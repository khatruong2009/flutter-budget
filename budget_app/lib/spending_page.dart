import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import 'transaction.dart';
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
  List<String> months = [
    "January",
    "February",
    "March",
    "April",
    "May",
    "June",
    "July",
    "August",
    "September",
    "October",
    "November",
    "December"
  ];

  // current month
  int currentMonthIndex = DateTime.now().month - 1;
  late FixedExtentScrollController scrollController;

  @override
  void initState() {
    super.initState();
    scrollController =
        FixedExtentScrollController(initialItem: currentMonthIndex);
  }

  // calculate total income
  double calculateTotalIncome(List<Transaction> transactions) {
    return transactions
        .where((transaction) => transaction.type == TransactionTyp.INCOME)
        .map((transaction) => transaction.amount)
        .fold(0, (previousValue, amount) => previousValue + amount);
  }

  // calculate total expenses
  double calculateTotalExpenses(List<Transaction> transactions) {
    return transactions
        .where((transaction) => transaction.type == TransactionTyp.EXPENSE)
        .map((transaction) => transaction.amount)
        .fold(0, (previousValue, amount) => previousValue + amount);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TransactionModel>(
      builder: (context, transactionModel, child) {
        double totalIncome =
            calculateTotalIncome(transactionModel.currentMonthTransactions);
        double totalExpenses =
            calculateTotalExpenses(transactionModel.currentMonthTransactions);
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
                        // top text with income and expenses
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
                        // toggle to select the month
                        CupertinoPicker(
                          scrollController: scrollController,
                          itemExtent: 32,
                          onSelectedItemChanged: (int index) {
                            transactionModel.selectMonth(
                                DateTime(DateTime.now().year, index + 1));
                          },
                          children: months.map((String month) {
                            return Text(month);
                          }).toList(),
                        ),
                        // hero text with cash flow
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
                // bottom buttons
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
                          showTransactionForm(context, TransactionTyp.EXPENSE,
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
                          showTransactionForm(context, TransactionTyp.INCOME,
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
