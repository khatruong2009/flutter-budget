import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'transaction.dart';

class TransactionModel extends ChangeNotifier {
  List<Transaction> transactions = [];
  double totalIncome = 0.0;
  double totalExpenses = 0.0;
  DateTime selectedMonth = DateTime.now();

  // method to change selected month
  void selectMonth(DateTime date) {
    selectedMonth = DateTime(date.year, date.month);
    notifyListeners();
  }

  // add transaction
  void addTransaction(TransactionTyp type, String description, double amount,
      String category, DateTime date) {
    Transaction newTransaction = Transaction(
      type: type,
      description: description,
      amount: amount,
      category: category,
      date: date,
    );
    transactions.add(newTransaction);
    if (type == TransactionTyp.EXPENSE) {
      totalExpenses += amount;
    } else {
      totalIncome += amount;
    }
    saveTransactions(transactions);
    notifyListeners();
  }

  // save transactions
  Future<void> saveTransactions(List<Transaction> transactions) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonTransactions = transactions.map((t) => t.toJson()).toList();
    print("Saving transactions: $jsonTransactions");
    await prefs.setString('transactions', jsonEncode(jsonTransactions));
  }

  // load transactions
  Future<void> getTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('transactions');
    if (jsonString != null && jsonString.isNotEmpty) {
      final jsonList = jsonDecode(jsonString) as List;
      transactions = jsonList.map((e) => Transaction.fromJson(e)).toList();
      totalIncome = transactions
          .where((transaction) => transaction.type == TransactionTyp.INCOME)
          .map((transaction) => transaction.amount)
          .fold(0, (previousValue, amount) => previousValue + amount);
      totalExpenses = transactions
          .where((transaction) => transaction.type == TransactionTyp.EXPENSE)
          .map((transaction) => transaction.amount)
          .fold(0, (previousValue, amount) => previousValue + amount);
    }
  }

  // get the current month's transactions
  List<Transaction> get currentMonthTransactions {
    return transactions
        .where((transaction) =>
            transaction.date.year == selectedMonth.year &&
            transaction.date.month == selectedMonth.month)
        .toList();
  }

  void deleteTransaction(int index) {
    Transaction deletedTransaction = transactions.removeAt(index);
    if (deletedTransaction.type == TransactionTyp.EXPENSE) {
      totalExpenses -= deletedTransaction.amount;
    } else {
      totalIncome -= deletedTransaction.amount;
    }
    saveTransactions(transactions);
    notifyListeners();
  }
}
