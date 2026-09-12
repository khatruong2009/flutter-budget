import 'package:flutter/material.dart';
import 'recurring_transaction.dart';
import 'storage/atomic_financial_store.dart';
import 'storage/persistence_status.dart';
import 'transaction.dart';

/// State management class for recurring transactions
/// Extends ChangeNotifier to integrate with Provider pattern
class RecurringTransactionModel extends ChangeNotifier with PersistenceStatus {
  List<RecurringTransaction> recurringTransactions = [];

  /// Add a new recurring transaction. Resolves to whether the change was
  /// verified on disk; a false result is also reflected by
  /// [hasUnsavedChanges].
  Future<bool> addRecurringTransaction(RecurringTransaction recurring) {
    recurringTransactions.add(recurring);
    notifyListeners();
    return saveRecurringTransactions();
  }

  /// Update an existing recurring transaction by ID
  Future<bool> updateRecurringTransaction(
    String id,
    RecurringTransaction updated,
  ) async {
    final index = recurringTransactions.indexWhere((r) => r.id == id);
    if (index == -1) return false;
    recurringTransactions[index] = updated;
    notifyListeners();
    return saveRecurringTransactions();
  }

  /// Delete a recurring transaction by ID
  Future<bool> deleteRecurringTransaction(String id) {
    recurringTransactions.removeWhere((r) => r.id == id);
    notifyListeners();
    return saveRecurringTransactions();
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
    notifyListeners();
    await saveRecurringTransactions();
  }

  /// Get a specific recurring transaction by ID
  RecurringTransaction? getRecurringTransaction(String id) {
    try {
      return recurringTransactions.firstWhere((r) => r.id == id);
    } catch (e) {
      return null;
    }
  }

  @override
  dynamic serializeSection(String section) {
    assert(section == FinancialSections.recurringTransactions);
    return recurringTransactions.map((r) => r.toJson()).toList();
  }

  /// Persist the templates to the financial store and confirm the write.
  Future<bool> saveRecurringTransactions() {
    return persistSections({
      FinancialSections.recurringTransactions:
          serializeSection(FinancialSections.recurringTransactions),
    });
  }

  /// Full-replace restore from a decoded backup. Replaces every template and
  /// persists the result.
  Future<void> restoreFromBackup(List<RecurringTransaction> templates) async {
    recurringTransactions = List<RecurringTransaction>.of(templates);
    notifyListeners();
    await saveRecurringTransactions();
  }

  /// Load recurring transactions from the financial store.
  Future<void> loadRecurringTransactions() async {
    final snapshot = await AtomicFinancialStore.instance.read();
    final stored = snapshot.sections[FinancialSections.recurringTransactions];
    if (stored is List && stored.isNotEmpty) {
      recurringTransactions =
          stored.map((e) => RecurringTransaction.fromJson(e)).toList();
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
              isSameDay(r.nextOccurrence, asOf));
    }).toList();
  }
}
