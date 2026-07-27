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

  /// Encoded map of expense category names to monthly budget limits.
  /// Owned by `TransactionModel`.
  static const String categoryBudgetLimits = 'category_budget_limits';

  /// Encoded list of savings goals. Owned by `TransactionModel`.
  static const String savingsGoals = 'savings_goals';

  /// Encoded list of `RecurringTransaction` templates.
  /// Owned by `RecurringTransactionModel`.
  static const String recurringTransactions = 'recurring_transactions';

  /// One of `'light' | 'dark' | 'system'`. Owned by `ThemeProvider`.
  static const String themeMode = 'themeMode';

  /// Whether the first-launch app tour has been completed. Owned by
  /// `OnboardingTutorialGate`.
  static const String onboardingCompleted = 'onboarding_completed';

  /// Encoded list of user-manageable income and expense category definitions.
  /// Owned by `CategoryProvider`.
  static const String categories = 'categories_v1';

  /// ISO 4217 code used to format every amount. Owned by
  /// `AppSettingsProvider`.
  static const String baseCurrencyCode = 'base_currency_code';

  /// Optional locale override (for example `en_US`). An absent value follows
  /// the device locale. Owned by `AppSettingsProvider`.
  static const String localeOverride = 'locale_override';

  /// Privacy controls. Authentication enforcement is owned by the app shell;
  /// the preferences live in `AppSettingsProvider`.
  static const String appLockEnabled = 'app_lock_enabled';
  static const String autoLockTimeoutSeconds = 'auto_lock_timeout_seconds';
  static const String hideBalances = 'hide_balances';

  /// User-defined transaction tags and merchant categorization rules.
  static const String transactionTags = 'transaction_tags_v1';
  static const String categorizationRules = 'categorization_rules_v1';

  // --- Legacy keys (read-only, used for one-time migration) ---

  /// Pre-v2 single-value starting-assets total. Migrated into
  /// `netWorthEntries` on first load when no entries exist.
  static const String legacyStartingAssets = 'starting_assets';

  /// Pre-v2 single-value starting-liabilities total. Migrated into
  /// `netWorthEntries` on first load when no entries exist.
  static const String legacyStartingLiabilities = 'starting_liabilities';
}
