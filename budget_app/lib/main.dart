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
                return const SpendingPage();
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

class SpendingPage extends StatelessWidget {
  const SpendingPage({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: Center(
          child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Container(
            margin: const EdgeInsets.all(10.0),
            child: CupertinoButton(
              color: Colors.red,
              minSize: 50,
              padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
              onPressed: () {
                // handle expense button press
              },
              child: const Text('Add Expense', style: TextStyle(fontSize: 20)),
            ),
          ),
          Container(
            margin: const EdgeInsets.all(10.0),
            child: CupertinoButton(
              color: Colors.green,
              minSize: 50,
              padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
              onPressed: () {
                // handle income button press
              },
              child: const Text('Add Income', style: TextStyle(fontSize: 20)),
            ),
          ),
        ],
      )),
    );
  }
}

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
