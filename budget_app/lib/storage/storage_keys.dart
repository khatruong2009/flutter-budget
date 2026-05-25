/// Central registry of every `SharedPreferences` key the app reads or writes.
///
/// Every persisted value in the app must have its key declared here. This
/// makes migrations, audits, and "what's stored on disk" questions trivial.
///
/// When you add a new key:
///   1. Add a `static const String` here.
///   2. Reference it from the model that owns the data.
///   3. If you change an existing key, write a migration — users have data
///      under the old name.
class StorageKeys {
  StorageKeys._();

  /// Encoded list of all `Transaction` objects (income + expense).
  /// Owned by `TransactionModel`.
  static const String transactions = 'transactions';

  /// Encoded list of all `NetWorthEntry` objects (assets + liabilities with
  /// month-keyed snapshots). Owned by `TransactionModel`.
  static const String netWorthEntries = 'net_worth_entries';

  /// ISO8601 string of the currently-selected month on the Net Worth tab.
  /// Owned by `TransactionModel`.
  static const String netWorthSelectedMonth = 'net_worth_selected_month';

  /// Encoded list of `RecurringTransaction` templates.
  /// Owned by `RecurringTransactionModel`.
  static const String recurringTransactions = 'recurring_transactions';

  /// One of `'light' | 'dark' | 'system'`. Owned by `ThemeProvider`.
  static const String themeMode = 'themeMode';

  // --- Legacy keys (read-only, used for one-time migration) ---

  /// Pre-v2 single-value starting-assets total. Migrated into
  /// `netWorthEntries` on first load when no entries exist.
  static const String legacyStartingAssets = 'starting_assets';

  /// Pre-v2 single-value starting-liabilities total. Migrated into
  /// `netWorthEntries` on first load when no entries exist.
  static const String legacyStartingLiabilities = 'starting_liabilities';
}
