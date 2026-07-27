import 'dart:convert';

import 'package:flutter/material.dart' show ThemeMode;

import 'net_worth_entry.dart';
import 'category_definition.dart';
import 'categorization_rule.dart';
import 'recurring_transaction.dart';
import 'savings_goal.dart';
import 'transaction.dart';
import 'transaction_tag.dart';

/// Bumped whenever the backup envelope or any covered model's serialization
/// changes in a way that older apps could not read.
const int kBackupSchemaVersion = 3;

/// Everything a full backup carries. Pure data — no IO, no persistence.
class BackupData {
  final List<Transaction> transactions;
  final List<NetWorthEntry> netWorthEntries;
  final Map<String, double> categoryBudgetLimits;
  final List<SavingsGoal> savingsGoals;
  final List<RecurringTransaction> recurringTransactions;
  final ThemeMode? themeMode; // null => do not change theme on restore
  final List<BudgetCategory> categories;
  final List<TransactionTag> transactionTags;
  final List<CategorizationRule> categorizationRules;
  final String baseCurrencyCode;
  final String? localeOverride;
  final bool appLockEnabled;
  final int autoLockTimeoutSeconds;
  final bool hideBalances;

  const BackupData({
    required this.transactions,
    required this.netWorthEntries,
    required this.categoryBudgetLimits,
    required this.savingsGoals,
    required this.recurringTransactions,
    this.themeMode,
    this.categories = const [],
    this.transactionTags = const [],
    this.categorizationRules = const [],
    this.baseCurrencyCode = 'USD',
    this.localeOverride,
    this.appLockEnabled = false,
    this.autoLockTimeoutSeconds = 60,
    this.hideBalances = false,
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
      'categories': data.categories.map((item) => item.toJson()).toList(),
      'transactionTags':
          data.transactionTags.map((item) => item.toJson()).toList(),
      'categorizationRules':
          data.categorizationRules.map((item) => item.toJson()).toList(),
      'baseCurrencyCode': data.baseCurrencyCode,
      'localeOverride': data.localeOverride,
      'appLockEnabled': data.appLockEnabled,
      'autoLockTimeoutSeconds': data.autoLockTimeoutSeconds,
      'hideBalances': data.hideBalances,
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

  final categories = _decodeList(data['categories'], BudgetCategory.fromJson);
  final tags = _decodeList(data['transactionTags'], TransactionTag.fromJson);
  final rules =
      _decodeList(data['categorizationRules'], CategorizationRule.fromJson);
  final categoryIds = categories.map((item) => item.id).toSet();
  final tagIds = tags.map((item) => item.id).toSet();
  final ruleIds = rules.map((item) => item.id).toSet();
  _require(categoryIds.length == categories.length);
  _require(tagIds.length == tags.length && ruleIds.length == rules.length);
  _require(rules.every(
    (rule) => rule.tagIds.every(tagIds.contains),
  ));
  if (categories.isNotEmpty) {
    _require(BudgetCategoryType.values.every(
      (type) => categories.any(
        (category) => category.type == type && !category.isArchived,
      ),
    ));
  }
  final localeRaw = data['localeOverride'];
  _require(localeRaw == null || localeRaw is String);
  final appLockRaw = data['appLockEnabled'];
  final hideBalancesRaw = data['hideBalances'];
  _require(appLockRaw == null || appLockRaw is bool);
  _require(hideBalancesRaw == null || hideBalancesRaw is bool);
  final timeoutRaw = data['autoLockTimeoutSeconds'];
  _require(timeoutRaw == null || timeoutRaw is num);
  final timeout = (timeoutRaw as num?)?.toInt() ?? 60;
  _require(timeout >= 0);

  return BackupData(
    transactions: _decodeList(data['transactions'], _backupTransaction),
    netWorthEntries: _decodeList(data['netWorthEntries'], _backupNetWorthEntry),
    categoryBudgetLimits: _decodeBudgetLimits(data['categoryBudgetLimits']),
    savingsGoals: _decodeList(data['savingsGoals'], _backupSavingsGoal),
    recurringTransactions:
        _decodeList(data['recurringTransactions'], _backupRecurring),
    themeMode: _themeModeFromString(data['themeMode']),
    categories: categories,
    transactionTags: tags,
    categorizationRules: rules,
    baseCurrencyCode: _decodeCurrency(data['baseCurrencyCode']),
    localeOverride: localeRaw as String?,
    appLockEnabled: appLockRaw as bool? ?? false,
    autoLockTimeoutSeconds: timeout,
    hideBalances: hideBalancesRaw as bool? ?? false,
  );
}

String _decodeCurrency(dynamic raw) {
  if (raw == null) return 'USD';
  if (raw is! String || raw.trim().length != 3) {
    throw const FormatException('This backup has an invalid currency.');
  }
  return raw.trim().toUpperCase();
}

// The model fromJson factories are lenient: unknown type strings coerce to a
// default, and non-finite numbers pass through even though jsonEncode cannot
// re-serialize them (which would fail midway through the store-by-store
// restore persistence, leaving a partial wipe). Restore is destructive, so
// the backup path validates strictly before accepting an entry.
void _require(bool condition) {
  if (!condition) {
    throw const FormatException('This backup file is corrupt or incomplete.');
  }
}

Transaction _backupTransaction(Map<String, dynamic> json) {
  _require(json['type'] == 'expense' || json['type'] == 'income');
  final transaction = Transaction.fromJson(json);
  _require(transaction.amount.isFinite);
  return transaction;
}

NetWorthEntry _backupNetWorthEntry(Map<String, dynamic> json) {
  _require(json['type'] == 'asset' || json['type'] == 'liability');
  final entry = NetWorthEntry.fromJson(json);
  _require(entry.snapshots.every((snapshot) => snapshot.amount.isFinite));
  return entry;
}

SavingsGoal _backupSavingsGoal(Map<String, dynamic> json) {
  final goal = SavingsGoal.fromJson(json);
  _require(goal.targetAmount.isFinite && goal.currentAmount.isFinite);
  return goal;
}

RecurringTransaction _backupRecurring(Map<String, dynamic> json) {
  _require(json['type'] == 'expense' || json['type'] == 'income');
  final recurring = RecurringTransaction.fromJson(json);
  _require(recurring.amount.isFinite);
  // TransactionGenerator dereferences dayOfMonth for monthly templates and
  // loops on the computed next occurrence, so an absent or out-of-range day
  // would crash or hang every subsequent launch.
  if (recurring.pattern == RecurrencePattern.monthly) {
    final day = recurring.dayOfMonth;
    _require(day != null && day >= 1 && day <= 31);
  }
  return recurring;
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
    return list.map((item) => fromJson(item as Map<String, dynamic>)).toList();
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
    return map.map((category, value) {
      final limit = (value as num).toDouble();
      _require(limit.isFinite);
      return MapEntry(category, limit);
    });
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
