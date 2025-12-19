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

// Data class for monthly cash flow information
class MonthCashFlow {
  final DateTime month;
  final double netCashFlow;
  final double income;
  final double expenses;

  MonthCashFlow({
    required this.month,
    required this.netCashFlow,
    required this.income,
    required this.expenses,
  });
}

// Data class for cash flow statistics
class CashFlowStatistics {
  final double average;
  final MonthCashFlow bestMonth;
  final MonthCashFlow worstMonth;

  CashFlowStatistics({
    required this.average,
    required this.bestMonth,
    required this.worstMonth,
  });

  factory CashFlowStatistics.empty() {
    DateTime now = DateTime.now();
    MonthCashFlow empty = MonthCashFlow(
      month: now,
      netCashFlow: 0.0,
      income: 0.0,
      expenses: 0.0,
    );
    return CashFlowStatistics(
      average: 0.0,
      bestMonth: empty,
      worstMonth: empty,
    );
  }
}

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
        .where((transaction) => transaction.type == TransactionTyp.income)
        .map((transaction) => transaction.amount)
        .fold(0, (previousValue, amount) => previousValue + amount);
  }

  // Calculate total expenses for selected month
  double get totalExpenses {
    return currentMonthTransactions
        .where((transaction) => transaction.type == TransactionTyp.expense)
        .map((transaction) => transaction.amount)
        .fold(0, (previousValue, amount) => previousValue + amount);
  }

  // add transaction
  void addTransaction(
    TransactionTyp type,
    String description,
    double amount,
    String category,
    DateTime date, {
    String? recurringTemplateId,
  }) {
    Transaction newTransaction = Transaction(
      type: type,
      description: description,
      amount: amount,
      category: category,
      date: date,
      recurringTemplateId: recurringTemplateId,
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
        .where((t) => t.type == TransactionTyp.income)
        .fold(0.0, (sum, t) => sum + t.amount);
    double expenses = monthTransactions
        .where((t) => t.type == TransactionTyp.expense)
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
          transaction.type == TransactionTyp.income ? 'Income' : 'Expense',
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
      debugPrint('Error exporting transactions: $e');
      rethrow;
    }
  }

  // Get net cash flow data for all months (for charting)
  List<MonthCashFlow> getNetCashFlowHistory() {
    List<DateTime> months = getAvailableMonths();
    return months.reversed.map((month) {
      Map<String, double> summary = getMonthlySummary(month);
      return MonthCashFlow(
        month: month,
        netCashFlow: summary['net'] ?? 0.0,
        income: summary['income'] ?? 0.0,
        expenses: summary['expenses'] ?? 0.0,
      );
    }).toList();
  }

  // Get summary statistics for cash flow history
  CashFlowStatistics getCashFlowStatistics() {
    List<MonthCashFlow> history = getNetCashFlowHistory();
    if (history.isEmpty) {
      return CashFlowStatistics.empty();
    }

    double average = history
            .map((m) => m.netCashFlow)
            .reduce((a, b) => a + b) /
        history.length;

    MonthCashFlow best = history.reduce(
      (a, b) => a.netCashFlow > b.netCashFlow ? a : b,
    );

    MonthCashFlow worst = history.reduce(
      (a, b) => a.netCashFlow < b.netCashFlow ? a : b,
    );

    return CashFlowStatistics(
      average: average,
      bestMonth: best,
      worstMonth: worst,
    );
  }
}
