import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'transaction.dart';

class TransactionModel extends ChangeNotifier {
  List<Transaction> transactions = [];
  DateTime selectedMonth = DateTime.now();

  // method to change selected month
  void selectMonth(DateTime date) {
    selectedMonth = DateTime(date.year, date.month);
    notifyListeners();
  }

  // Calculate total income for selected month
  double get totalIncome {
    return currentMonthTransactions
        .where((transaction) => transaction.type == TransactionTyp.INCOME)
        .map((transaction) => transaction.amount)
        .fold(0, (previousValue, amount) => previousValue + amount);
  }

  // Calculate total expenses for selected month
  double get totalExpenses {
    return currentMonthTransactions
        .where((transaction) => transaction.type == TransactionTyp.EXPENSE)
        .map((transaction) => transaction.amount)
        .fold(0, (previousValue, amount) => previousValue + amount);
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
    saveTransactions(transactions);
    notifyListeners();
  }

  // save transactions
  Future<void> saveTransactions(List<Transaction> transactions) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonTransactions = transactions.map((t) => t.toJson()).toList();
    await prefs.setString('transactions', jsonEncode(jsonTransactions));
  }

  // load transactions
  Future<void> getTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('transactions');
    if (jsonString != null && jsonString.isNotEmpty) {
      final jsonList = jsonDecode(jsonString) as List;
      transactions = jsonList.map((e) => Transaction.fromJson(e)).toList();
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

  void deleteTransaction(Transaction transactionToDelete) {
    transactions.remove(transactionToDelete);
    saveTransactions(transactions);
    notifyListeners();
  }

  // Get all unique months that have transactions
  List<DateTime> getAvailableMonths() {
    Set<String> monthKeys = {};
    for (var transaction in transactions) {
      String key = '${transaction.date.year}-${transaction.date.month}';
      monthKeys.add(key);
    }

    List<DateTime> months = monthKeys.map((key) {
      var parts = key.split('-');
      return DateTime(int.parse(parts[0]), int.parse(parts[1]));
    }).toList();

    months.sort((a, b) => b.compareTo(a)); // Sort descending (newest first)
    return months;
  }

  // Get transactions for a specific month and year
  List<Transaction> getTransactionsForMonth(DateTime month) {
    return transactions
        .where((transaction) =>
            transaction.date.year == month.year &&
            transaction.date.month == month.month)
        .toList();
  }

  // Calculate monthly summary
  Map<String, double> getMonthlySummary(DateTime month) {
    List<Transaction> monthTransactions = getTransactionsForMonth(month);
    double income = monthTransactions
        .where((t) => t.type == TransactionTyp.INCOME)
        .fold(0.0, (sum, t) => sum + t.amount);
    double expenses = monthTransactions
        .where((t) => t.type == TransactionTyp.EXPENSE)
        .fold(0.0, (sum, t) => sum + t.amount);

    return {
      'income': income,
      'expenses': expenses,
      'net': income - expenses,
    };
  }

  // Get all transactions sorted by date (newest first)
  List<Transaction> getAllTransactionsSorted() {
    List<Transaction> sorted = List.from(transactions);
    sorted.sort((a, b) => b.date.compareTo(a.date));
    return sorted;
  }

  // Export all transactions to CSV
  Future<void> exportTransactionsToCSV(Rect? sharePositionOrigin) async {
    try {
      // Create CSV data
      List<List<dynamic>> rows = [];

      // Add header row
      rows.add(['Date', 'Type', 'Category', 'Description', 'Amount']);

      // Sort transactions by date (oldest first for better readability in CSV)
      List<Transaction> sortedTransactions = List.from(transactions);
      sortedTransactions.sort((a, b) => a.date.compareTo(b.date));

      // Add transaction data
      for (var transaction in sortedTransactions) {
        rows.add([
          DateFormat('yyyy-MM-dd').format(transaction.date),
          transaction.type == TransactionTyp.INCOME ? 'Income' : 'Expense',
          transaction.category,
          transaction.description,
          transaction.amount.toStringAsFixed(2),
        ]);
      }

      // Convert to CSV string
      String csv = const ListToCsvConverter().convert(rows);

      // Get temporary directory
      final Directory tempDir = await getTemporaryDirectory();
      final String timestamp =
          DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final String filePath = '${tempDir.path}/transactions_$timestamp.csv';

      // Write to file
      final File file = File(filePath);
      await file.writeAsString(csv);

      // Share the file
      await Share.shareXFiles(
        [XFile(filePath)],
        subject: 'Budget Transactions Export',
        sharePositionOrigin: sharePositionOrigin,
      );
    } catch (e) {
      print('Error exporting transactions: $e');
      rethrow;
    }
  }
}
