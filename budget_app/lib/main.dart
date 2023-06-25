import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_datastore/amplify_datastore.dart';
// import 'amplifyconfiguration.dart';
// import 'models/ModelProvider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  // initialize Amplify
  // Future<void> _configureAmplify() async {
  //   final datastorePlugin =
  //       AmplifyDataStore(modelProvider: ModelProvider.instance);
  //   await Amplify.addPlugins([datastorePlugin]);

  //   try {
  //     await Amplify.configure(amplifyconfig);
  //   } on AmplifyAlreadyConfiguredException {
  //     print("Amplify was already configured. Was the app restarted?");
  //   }
  // }

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

  void addTransaction(String description, double amount, String category) {
    setState(() {
      transactions.add(Transaction(description, amount, category));
      total += amount;
    });
  }
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

  Transaction(this.type, this.description, this.amount, this.category);
}

enum TransactionType { EXPENSE, INCOME }
