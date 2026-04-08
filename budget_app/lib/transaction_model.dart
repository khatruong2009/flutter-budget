import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'net_worth_entry.dart';
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

class TransactionModel extends ChangeNotifier {
  static const String _transactionsStorageKey = 'transactions';
  static const String _netWorthEntriesStorageKey = 'net_worth_entries';
  static const String _netWorthMonthStorageKey = 'net_worth_selected_month';

  List<Transaction> transactions = [];
  DateTime selectedMonth = DateTime.now();
  DateTime _selectedNetWorthMonth =
      DateTime(DateTime.now().year, DateTime.now().month);
  List<NetWorthEntry> _netWorthEntries = [];

  DateTime get selectedNetWorthMonth => _selectedNetWorthMonth;
  List<NetWorthEntry> get netWorthEntries =>
      List<NetWorthEntry>.unmodifiable(_netWorthEntries);
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
      _netWorthMonthStorageKey,
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
        _transactionsStorageKey, jsonEncode(jsonTransactions));
  }

  // load transactions
  Future<void> getTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_transactionsStorageKey);
    final netWorthEntriesJson = prefs.getString(_netWorthEntriesStorageKey);
    final netWorthMonthString = prefs.getString(_netWorthMonthStorageKey);

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
    };

    for (final entry in _netWorthEntries) {
      for (final snapshot in entry.snapshots) {
        monthKeys.add(snapshot.monthKey);
      }
    }

    final months = monthKeys.map(netWorthMonthFromKey).toList()
      ..sort((a, b) => b.compareTo(a));
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
      _netWorthEntriesStorageKey,
      jsonEncode(_netWorthEntries.map((entry) => entry.toJson()).toList()),
    );
  }

  Future<List<NetWorthEntry>> _migrateLegacyNetWorthIfNeeded(
    SharedPreferences prefs,
  ) async {
    final startingAssets = prefs.getDouble('starting_assets') ?? 0.0;
    final startingLiabilities = prefs.getDouble('starting_liabilities') ?? 0.0;
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
        _netWorthEntriesStorageKey,
        jsonEncode(migratedEntries.map((entry) => entry.toJson()).toList()),
      );
    }

    return migratedEntries;
  }
}
