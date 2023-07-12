import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => TransactionModel(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Budgeting App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: FutureBuilder(
        future: context.read<TransactionModel>().getTransactions(),
        builder: (BuildContext context, AsyncSnapshot snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return const BudgetHomePage(title: 'Home');
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }
}

class TransactionModel extends ChangeNotifier {
  List<Transaction> transactions = [];
  double totalIncome = 0.0;
  double totalExpenses = 0.0;

  void addTransaction(TransactionType type, String description, double amount,
      String category) {
    Transaction newTransaction = Transaction(
      type: type,
      description: description,
      amount: amount,
      category: category,
      date: DateTime.now(),
    );
    transactions.add(newTransaction);
    if (type == TransactionType.EXPENSE) {
      totalExpenses += amount;
    } else {
      totalIncome += amount;
    }
    saveTransactions(transactions);
    notifyListeners();
  }

  Future<void> saveTransactions(List<Transaction> transactions) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonTransactions = transactions.map((t) => t.toJson()).toList();
    print("Saving transactions: $jsonTransactions");
    await prefs.setString('transactions', jsonEncode(jsonTransactions));
  }

  Future<void> getTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('transactions');
    if (jsonString != null && jsonString.isNotEmpty) {
      final jsonList = jsonDecode(jsonString) as List;
      transactions = jsonList.map((e) => Transaction.fromJson(e)).toList();
      totalIncome = transactions
          .where((transaction) => transaction.type == TransactionType.INCOME)
          .map((transaction) => transaction.amount)
          .fold(0, (previousValue, amount) => previousValue + amount);
      totalExpenses = transactions
          .where((transaction) => transaction.type == TransactionType.EXPENSE)
          .map((transaction) => transaction.amount)
          .fold(0, (previousValue, amount) => previousValue + amount);
    }
  }

  void deleteTransaction(int index) {
    Transaction deletedTransaction = transactions.removeAt(index);
    if (deletedTransaction.type == TransactionType.EXPENSE) {
      totalExpenses -= deletedTransaction.amount;
    } else {
      totalIncome -= deletedTransaction.amount;
    }
    saveTransactions(transactions);
    notifyListeners();
  }
}

Future<void> showTransactionForm(
    BuildContext context, TransactionType type, Function addTransaction) async {
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
                  addTransaction(type, description, amount, category);
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

// SPENDING PAGE
class SpendingPage extends StatefulWidget {
  final List<Transaction> transactions = [];
  final Function addTransaction;

  SpendingPage({
    Key? key,
    required this.addTransaction,
  }) : super(key: key);

  @override
  _SpendingPageState createState() => _SpendingPageState();
}

class _SpendingPageState extends State<SpendingPage> {
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
    return Consumer<TransactionModel>(
      builder: (context, TransactionModel, child) {
        double totalIncome = TransactionModel.totalIncome;
        double totalExpenses = TransactionModel.totalExpenses;
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
                              TransactionModel.addTransaction);
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
                              TransactionModel.addTransaction);
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

// TRANSACTION PAGE
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
  DateTime date;

  Transaction(
      {required this.type,
      required this.description,
      required this.amount,
      required this.category,
      required this.date});

  // convert transaction object into a map
  Map<String, dynamic> toJson() => {
        'type': type == TransactionType.EXPENSE ? 'expense' : 'income',
        'description': description,
        'amount': amount,
        'category': category,
        'date': date.toIso8601String(),
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
      date: DateTime.parse(json['date']),
    );
  }
}

enum TransactionType { EXPENSE, INCOME }
