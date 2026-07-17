import 'dart:convert';

import 'package:flutter/material.dart' show ThemeMode;

import 'net_worth_entry.dart';
import 'recurring_transaction.dart';
import 'savings_goal.dart';
import 'transaction.dart';

/// Bumped whenever the backup envelope or any covered model's serialization
/// changes in a way that older apps could not read.
const int kBackupSchemaVersion = 1;

/// Everything a full backup carries. Pure data — no IO, no persistence.
class BackupData {
  final List<Transaction> transactions;
  final List<NetWorthEntry> netWorthEntries;
  final Map<String, double> categoryBudgetLimits;
  final List<SavingsGoal> savingsGoals;
  final List<RecurringTransaction> recurringTransactions;
  final ThemeMode? themeMode; // null => do not change theme on restore

  const BackupData({
    required this.transactions,
    required this.netWorthEntries,
    required this.categoryBudgetLimits,
    required this.savingsGoals,
    required this.recurringTransactions,
    this.themeMode,
  });
}

/// Serialize [data] to a versioned, pretty-printed JSON envelope.
String encodeBackup(
  BackupData data, {
  required String appVersion,
  required DateTime exportedAt,
}) {
  final envelope = <String, dynamic>{
    'schemaVersion': kBackupSchemaVersion,
    'app': 'budgie',
    'appVersion': appVersion,
    'exportedAt': exportedAt.toIso8601String(),
    'data': <String, dynamic>{
      'transactions': data.transactions.map((t) => t.toJson()).toList(),
      'netWorthEntries': data.netWorthEntries.map((e) => e.toJson()).toList(),
      'categoryBudgetLimits': data.categoryBudgetLimits,
      'savingsGoals': data.savingsGoals.map((g) => g.toJson()).toList(),
      'recurringTransactions':
          data.recurringTransactions.map((r) => r.toJson()).toList(),
      'themeMode': _themeModeToString(data.themeMode),
    },
  };

  return const JsonEncoder.withIndent('  ').convert(envelope);
}

/// Parse and validate a backup file. This guards a destructive restore, so it
/// is strict: anything malformed throws a [FormatException] with a
/// user-facing message rather than silently dropping data.
BackupData decodeBackup(String content) {
  var text = content;
  if (text.isNotEmpty && text.codeUnitAt(0) == 0xFEFF) {
    text = text.substring(1);
  }

  dynamic decoded;
  try {
    decoded = jsonDecode(text);
  } on FormatException {
    throw const FormatException('This is not a valid Budgie backup file');
  }

  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('This is not a valid Budgie backup file');
  }

  final schemaVersion = decoded['schemaVersion'];
  if (schemaVersion is! int) {
    throw const FormatException('This is not a valid Budgie backup file');
  }
  if (schemaVersion > kBackupSchemaVersion) {
    throw const FormatException(
      'This backup was made by a newer version of Budgie. '
      'Update the app and try again.',
    );
  }

  final data = decoded['data'];
  if (data is! Map<String, dynamic>) {
    throw const FormatException('This backup file is missing its data.');
  }

  return BackupData(
    transactions: _decodeList(data['transactions'], Transaction.fromJson),
    netWorthEntries:
        _decodeList(data['netWorthEntries'], NetWorthEntry.fromJson),
    categoryBudgetLimits: _decodeBudgetLimits(data['categoryBudgetLimits']),
    savingsGoals: _decodeList(data['savingsGoals'], SavingsGoal.fromJson),
    recurringTransactions:
        _decodeList(data['recurringTransactions'], RecurringTransaction.fromJson),
    themeMode: _themeModeFromString(data['themeMode']),
  );
}

// An absent or null section is a valid empty section. A present-but-wrong-type
// section, or an entry the model cannot parse, is corruption — turn any raw
// error into a FormatException rather than letting it escape or dropping data.
List<T> _decodeList<T>(
  dynamic raw,
  T Function(Map<String, dynamic>) fromJson,
) {
  if (raw == null) {
    return <T>[];
  }
  try {
    final list = raw as List;
    return list
        .map((item) => fromJson(item as Map<String, dynamic>))
        .toList();
  } catch (_) {
    throw const FormatException('This backup file is corrupt or incomplete.');
  }
}

Map<String, double> _decodeBudgetLimits(dynamic raw) {
  if (raw == null) {
    return <String, double>{};
  }
  try {
    final map = raw as Map<String, dynamic>;
    return map.map(
      (category, value) => MapEntry(category, (value as num).toDouble()),
    );
  } catch (_) {
    throw const FormatException('This backup file is corrupt or incomplete.');
  }
}

String? _themeModeToString(ThemeMode? mode) {
  switch (mode) {
    case ThemeMode.light:
      return 'light';
    case ThemeMode.dark:
      return 'dark';
    case ThemeMode.system:
      return 'system';
    case null:
      return null;
  }
}

// Absent, null, or an unknown string all map to null (do not change theme).
ThemeMode? _themeModeFromString(dynamic raw) {
  switch (raw) {
    case 'light':
      return ThemeMode.light;
    case 'dark':
      return ThemeMode.dark;
    case 'system':
      return ThemeMode.system;
    default:
      return null;
  }
}
