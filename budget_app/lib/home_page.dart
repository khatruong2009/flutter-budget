import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'transaction.dart';
import 'spending_page.dart';
import 'transaction_page.dart';
import 'category_page.dart';
import 'settings_page.dart';

class BudgetHomePage extends StatefulWidget {
  const BudgetHomePage({Key? key, required this.title}) : super(key: key);
  final String title;
  @override
  State<BudgetHomePage> createState() => _BudgetHomePageState();
}

class _BudgetHomePageState extends State<BudgetHomePage> {
  double total = 0.0;
  List<Transaction> transactions = [];

  double totalIncome = 0.0;
  double totalExpenses = 0.0;

  @override
  void initState() {
    super.initState();
    getTransactions().then((loadedTransactions) {
      setState(() {
        transactions = loadedTransactions;
        totalIncome = transactions
            .where((transaction) => transaction.type == TransactionType.INCOME)
            .map((transaction) => transaction.amount)
            .fold(0, (previousValue, amount) => previousValue + amount);
        totalExpenses = transactions
            .where((transaction) => transaction.type == TransactionType.EXPENSE)
            .map((transaction) => transaction.amount)
            .fold(0, (previousValue, amount) => previousValue + amount);
      });
    });
  }

  void addTransaction(TransactionType type, String description, double amount,
      String category) {
    setState(() {
      transactions.add(Transaction(
        type: type,
        description: description,
        amount: amount,
        category: category,
        date: DateTime.now(),
      ));
      if (type == TransactionType.EXPENSE) {
        totalExpenses += amount;
      } else {
        totalIncome += amount;
      }
    });
    saveTransactions(transactions);
    saveTotal(totalIncome - totalExpenses);
  }

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
            icon: Icon(Icons.pie_chart),
            label: 'Categories',
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
                return SpendingPage(
                    // totalIncome: totalIncome,
                    // totalExpenses: totalExpenses,
                    addTransaction: addTransaction);
              case 1:
                return TransactionPage();
              case 2:
                return CategoryPage();
              case 3:
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

  void saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('key', 'value');
  }

  void retrieveData() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString('key');
    print(value);
  }

  // save transactions to local storage
  Future<void> saveTransactions(List<Transaction> transactions) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonTransactions = transactions.map((t) => t.toJson()).toList();
    print("Saving transactions: $jsonTransactions");
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
    print("Retrieving transactions: $jsonList");
    return jsonList.map((e) => Transaction.fromJson(e)).toList();
  }
}
