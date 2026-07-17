import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:csv/csv.dart';
import 'package:csv/csv_settings_autodetection.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'net_worth_entry.dart';
import 'savings_goal.dart';
import 'storage/storage_keys.dart';
import 'transaction.dart';
import 'utils/platform_utils.dart';

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
    final now = DateTime.now();
    final empty = MonthCashFlow(
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

class CategoryBudgetProgress {
  final String category;
  final double spent;
  final double limit;

  const CategoryBudgetProgress({
    required this.category,
    required this.spent,
    required this.limit,
  });

  double get remaining => limit - spent;
  double get progress => limit <= 0 ? 0.0 : spent / limit;
  bool get isOverBudget => limit > 0 && spent > limit;
}

class YearOverYearComparison {
  final DateTime currentMonth;
  final DateTime previousYearMonth;
  final double currentExpenses;
  final double previousYearExpenses;
  final Map<String, double> currentCategoryExpenses;
  final Map<String, double> previousYearCategoryExpenses;

  const YearOverYearComparison({
    required this.currentMonth,
    required this.previousYearMonth,
    required this.currentExpenses,
    required this.previousYearExpenses,
    required this.currentCategoryExpenses,
    required this.previousYearCategoryExpenses,
  });

  double get difference => currentExpenses - previousYearExpenses;
  double get percentChange {
    if (previousYearExpenses == 0) {
      return currentExpenses == 0 ? 0.0 : 100.0;
    }
    return (difference / previousYearExpenses) * 100;
  }

  List<String> get categories {
    final names = <String>{
      ...currentCategoryExpenses.keys,
      ...previousYearCategoryExpenses.keys,
    }.toList();
    names.sort((a, b) {
      final aTotal = (currentCategoryExpenses[a] ?? 0.0) +
          (previousYearCategoryExpenses[a] ?? 0.0);
      final bTotal = (currentCategoryExpenses[b] ?? 0.0) +
          (previousYearCategoryExpenses[b] ?? 0.0);
      final amountCompare = bTotal.compareTo(aTotal);
      if (amountCompare != 0) {
        return amountCompare;
      }
      return a.toLowerCase().compareTo(b.toLowerCase());
    });
    return names;
  }
}

// Result of parsing a CSV export: transactions ready to import plus
// diagnostics for skipped duplicates and malformed rows.
class CsvImportSummary {
  final List<Transaction> transactions;
  final int duplicateCount;
  final List<String> rowErrors;

  const CsvImportSummary({
    required this.transactions,
    required this.duplicateCount,
    required this.rowErrors,
  });
}

class TransactionModel extends ChangeNotifier {
  List<Transaction> transactions = [];
  DateTime selectedMonth = DateTime.now();
  DateTime _selectedNetWorthMonth =
      DateTime(DateTime.now().year, DateTime.now().month);
  List<NetWorthEntry> _netWorthEntries = [];
  Map<String, double> _categoryBudgetLimits = {};
  List<SavingsGoal> _savingsGoals = [];

  DateTime get selectedNetWorthMonth => _selectedNetWorthMonth;
  List<NetWorthEntry> get netWorthEntries =>
      List<NetWorthEntry>.unmodifiable(_netWorthEntries);
  Map<String, double> get categoryBudgetLimits =>
      Map<String, double>.unmodifiable(_categoryBudgetLimits);
  List<SavingsGoal> get savingsGoals =>
      List<SavingsGoal>.unmodifiable(_savingsGoals);
  List<NetWorthEntry> get assetEntriesForSelectedNetWorthMonth =>
      getNetWorthEntriesForMonth(
        _selectedNetWorthMonth,
        type: NetWorthEntryType.asset,
      );
  List<NetWorthEntry> get liabilityEntriesForSelectedNetWorthMonth =>
      getNetWorthEntriesForMonth(
        _selectedNetWorthMonth,
        type: NetWorthEntryType.liability,
      );
  double get totalAssets => getTotalAssetsForMonth(_selectedNetWorthMonth);
  double get totalLiabilities =>
      getTotalLiabilitiesForMonth(_selectedNetWorthMonth);
  double get netWorth => totalAssets - totalLiabilities;
  int get staleNetWorthEntryCount =>
      getStaleNetWorthEntryCountForMonth(_selectedNetWorthMonth);
  bool get hasNetWorthEntries => _netWorthEntries.isNotEmpty;

  // method to change selected month
  void selectMonth(DateTime date) {
    selectedMonth = DateTime(date.year, date.month);
    notifyListeners();
  }

  Future<void> selectNetWorthMonth(DateTime date) async {
    _selectedNetWorthMonth = DateTime(date.year, date.month);
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      StorageKeys.netWorthSelectedMonth,
      _selectedNetWorthMonth.toIso8601String(),
    );
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
    final newTransaction = Transaction(
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
    await prefs.setString(
        StorageKeys.transactions, jsonEncode(jsonTransactions));
    await _syncWidgetSafeToSpend();
  }

  static const MethodChannel _widgetDataChannel =
      MethodChannel('budget_app/widget_data');

  // Pushes the current calendar month's safe-to-spend to the iOS home screen
  // widgets via the shared app group.
  Future<void> _syncWidgetSafeToSpend() async {
    if (!PlatformUtils.isIOS) return;

    final now = DateTime.now();
    var safeToSpend = 0.0;
    for (final transaction in transactions) {
      if (transaction.date.year != now.year ||
          transaction.date.month != now.month) {
        continue;
      }
      safeToSpend += transaction.type == TransactionTyp.income
          ? transaction.amount
          : -transaction.amount;
    }

    try {
      await _widgetDataChannel.invokeMethod('updateSafeToSpend', {
        'amount': safeToSpend,
        'month': '${now.year}-${now.month.toString().padLeft(2, '0')}',
      });
    } on PlatformException {
      // Widget data is best-effort; never let it break a save.
    } on MissingPluginException {
      // Native handler absent (e.g. stale binary during development).
    }
  }

  // load transactions
  Future<void> getTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(StorageKeys.transactions);
    final netWorthEntriesJson = prefs.getString(StorageKeys.netWorthEntries);
    final netWorthMonthString =
        prefs.getString(StorageKeys.netWorthSelectedMonth);
    final categoryBudgetLimitsJson =
        prefs.getString(StorageKeys.categoryBudgetLimits);
    final savingsGoalsJson = prefs.getString(StorageKeys.savingsGoals);

    if (jsonString != null && jsonString.isNotEmpty) {
      final jsonList = jsonDecode(jsonString) as List<dynamic>;
      transactions = jsonList.map((e) => Transaction.fromJson(e)).toList();
    }

    if (netWorthEntriesJson != null && netWorthEntriesJson.isNotEmpty) {
      final jsonList = jsonDecode(netWorthEntriesJson) as List<dynamic>;
      _netWorthEntries = jsonList
          .map((entry) => NetWorthEntry.fromJson(entry as Map<String, dynamic>))
          .toList();
    } else {
      _netWorthEntries = await _migrateLegacyNetWorthIfNeeded(prefs);
    }

    if (netWorthMonthString != null && netWorthMonthString.isNotEmpty) {
      final parsedMonth = DateTime.tryParse(netWorthMonthString);
      if (parsedMonth != null) {
        _selectedNetWorthMonth = DateTime(parsedMonth.year, parsedMonth.month);
      }
    }

    if (categoryBudgetLimitsJson != null &&
        categoryBudgetLimitsJson.isNotEmpty) {
      final decoded =
          jsonDecode(categoryBudgetLimitsJson) as Map<String, dynamic>;
      _categoryBudgetLimits = decoded.map(
        (category, value) => MapEntry(category, (value as num).toDouble()),
      )..removeWhere((_, limit) => limit <= 0);
    }

    if (savingsGoalsJson != null && savingsGoalsJson.isNotEmpty) {
      final jsonList = jsonDecode(savingsGoalsJson) as List<dynamic>;
      _savingsGoals = jsonList
          .map((goal) => SavingsGoal.fromJson(goal as Map<String, dynamic>))
          .toList();
    }

    await _syncWidgetSafeToSpend();
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

  List<NetWorthEntry> getNetWorthEntriesForMonth(
    DateTime month, {
    NetWorthEntryType? type,
  }) {
    final entries = _netWorthEntries.where((entry) {
      if (type != null && entry.type != type) {
        return false;
      }
      return entry.amountForMonth(month) != null;
    }).toList();

    entries.sort((a, b) {
      final amountCompare = (b.amountForMonth(month) ?? 0.0)
          .compareTo(a.amountForMonth(month) ?? 0.0);
      if (amountCompare != 0) {
        return amountCompare;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return entries;
  }

  double getTotalAssetsForMonth(DateTime month) {
    return _sumNetWorthEntriesForMonth(month, NetWorthEntryType.asset);
  }

  double getTotalLiabilitiesForMonth(DateTime month) {
    return _sumNetWorthEntriesForMonth(month, NetWorthEntryType.liability);
  }

  double getNetWorthForMonth(DateTime month) {
    return getTotalAssetsForMonth(month) - getTotalLiabilitiesForMonth(month);
  }

  int getStaleNetWorthEntryCountForMonth(DateTime month) {
    final selectedMonthKey = netWorthMonthKey(month);
    return _netWorthEntries.where((entry) {
      final latestSnapshot =
          entry.latestSnapshotThrough(endOfNetWorthMonth(month));
      return latestSnapshot != null &&
          latestSnapshot.monthKey != selectedMonthKey;
    }).length;
  }

  List<NetWorthHistoryPoint> getNetWorthHistory({int limit = 24}) {
    final dayKeys = <String>{};

    for (final entry in _netWorthEntries) {
      for (final snapshot in entry.snapshots) {
        dayKeys.add(snapshot.dayKey);
      }
    }

    final hasSelectedMonthPoint = dayKeys.any((dayKey) {
      final date = netWorthDayFromKey(dayKey);
      return date.year == _selectedNetWorthMonth.year &&
          date.month == _selectedNetWorthMonth.month;
    });

    if (!hasSelectedMonthPoint &&
        hasNetWorthDataForMonth(_selectedNetWorthMonth)) {
      dayKeys.add(
          netWorthDayKey(_defaultSnapshotDateForMonth(_selectedNetWorthMonth)));
    }

    return _buildNetWorthHistoryPoints(dayKeys.toList(), limit);
  }

  List<DateTime> getNetWorthAvailableMonths() {
    final now = DateTime.now();
    final monthKeys = <String>{
      netWorthMonthKey(DateTime(now.year, now.month)),
      netWorthMonthKey(_selectedNetWorthMonth),
    };

    for (final entry in _netWorthEntries) {
      for (final snapshot in entry.snapshots) {
        monthKeys.add(snapshot.monthKey);
      }
    }

    final months = monthKeys.map(netWorthMonthFromKey).toList()
      ..sort((a, b) {
        final selected = _selectedNetWorthMonth;
        final aIsSelected =
            a.year == selected.year && a.month == selected.month;
        final bIsSelected =
            b.year == selected.year && b.month == selected.month;
        if (aIsSelected != bIsSelected) {
          return aIsSelected ? -1 : 1;
        }
        return b.compareTo(a);
      });
    return months;
  }

  bool hasNetWorthDataForMonth(DateTime month) {
    return _netWorthEntries.any((entry) => entry.amountForMonth(month) != null);
  }

  int getTrackedNetWorthEntryCountForMonth(DateTime month) {
    return _netWorthEntries
        .where((entry) => entry.amountForMonth(month) != null)
        .length;
  }

  int getUpdatedNetWorthEntryCountForMonth(DateTime month) {
    return _netWorthEntries
        .where((entry) => entry.snapshotForMonth(month) != null)
        .length;
  }

  Future<void> addNetWorthEntry({
    required String name,
    required NetWorthEntryType type,
    required double amount,
    DateTime? month,
    DateTime? recordedAt,
  }) async {
    final effectiveMonth = month ?? _selectedNetWorthMonth;
    final effectiveRecordedAt =
        recordedAt ?? _defaultSnapshotDateForMonth(effectiveMonth);
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      return;
    }

    _netWorthEntries = [
      ..._netWorthEntries,
      NetWorthEntry(
        name: trimmedName,
        type: type,
        snapshots: [
          NetWorthSnapshot.forDate(
            date: effectiveRecordedAt,
            amount: amount,
          ),
        ],
      ),
    ];

    await _saveNetWorthEntries();
    notifyListeners();
  }

  Future<void> updateNetWorthEntry({
    required String id,
    required String name,
    required NetWorthEntryType type,
    required double amount,
    DateTime? month,
    DateTime? recordedAt,
  }) async {
    final effectiveMonth = month ?? _selectedNetWorthMonth;
    final effectiveRecordedAt =
        recordedAt ?? _defaultSnapshotDateForMonth(effectiveMonth);
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      return;
    }

    _netWorthEntries = _netWorthEntries.map((entry) {
      if (entry.id != id) {
        return entry;
      }

      return entry
          .copyWith(name: trimmedName, type: type)
          .withSnapshot(date: effectiveRecordedAt, amount: amount);
    }).toList();

    await _saveNetWorthEntries();
    notifyListeners();
  }

  Future<void> deleteNetWorthEntry(String id) async {
    _netWorthEntries =
        _netWorthEntries.where((entry) => entry.id != id).toList();
    await _saveNetWorthEntries();
    notifyListeners();
  }

  Future<void> deleteNetWorthSnapshot({
    required String entryId,
    required DateTime recordedAt,
  }) async {
    var changed = false;

    _netWorthEntries = _netWorthEntries.map((entry) {
      if (entry.id != entryId) {
        return entry;
      }

      final updatedSnapshots = entry.snapshots
          .where((snapshot) => snapshot.recordedAt != recordedAt)
          .toList();
      changed = updatedSnapshots.length != entry.snapshots.length;
      return entry.copyWith(snapshots: updatedSnapshots);
    }).toList();

    if (!changed) {
      return;
    }

    await _saveNetWorthEntries();
    notifyListeners();
  }

  List<NetWorthSnapshot> getNetWorthEntryHistory(String id) {
    final entry = _netWorthEntries.cast<NetWorthEntry?>().firstWhere(
          (item) => item?.id == id,
          orElse: () => null,
        );
    if (entry == null) {
      return const [];
    }

    final history = List<NetWorthSnapshot>.from(entry.snapshots)
      ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
    return history;
  }

  Future<bool> carryNetWorthMonthForward(DateTime month) async {
    bool changed = false;
    final previousMonth = DateTime(month.year, month.month - 1);

    _netWorthEntries = _netWorthEntries.map((entry) {
      if (entry.hasSnapshotForMonth(month)) {
        return entry;
      }

      final previousSnapshot =
          entry.latestSnapshotThrough(endOfNetWorthMonth(previousMonth));
      if (previousSnapshot == null) {
        return entry;
      }

      changed = true;
      return entry.withSnapshot(
        date: _defaultSnapshotDateForMonth(month),
        amount: previousSnapshot.amount,
      );
    }).toList();

    if (!changed) {
      return false;
    }

    await _saveNetWorthEntries();
    notifyListeners();
    return true;
  }

  // Get all unique months that have transactions
  List<DateTime> getAvailableMonths() {
    final monthKeys = <String>{};
    for (final transaction in transactions) {
      final key = '${transaction.date.year}-${transaction.date.month}';
      monthKeys.add(key);
    }

    final months = monthKeys.map((key) {
      final parts = key.split('-');
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

  double? getCategoryBudgetLimit(String category) {
    return _categoryBudgetLimits[category];
  }

  Future<void> setCategoryBudgetLimit(String category, double limit) async {
    final trimmedCategory = category.trim();
    if (trimmedCategory.isEmpty) {
      return;
    }

    if (limit <= 0) {
      await removeCategoryBudgetLimit(trimmedCategory);
      return;
    }

    _categoryBudgetLimits = {
      ..._categoryBudgetLimits,
      trimmedCategory: limit,
    };
    await _saveCategoryBudgetLimits();
    notifyListeners();
  }

  Future<void> removeCategoryBudgetLimit(String category) async {
    if (!_categoryBudgetLimits.containsKey(category)) {
      return;
    }

    _categoryBudgetLimits = Map<String, double>.from(_categoryBudgetLimits)
      ..remove(category);
    await _saveCategoryBudgetLimits();
    notifyListeners();
  }

  double getCategorySpendingForMonth(String category, DateTime month) {
    return getTransactionsForMonth(month)
        .where((transaction) =>
            transaction.type == TransactionTyp.expense &&
            transaction.category == category)
        .fold(0.0, (sum, transaction) => sum + transaction.amount);
  }

  Map<String, double> getCategoryExpensesForMonth(DateTime month) {
    final totals = <String, double>{};
    for (final transaction in getTransactionsForMonth(month)
        .where((item) => item.type == TransactionTyp.expense)) {
      totals.update(
        transaction.category,
        (existing) => existing + transaction.amount,
        ifAbsent: () => transaction.amount,
      );
    }
    return totals;
  }

  List<CategoryBudgetProgress> getCategoryBudgetProgressForMonth(
    DateTime month,
  ) {
    final progress = _categoryBudgetLimits.entries
        .map(
          (entry) => CategoryBudgetProgress(
            category: entry.key,
            spent: getCategorySpendingForMonth(entry.key, month),
            limit: entry.value,
          ),
        )
        .toList();

    progress.sort((a, b) {
      final overBudgetCompare =
          (b.isOverBudget ? 1 : 0).compareTo(a.isOverBudget ? 1 : 0);
      if (overBudgetCompare != 0) {
        return overBudgetCompare;
      }
      final progressCompare = b.progress.compareTo(a.progress);
      if (progressCompare != 0) {
        return progressCompare;
      }
      return a.category.toLowerCase().compareTo(b.category.toLowerCase());
    });

    return progress;
  }

  Future<void> addSavingsGoal({
    required String name,
    required double targetAmount,
    required DateTime targetDate,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty || targetAmount <= 0) {
      return;
    }

    _savingsGoals = [
      ..._savingsGoals,
      SavingsGoal(
        name: trimmedName,
        targetAmount: targetAmount,
        targetDate: DateTime(targetDate.year, targetDate.month, targetDate.day),
      ),
    ];
    await _saveSavingsGoals();
    notifyListeners();
  }

  Future<void> updateSavingsGoal(SavingsGoal goal) async {
    final trimmedName = goal.name.trim();
    if (trimmedName.isEmpty || goal.targetAmount <= 0) {
      return;
    }

    var found = false;
    _savingsGoals = _savingsGoals.map((existingGoal) {
      if (existingGoal.id != goal.id) {
        return existingGoal;
      }

      found = true;
      final normalizedCurrent = goal.currentAmount.clamp(
        0.0,
        double.infinity,
      );
      final isCompleted = normalizedCurrent >= goal.targetAmount;
      return goal.copyWith(
        name: trimmedName,
        currentAmount: normalizedCurrent,
        completedAt: isCompleted ? goal.completedAt ?? DateTime.now() : null,
      );
    }).toList();

    if (!found) {
      return;
    }

    await _saveSavingsGoals();
    notifyListeners();
  }

  Future<void> deleteSavingsGoal(String id) async {
    final updatedGoals = _savingsGoals.where((goal) => goal.id != id).toList();
    if (updatedGoals.length == _savingsGoals.length) {
      return;
    }

    _savingsGoals = updatedGoals;
    await _saveSavingsGoals();
    notifyListeners();
  }

  Future<void> allocateToSavingsGoal(String goalId, double amount) async {
    if (amount == 0) {
      return;
    }

    var found = false;
    _savingsGoals = _savingsGoals.map((goal) {
      if (goal.id != goalId) {
        return goal;
      }

      found = true;
      final updatedAmount = (goal.currentAmount + amount).clamp(
        0.0,
        double.infinity,
      );
      final isCompleted = updatedAmount >= goal.targetAmount;
      return goal.copyWith(
        currentAmount: updatedAmount,
        completedAt: isCompleted ? goal.completedAt ?? DateTime.now() : null,
      );
    }).toList();

    if (!found) {
      return;
    }

    await _saveSavingsGoals();
    notifyListeners();
  }

  // Calculate monthly summary
  Map<String, double> getMonthlySummary(DateTime month) {
    final monthTransactions = getTransactionsForMonth(month);
    final income = monthTransactions
        .where((t) => t.type == TransactionTyp.income)
        .fold(0.0, (sum, t) => sum + t.amount);
    final expenses = monthTransactions
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
    final sorted = List<Transaction>.from(transactions);
    sorted.sort((a, b) => b.date.compareTo(a.date));
    return sorted;
  }

  // Export all transactions to CSV
  Future<void> exportTransactionsToCSV(Rect? sharePositionOrigin) async {
    try {
      // Create CSV data
      final rows = <List<dynamic>>[];

      // Add header row
      rows.add(['Date', 'Type', 'Category', 'Description', 'Amount']);

      // Sort transactions by date (oldest first for better readability in CSV)
      final sortedTransactions = List<Transaction>.from(transactions);
      sortedTransactions.sort((a, b) => a.date.compareTo(b.date));

      // Add transaction data
      for (final transaction in sortedTransactions) {
        rows.add([
          DateFormat('yyyy-MM-dd').format(transaction.date),
          transaction.type == TransactionTyp.income ? 'Income' : 'Expense',
          transaction.category,
          transaction.description,
          transaction.amount.toStringAsFixed(2),
        ]);
      }

      // Convert to CSV string
      final csv = const ListToCsvConverter().convert(rows);

      // Get temporary directory
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filePath = '${tempDir.path}/transactions_$timestamp.csv';

      // Write to file
      final file = File(filePath);
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

  // Parse a Date,Type,Category,Description,Amount CSV export into transactions,
  // deduplicating against existing rows. Does not persist or notify.
  CsvImportSummary parseTransactionsCsv(String csvContent) {
    var content = csvContent;
    if (content.isNotEmpty && content.codeUnitAt(0) == 0xFEFF) {
      content = content.substring(1);
    }

    final rows = const CsvToListConverter(
      shouldParseNumbers: false,
      csvSettingsDetector: FirstOccurrenceSettingsDetector(
        eols: ['\r\n', '\n'],
      ),
    ).convert(content);

    final header = rows.isEmpty ? const <dynamic>[] : rows.first;
    final headerMatches = header.length == 5 &&
        header[0].toString().trim().toLowerCase() == 'date' &&
        header[1].toString().trim().toLowerCase() == 'type' &&
        header[2].toString().trim().toLowerCase() == 'category' &&
        header[3].toString().trim().toLowerCase() == 'description' &&
        header[4].toString().trim().toLowerCase() == 'amount';
    if (rows.isEmpty || !headerMatches) {
      throw const FormatException('Not a valid transactions CSV export');
    }

    final parsed = <Transaction>[];
    final rowErrors = <String>[];

    // Row 1 is the header, so data rows are numbered from 2.
    for (var i = 1; i < rows.length; i++) {
      final rowNumber = i + 1;
      final row = rows[i];

      if (row.every((cell) => cell.toString().trim().isEmpty)) {
        continue;
      }

      if (row.length != 5) {
        rowErrors.add(
            'Row $rowNumber: expected 5 columns but found ${row.length}');
        continue;
      }

      final dateText = row[0].toString().trim();
      final date = DateTime.tryParse(dateText);
      // Dart normalizes out-of-range components ('2026-02-30' parses as
      // 2026-03-02), so require the text to match the parsed day to surface
      // typo'd dates as row errors instead of importing on a shifted date.
      if (date == null ||
          !dateText.startsWith(DateFormat('yyyy-MM-dd').format(date))) {
        rowErrors.add('Row $rowNumber: invalid date "$dateText"');
        continue;
      }

      final typeText = row[1].toString().trim();
      final typeLower = typeText.toLowerCase();
      if (typeLower != 'income' && typeLower != 'expense') {
        rowErrors.add('Row $rowNumber: invalid type "$typeText"');
        continue;
      }
      final type = typeLower == 'income'
          ? TransactionTyp.income
          : TransactionTyp.expense;

      final category = row[2].toString().trim();
      if (category.isEmpty) {
        rowErrors.add('Row $rowNumber: category is empty');
        continue;
      }

      final description = row[3].toString().trim();

      final amountText = row[4].toString().trim();
      var amountValue = amountText;
      if (amountValue.startsWith('\$')) {
        amountValue = amountValue.substring(1);
      }
      // Commas are only accepted as US-style thousands separators; stripping
      // them from anything else (e.g. the European decimal comma in
      // '1.234,56') would silently parse to the wrong magnitude.
      if (amountValue.contains(',')) {
        if (!RegExp(r'^\d{1,3}(,\d{3})+(\.\d+)?$').hasMatch(amountValue)) {
          rowErrors.add('Row $rowNumber: invalid amount "$amountText"');
          continue;
        }
        amountValue = amountValue.replaceAll(',', '');
      }
      final amount = double.tryParse(amountValue);
      if (amount == null || !amount.isFinite || amount < 0) {
        rowErrors.add('Row $rowNumber: invalid amount "$amountText"');
        continue;
      }

      parsed.add(Transaction(
        type: type,
        description: description,
        amount: amount,
        category: category,
        date: date,
      ));
    }

    // Multiset dedupe against existing transactions only. Two identical rows
    // within the file remain distinct except where they match remaining
    // existing counts.
    final existingCounts = <String, int>{};
    for (final transaction in transactions) {
      existingCounts.update(
        _csvDedupeKey(transaction),
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }

    final toImport = <Transaction>[];
    var duplicateCount = 0;
    for (final transaction in parsed) {
      final key = _csvDedupeKey(transaction);
      final remaining = existingCounts[key] ?? 0;
      if (remaining > 0) {
        existingCounts[key] = remaining - 1;
        duplicateCount++;
      } else {
        toImport.add(transaction);
      }
    }

    return CsvImportSummary(
      transactions: toImport,
      duplicateCount: duplicateCount,
      rowErrors: rowErrors,
    );
  }

  // Append parsed transactions from a CSV import and persist them.
  Future<void> importTransactions(List<Transaction> newTransactions) async {
    if (newTransactions.isEmpty) {
      return;
    }
    transactions.addAll(newTransactions);
    await saveTransactions(transactions);
    notifyListeners();
  }

  // Full-replace restore from a decoded backup. Wipes the in-memory state this
  // model owns, replaces it with the backup's contents, and persists all of it.
  Future<void> restoreFromBackup({
    required List<Transaction> transactions,
    required List<NetWorthEntry> netWorthEntries,
    required Map<String, double> categoryBudgetLimits,
    required List<SavingsGoal> savingsGoals,
  }) async {
    this.transactions = List<Transaction>.of(transactions);
    _netWorthEntries = List<NetWorthEntry>.of(netWorthEntries);
    _categoryBudgetLimits = Map<String, double>.of(categoryBudgetLimits)
      ..removeWhere((_, limit) => limit <= 0);
    _savingsGoals = List<SavingsGoal>.of(savingsGoals);

    await saveTransactions(this.transactions);
    await _saveNetWorthEntries();
    await _saveCategoryBudgetLimits();
    await _saveSavingsGoals();

    notifyListeners();
  }

  // Multiset dedupe key: identical transactions collapse to the same string.
  // Amount is normalized with toStringAsFixed(2) and text fields are trimmed
  // to mirror what the CSV export/parse round-trip does to a transaction, so
  // an exported row always keys the same as the transaction it came from.
  String _csvDedupeKey(Transaction transaction) {
    final date = DateFormat('yyyy-MM-dd').format(transaction.date);
    final type =
        transaction.type == TransactionTyp.income ? 'income' : 'expense';
    final amount = transaction.amount.toStringAsFixed(2);
    return '$date|$type|${transaction.category.trim()}|'
        '${transaction.description.trim()}|$amount';
  }

  // Get net cash flow data for all months (for charting)
  List<MonthCashFlow> getNetCashFlowHistory() {
    final months = getAvailableMonths();
    return months.reversed.map((month) {
      final summary = getMonthlySummary(month);
      return MonthCashFlow(
        month: month,
        netCashFlow: summary['net'] ?? 0.0,
        income: summary['income'] ?? 0.0,
        expenses: summary['expenses'] ?? 0.0,
      );
    }).toList();
  }

  List<MonthCashFlow> getRollingCashFlowTrend({int months = 12}) {
    if (months <= 0) {
      return const [];
    }

    final now = DateTime.now();
    final start = DateTime(now.year, now.month - months + 1);
    return List<MonthCashFlow>.generate(months, (index) {
      final month = DateTime(start.year, start.month + index);
      final summary = getMonthlySummary(month);
      return MonthCashFlow(
        month: month,
        netCashFlow: summary['net'] ?? 0.0,
        income: summary['income'] ?? 0.0,
        expenses: summary['expenses'] ?? 0.0,
      );
    });
  }

  YearOverYearComparison getYearOverYearComparison(DateTime month) {
    final normalizedMonth = DateTime(month.year, month.month);
    final previousYearMonth =
        DateTime(normalizedMonth.year - 1, normalizedMonth.month);
    return YearOverYearComparison(
      currentMonth: normalizedMonth,
      previousYearMonth: previousYearMonth,
      currentExpenses: getMonthlySummary(normalizedMonth)['expenses'] ?? 0.0,
      previousYearExpenses:
          getMonthlySummary(previousYearMonth)['expenses'] ?? 0.0,
      currentCategoryExpenses: getCategoryExpensesForMonth(normalizedMonth),
      previousYearCategoryExpenses:
          getCategoryExpensesForMonth(previousYearMonth),
    );
  }

  // Get summary statistics for cash flow history
  CashFlowStatistics getCashFlowStatistics() {
    final history = getNetCashFlowHistory();
    if (history.isEmpty) {
      return CashFlowStatistics.empty();
    }

    final average = history.map((m) => m.netCashFlow).reduce((a, b) => a + b) /
        history.length;

    final best = history.reduce(
      (a, b) => a.netCashFlow > b.netCashFlow ? a : b,
    );

    final worst = history.reduce(
      (a, b) => a.netCashFlow < b.netCashFlow ? a : b,
    );

    return CashFlowStatistics(
      average: average,
      bestMonth: best,
      worstMonth: worst,
    );
  }

  double _sumNetWorthEntriesForMonth(
    DateTime month,
    NetWorthEntryType type,
  ) {
    return _sumNetWorthEntriesAtDate(endOfNetWorthMonth(month), type);
  }

  double _sumNetWorthEntriesAtDate(
    DateTime date,
    NetWorthEntryType type,
  ) {
    return _netWorthEntries
        .where((entry) => entry.type == type)
        .map((entry) => entry.amountAt(date) ?? 0.0)
        .fold(0.0, (sum, amount) => sum + amount);
  }

  double _getTotalAssetsAtDate(DateTime date) {
    return _sumNetWorthEntriesAtDate(date, NetWorthEntryType.asset);
  }

  double _getTotalLiabilitiesAtDate(DateTime date) {
    return _sumNetWorthEntriesAtDate(date, NetWorthEntryType.liability);
  }

  int _countNetWorthEntriesAtDate(
    DateTime date,
    NetWorthEntryType type,
  ) {
    return _netWorthEntries
        .where((entry) => entry.type == type)
        .where((entry) => entry.amountAt(date) != null)
        .length;
  }

  List<NetWorthHistoryPoint> _buildNetWorthHistoryPoints(
    List<String> dayKeys,
    int limit,
  ) {
    if (dayKeys.isEmpty || limit <= 0) {
      return const [];
    }

    final sortedKeys = dayKeys.toList()..sort((a, b) => b.compareTo(a));
    final monthBuckets = <String, List<String>>{};
    for (final dayKey in sortedKeys) {
      final monthKey = netWorthMonthKey(netWorthDayFromKey(dayKey));
      monthBuckets.putIfAbsent(monthKey, () => []).add(dayKey);
    }

    final compressedMonths = <String>{};
    var pointCount = sortedKeys.length;
    final oldestMonthsFirst = monthBuckets.keys.toList()..sort();

    for (final monthKey in oldestMonthsFirst) {
      if (pointCount <= limit) {
        break;
      }

      final bucket = monthBuckets[monthKey] ?? const [];
      final reduciblePoints = bucket.length - 1;
      if (reduciblePoints <= 0) {
        continue;
      }

      compressedMonths.add(monthKey);
      pointCount -= reduciblePoints;
    }

    final points = <NetWorthHistoryPoint>[];
    for (final monthKey in monthBuckets.keys) {
      final bucket = monthBuckets[monthKey] ?? const [];
      if (compressedMonths.contains(monthKey)) {
        final month = netWorthMonthFromKey(monthKey);
        points.add(
          _buildNetWorthHistoryPoint(
            displayDate: endOfNetWorthMonth(month),
            effectiveDate: endOfNetWorthMonth(month),
            granularity: NetWorthHistoryGranularity.month,
          ),
        );
        continue;
      }

      for (final dayKey in bucket) {
        final day = netWorthDayFromKey(dayKey);
        points.add(
          _buildNetWorthHistoryPoint(
            displayDate: day,
            effectiveDate: endOfNetWorthDay(day),
          ),
        );
      }
    }

    return points.take(limit).toList();
  }

  NetWorthHistoryPoint _buildNetWorthHistoryPoint({
    required DateTime displayDate,
    required DateTime effectiveDate,
    NetWorthHistoryGranularity granularity = NetWorthHistoryGranularity.day,
  }) {
    return NetWorthHistoryPoint(
      date: displayDate,
      assets: _getTotalAssetsAtDate(effectiveDate),
      liabilities: _getTotalLiabilitiesAtDate(effectiveDate),
      assetCount:
          _countNetWorthEntriesAtDate(effectiveDate, NetWorthEntryType.asset),
      liabilityCount: _countNetWorthEntriesAtDate(
          effectiveDate, NetWorthEntryType.liability),
      granularity: granularity,
    );
  }

  DateTime _defaultSnapshotDateForMonth(DateTime month) {
    final normalizedMonth = DateTime(month.year, month.month);
    final now = DateTime.now();
    if (normalizedMonth.year == now.year &&
        normalizedMonth.month == now.month) {
      return now;
    }

    return endOfNetWorthMonth(normalizedMonth);
  }

  Future<void> _saveNetWorthEntries() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      StorageKeys.netWorthEntries,
      jsonEncode(_netWorthEntries.map((entry) => entry.toJson()).toList()),
    );
  }

  Future<void> _saveCategoryBudgetLimits() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      StorageKeys.categoryBudgetLimits,
      jsonEncode(_categoryBudgetLimits),
    );
  }

  Future<void> _saveSavingsGoals() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      StorageKeys.savingsGoals,
      jsonEncode(_savingsGoals.map((goal) => goal.toJson()).toList()),
    );
  }

  Future<List<NetWorthEntry>> _migrateLegacyNetWorthIfNeeded(
    SharedPreferences prefs,
  ) async {
    final startingAssets =
        prefs.getDouble(StorageKeys.legacyStartingAssets) ?? 0.0;
    final startingLiabilities =
        prefs.getDouble(StorageKeys.legacyStartingLiabilities) ?? 0.0;
    final migratedEntries = <NetWorthEntry>[];
    final currentMonth = DateTime.now();

    if (startingAssets > 0) {
      migratedEntries.add(
        NetWorthEntry(
          name: 'Starting Assets',
          type: NetWorthEntryType.asset,
          snapshots: [
            NetWorthSnapshot.forDate(
              date: currentMonth,
              amount: startingAssets,
            ),
          ],
        ),
      );
    }

    if (startingLiabilities > 0) {
      migratedEntries.add(
        NetWorthEntry(
          name: 'Starting Liabilities',
          type: NetWorthEntryType.liability,
          snapshots: [
            NetWorthSnapshot.forDate(
              date: currentMonth,
              amount: startingLiabilities,
            ),
          ],
        ),
      );
    }

    if (migratedEntries.isNotEmpty) {
      await prefs.setString(
        StorageKeys.netWorthEntries,
        jsonEncode(migratedEntries.map((entry) => entry.toJson()).toList()),
      );
    }

    return migratedEntries;
  }
}
