import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'transaction.dart';

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
