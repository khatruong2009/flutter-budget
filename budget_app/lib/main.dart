import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Budgeting App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const BudgetHomePage(title: 'Home'),
    );
  }
}

Future<void> showTransactionForm(
    BuildContext context, TransactionType type) async {
  // categories and their icons
  final Map<String, IconData> expenseCategories = {
    'General': CupertinoIcons.square_grid_2x2,
    'Eating Out': CupertinoIcons.drop_triangle,
    'Groceries': CupertinoIcons.cart,
    'Housing': CupertinoIcons.house,
    'Transportation': CupertinoIcons.car_detailed,
    'Travel': CupertinoIcons.airplane,
    'Clothing': CupertinoIcons.bag,
    'Gift': CupertinoIcons.gift,
    'Health': CupertinoIcons.heart,
    'Entertainment': CupertinoIcons.film,
  };

  final Map<String, IconData> incomeCategories = {
    'Salary': CupertinoIcons.money_dollar,
    'Investment': CupertinoIcons.chart_bar,
    'Gift': CupertinoIcons.gift,
    'Other': CupertinoIcons.square_grid_2x2,
  };

  final _formKey = GlobalKey<FormState>();
  String description = '';
  String category = type == TransactionType.EXPENSE
      ? expenseCategories.keys.first
      : incomeCategories.keys.first;
  double amount = 0.0;

  // show transaction form
  await showCupertinoDialog(
    context: context,
    builder: (BuildContext context) {
      return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
        final categoryMap = type == TransactionType.EXPENSE
            ? expenseCategories
            : incomeCategories;

        return CupertinoAlertDialog(
          title: Text(
              type == TransactionType.EXPENSE ? 'Add Expense' : 'Add Income'),
          content: Form(
            key: _formKey,
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 10.0),
                  child: CupertinoTextField(
                    placeholder: 'Description',
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    onChanged: (value) {
                      description = value;
                    },
                  ),
                ),
                Container(
                  height: 150,
                  child: CupertinoPicker(
                    itemExtent: 30,
                    onSelectedItemChanged: (index) {
                      setState(() {
                        category = categoryMap.keys.elementAt(index);
                      });
                    },
                    children: categoryMap.entries.map((entry) {
                      return Row(
                        children: <Widget>[
                          Icon(entry.value, size: 25),
                          SizedBox(width: 10),
                          Text(entry.key),
                        ],
                      );
                    }).toList(),
                  ),
                ),
                CupertinoTextField(
                  placeholder: 'Amount',
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  onChanged: (value) {
                    amount = double.parse(value);
                  },
                ),
              ],
            ),
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            CupertinoDialogAction(
              child: const Text('Add'),
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  // add transaction
                  // addTransaction(type, description, amount, category);
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      });
    },
  );
}

// HOME PAGE
class BudgetHomePage extends StatefulWidget {
  const BudgetHomePage({Key? key, required this.title}) : super(key: key);
  final String title;
  @override
  State<BudgetHomePage> createState() => _BudgetHomePageState();
}

class _BudgetHomePageState extends State<BudgetHomePage> {
  double total = 0.0;
  List<Transaction> transactions = [];

  @override
  Widget build(BuildContext context) {
    return CupertinoTabScaffold(
      tabBar: CupertinoTabBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.money_dollar_circle),
            label: 'Spending',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.list_bullet),
            label: 'Transaction',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.gear),
            label: 'Settings',
          ),
        ],
      ),
      tabBuilder: (BuildContext context, int index) {
        return CupertinoTabView(
          builder: (BuildContext context) {
            switch (index) {
              case 0:
                return SpendingPage();
              case 1:
                return const TransactionPage();
              case 2:
                return const SettingsPage();
            }
            return const CupertinoPageScaffold(
              child: Center(child: Text('Page not found.')),
            );
          },
        );
      },
    );
  }

  // save total to local storage
  Future<void> saveTotal(double total) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('total', total);
  }

  // get total from local storage
  Future<double> getTotal() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble('total') ?? 0.0;
  }

  // save transactions to local storage
  Future<void> saveTransactions(List<Transaction> transactions) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonTransactions = transactions.map((t) => t.toJson()).toList();
    await prefs.setString('transactions', jsonEncode(jsonTransactions));
  }

  // get transactions from local storage
  Future<List<Transaction>> getTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('transactions');
    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }
    final jsonList = jsonDecode(jsonString) as List;
    return jsonList.map((e) => Transaction.fromJson(e)).toList();
  }

  // void addTransaction(
  //     TransactionType type, description, double amount, String category) {
  //   setState(() {
  //     transactions.add(Transaction(type, description, amount, category));
  //     total += amount;
  //   });
  // }
}

// SPENDING PAGE
class SpendingPage extends StatelessWidget {
  final List<Transaction> transactions = [];

  SpendingPage({Key? key}) : super(key: key);
  @override

  // calculate total income
  double calculateTotalIncome(List<Transaction> transactions) {
    return transactions
        .where((transaction) => transaction.type == 'INCOME')
        .map((transaction) => transaction.amount)
        .fold(0, (previousValue, amount) => previousValue + amount);
  }

  // calculate total expenses
  double calculateTotalExpenses(List<Transaction> transactions) {
    return transactions
        .where((transaction) => transaction.type == 'EXPENSE')
        .map((transaction) => transaction.amount)
        .fold(0, (previousValue, amount) => previousValue + amount);
  }

  @override
  Widget build(BuildContext context) {
    double totalIncome = calculateTotalIncome(transactions);
    double totalExpenses = calculateTotalExpenses(transactions);
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
                      showTransactionForm(context, TransactionType.EXPENSE);
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
                      showTransactionForm(context, TransactionType.INCOME);
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
  }
}

// TRANSACTION PAGE
class TransactionPage extends StatelessWidget {
  const TransactionPage({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return const CupertinoPageScaffold(
      child: Center(
        child: Text('Welcome to your Transaction page!',
            style: TextStyle(fontSize: 20)),
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return const CupertinoPageScaffold(
      child: Center(
        child: Text('Welcome to your Settings page!',
            style: TextStyle(fontSize: 20)),
      ),
    );
  }
}

// TRANSACTION CLASS
class Transaction {
  String description;
  double amount;
  String category;
  TransactionType type;

  Transaction(
      {required this.type,
      required this.description,
      required this.amount,
      required this.category});

  // convert transaction object into a map
  Map<String, dynamic> toJson() => {
        'type': type == TransactionType.EXPENSE ? 'expense' : 'income',
        'description': description,
        'amount': amount,
        'category': category,
      };

  // convert map into a transaction object
  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      type: json['type'] == 'expense'
          ? TransactionType.EXPENSE
          : TransactionType.INCOME,
      description: json['description'],
      amount: json['amount'],
      category: json['category'],
    );
  }
}

enum TransactionType { EXPENSE, INCOME }
