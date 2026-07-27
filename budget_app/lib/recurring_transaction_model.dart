import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'recurring_transaction.dart';
import 'storage/storage_keys.dart';
import 'storage/atomic_financial_store.dart';
import 'transaction.dart';

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

  Future<void> renameCategory({
    required TransactionTyp type,
    required String oldName,
    required String newName,
  }) async {
    var changed = false;
    recurringTransactions = recurringTransactions.map((template) {
      if (template.type != type || template.category != oldName) {
        return template;
      }
      changed = true;
      return template.copyWith(category: newName);
    }).toList();
    if (!changed) return;
    await saveRecurringTransactions();
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
    await AtomicFinancialStore.instance.updateSection(
      FinancialSections.recurringTransactions,
      jsonTransactions,
    );
    await prefs.setString(
        StorageKeys.recurringTransactions, jsonEncode(jsonTransactions));
  }

  /// Full-replace restore from a decoded backup. Replaces every template and
  /// persists the result.
  Future<void> restoreFromBackup(List<RecurringTransaction> templates) async {
    recurringTransactions = List<RecurringTransaction>.of(templates);
    await saveRecurringTransactions();
    notifyListeners();
  }

  /// Load recurring transactions from SharedPreferences
  Future<void> loadRecurringTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    final snapshot = await AtomicFinancialStore.instance.read();
    final stored = snapshot.sections[FinancialSections.recurringTransactions];
    if (stored is List && stored.isNotEmpty) {
      final jsonList = stored;
      recurringTransactions =
          jsonList.map((e) => RecurringTransaction.fromJson(e)).toList();
      notifyListeners();
    } else {
      final jsonString = prefs.getString(StorageKeys.recurringTransactions);
      if (jsonString != null && jsonString.isNotEmpty) {
        final jsonList = jsonDecode(jsonString) as List;
        recurringTransactions =
            jsonList.map((e) => RecurringTransaction.fromJson(e)).toList();
        await saveRecurringTransactions();
        notifyListeners();
      }
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
              isSameDay(r.nextOccurrence, asOf));
    }).toList();
  }
}
