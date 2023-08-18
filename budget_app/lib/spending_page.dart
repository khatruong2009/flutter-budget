import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:animated_digit/animated_digit.dart';
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
  bool isExpanded = false;

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
        ValueNotifier<double> netDifference = ValueNotifier<double>(0.0);
        netDifference.value = totalIncome - totalExpenses;

        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'Spending',
              textAlign: TextAlign.center,
            ),
            centerTitle: true,
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: <Widget>[
                  // Display for Income and Expenses
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Income',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                              const SizedBox(height: 4),
                              Text(
                                  '\$${NumberFormat("#,##0.00", "en_US").format(totalIncome)}',
                                  style: const TextStyle(
                                      fontSize: 20, color: Colors.green)),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Expenses',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                              const SizedBox(height: 4),
                              Text(
                                  '\$${NumberFormat("#,##0.00", "en_US").format(totalExpenses)}',
                                  style: const TextStyle(
                                      fontSize: 20, color: Colors.red)),
                            ],
                          )
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Month Selector
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        isExpanded = !isExpanded; // Toggle the isExpanded state
                      });
                    },
                    child: AnimatedContainer(
                      height: isExpanded
                          ? 100
                          : 38, // 100 when expanded, 38 when collapsed
                      duration: const Duration(
                          milliseconds:
                              300), // Duration for the height animation
                      curve: Curves.easeInOut,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: CupertinoPicker(
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
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Cash Flow Display
                  Text("Cash Flow:",
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Colors.black,
                          decoration: TextDecoration.none)),
                  const SizedBox(height: 10),
                  ValueListenableBuilder<double>(
                    valueListenable: netDifference,
                    builder: (context, value, child) {
                      return AnimatedDigitWidget(
                        fractionDigits: 2,
                        value: value,
                        textStyle: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: value < 0 ? Colors.red : Colors.green,
                          decoration: TextDecoration.none,
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 30),

                  // Add Expense and Add Income Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: <Widget>[
                      CupertinoButton(
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
                      CupertinoButton(
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
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
