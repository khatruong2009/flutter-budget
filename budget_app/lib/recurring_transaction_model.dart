import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'recurring_transaction.dart';

/// State management class for recurring transactions
/// Extends ChangeNotifier to integrate with Provider pattern
class RecurringTransactionModel extends ChangeNotifier {
  List<RecurringTransaction> recurringTransactions = [];

  /// Add a new recurring transaction
  void addRecurringTransaction(RecurringTransaction recurring) {
    recurringTransactions.add(recurring);
    saveRecurringTransactions();
    notifyListeners();
  }

  /// Update an existing recurring transaction by ID
  void updateRecurringTransaction(String id, RecurringTransaction updated) {
    final index = recurringTransactions.indexWhere((r) => r.id == id);
    if (index != -1) {
      recurringTransactions[index] = updated;
      saveRecurringTransactions();
      notifyListeners();
    }
  }

  /// Delete a recurring transaction by ID
  void deleteRecurringTransaction(String id) {
    recurringTransactions.removeWhere((r) => r.id == id);
    saveRecurringTransactions();
    notifyListeners();
  }

  /// Get a specific recurring transaction by ID
  RecurringTransaction? getRecurringTransaction(String id) {
    try {
      return recurringTransactions.firstWhere((r) => r.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Save recurring transactions to SharedPreferences
  Future<void> saveRecurringTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonTransactions =
        recurringTransactions.map((r) => r.toJson()).toList();
    await prefs.setString('recurring_transactions', jsonEncode(jsonTransactions));
  }

  /// Load recurring transactions from SharedPreferences
  Future<void> loadRecurringTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('recurring_transactions');
    if (jsonString != null && jsonString.isNotEmpty) {
      final jsonList = jsonDecode(jsonString) as List;
      recurringTransactions =
          jsonList.map((e) => RecurringTransaction.fromJson(e)).toList();
      notifyListeners();
    }
  }

  /// Get all active recurring transactions
  List<RecurringTransaction> getActiveRecurringTransactions() {
    return recurringTransactions.where((r) => r.isActive).toList();
  }

  /// Get recurring transactions that are due (nextOccurrence <= asOf date)
  List<RecurringTransaction> getDueRecurringTransactions(DateTime asOf) {
    return recurringTransactions.where((r) {
      return r.isActive &&
          (r.nextOccurrence.isBefore(asOf) ||
              _isSameDay(r.nextOccurrence, asOf));
    }).toList();
  }

  /// Helper method to check if two dates are the same day
  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
