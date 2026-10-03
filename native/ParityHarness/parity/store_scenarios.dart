// Builds realistic stores by driving the real app models, the same calls the
// UI makes. Shared by store_fixtures_test.dart and legacy_fixtures_test.dart.

import 'package:budget_app/categorization_rule.dart';
import 'package:budget_app/category_definition.dart';
import 'package:budget_app/net_worth_entry.dart';
import 'package:budget_app/recurring_transaction.dart';
import 'package:budget_app/storage/atomic_financial_store.dart';
import 'package:budget_app/transaction.dart';
import 'package:budget_app/transaction_generator.dart';

import 'harness_support.dart';

/// A clock that moves forward a little between operations, so timestamps
/// differ and carry non-zero microseconds.
class TickingClock {
  DateTime _now;
  TickingClock(this._now) {
    pinClock(_now);
  }
  DateTime get now => _now;
  void tick([Duration by = const Duration(seconds: 1, microseconds: 1234)]) {
    _now = _now.add(by);
    pinClock(_now);
  }

  void set(DateTime value) {
    _now = value;
    pinClock(_now);
  }
}

Future<void> _add(AppHarness app, TickingClock clock, TransactionTyp type,
    String description, double amount, String category, DateTime date,
    {List<String> tagIds = const []}) async {
  clock.tick();
  final ok = await app.transactionModel
      .addTransaction(type, description, amount, category, date, tagIds: tagIds);
  if (!ok) throw StateError('save failed for $description');
}

/// The "typical" store: sixteen months of activity touching every section and
/// every enum value, with the awkward values real users produce.
Future<void> buildTypicalStore(AppHarness app) async {
  final clock = TickingClock(DateTime(2025, 6, 1, 9, 0, 0, 0, 123));
  await app.initialize(generate: false);

  clock.tick();
  await app.appSettings.setBaseCurrencyCode('eur');
  clock.tick();
  await app.appSettings.setLocaleOverride('de_DE');
  clock.tick();
  await app.appSettings.setAppLockEnabled(true);
  clock.tick();
  await app.appSettings.setAutoLockTimeoutSeconds(300);

  clock.tick();
  final work = await app.categorizationProvider.addTag('Work');
  clock.tick();
  final vacation = await app.categorizationProvider
      .addTag('Vacation 🏖️', colorToken: 'cyan');
  clock.tick();
  await app.categorizationProvider.addRule(CategorizationRule(
    merchantPattern: '  Starbucks ',
    category: 'Eating Out',
    transactionType: TransactionTyp.expense,
    maximumAmount: 20.0,
    tagIds: [work.id],
    priority: 2,
  ));
  clock.tick();
  await app.categorizationProvider.addRule(CategorizationRule(
    merchantPattern: 'ACME PAYROLL',
    matchType: MerchantMatchType.startsWith,
    category: 'Salary',
    transactionType: TransactionTyp.income,
    minimumAmount: 1000.0,
  ));
  clock.tick();
  await app.categorizationProvider.addRule(CategorizationRule(
    merchantPattern: 'rent',
    matchType: MerchantMatchType.exact,
    category: 'Housing',
    isEnabled: false,
  ));
  clock.tick();
  await app.categoryProvider.addCategory(
    type: BudgetCategoryType.expense,
    name: 'Pet Food',
    iconIdentifier: 'paw',
    colorToken: 'green',
  );
  clock.tick();
  await app.categoryProvider.addCategory(
    type: BudgetCategoryType.income,
    name: 'Side Gig ✨',
    iconIdentifier: 'wrench',
    colorToken: 'orange',
  );

  // Sixteen months of ordinary activity.
  for (var i = 0; i < 16; i++) {
    final year = 2025 + (5 + i) ~/ 12;
    final month = (5 + i) % 12 + 1;
    clock.set(DateTime(year, month, 28, 20, 15, 0, 0, 500 + i));
    await _add(app, clock, TransactionTyp.income, 'ACME PAYROLL', 4200.0,
        'Salary', DateTime(year, month, 1));
    await _add(app, clock, TransactionTyp.expense, 'Rent', 1500.0, 'Housing',
        DateTime(year, month, 3));
    await _add(app, clock, TransactionTyp.expense, 'Groceries', 87.45 + i,
        'Groceries', DateTime(year, month, 9, 18, 2, 11, 250, 17));
    await _add(app, clock, TransactionTyp.expense, 'Starbucks', 6.35,
        'Eating Out', DateTime(year, month, 12, 12, 34, 56, 789, 12),
        tagIds: [work.id]);
    await _add(app, clock, TransactionTyp.expense, 'Kibble', 42.0, 'Pet Food',
        DateTime(year, month, 20));
    if (i % 3 == 0) {
      await _add(app, clock, TransactionTyp.income, 'Freelance', 350.75,
          'Side Gig ✨', DateTime(year, month, 15, 9));
    }
  }

  // Awkward values.
  clock.set(DateTime(2026, 9, 20, 8, 0, 0, 0, 1));
  final awkward = <(TransactionTyp, String, double, String, DateTime)>[
    (TransactionTyp.expense, 'Café ☕️ 🍰 déjà vu', 4.5, 'Eating Out',
        DateTime(2026, 9, 2, 7, 45)),
    (TransactionTyp.expense, 'bad \uD83D surrogate', 1.0, 'General',
        DateTime(2026, 9, 2)),
    (TransactionTyp.expense, 'Book "Dart", vol 2\nsecond line\ttab', 39.99,
        'General', DateTime(2026, 9, 3)),
    (TransactionTyp.expense, '', 3.0, 'General', DateTime(2026, 9, 4)),
    (TransactionTyp.expense, '=SUM(A1)', 0.30000000000000004, 'General',
        DateTime(2026, 9, 5)),
    (TransactionTyp.expense, 'tiny', 1e-7, 'General', DateTime(2026, 9, 5)),
    (TransactionTyp.income, 'big', 1234567.891, 'Other', DateTime(2026, 9, 6)),
    (TransactionTyp.expense, 'negative', -12.5, 'General',
        DateTime(2026, 9, 6)),
    (TransactionTyp.expense, 'denormal', 5e-324, 'General',
        DateTime(2026, 9, 7)),
    (TransactionTyp.expense, 'huge', 1.5e300, 'General', DateTime(2026, 9, 7)),
    (TransactionTyp.expense, 'round', 100.0, 'General', DateTime(2026, 9, 8)),
    (TransactionTyp.expense, 'half cent', 0.015, 'General',
        DateTime(2026, 9, 8)),
    (TransactionTyp.expense, 'leap day', 29.0, 'General',
        DateTime(2024, 2, 29)),
    (TransactionTyp.expense, 'dst gap', 2.0, 'General',
        DateTime(2026, 3, 8, 2, 30)),
    (TransactionTyp.expense, 'dst overlap', 3.0, 'General',
        DateTime(2026, 11, 1, 1, 30)),
    (TransactionTyp.expense, 'month end', 31.0, 'General',
        DateTime(2026, 1, 31, 23, 59, 59, 999, 999)),
    (TransactionTyp.expense, 'month start', 1.0, 'General',
        DateTime(2026, 2, 1)),
    (TransactionTyp.expense, '  padded  ', 7.0, '  Padded Cat ',
        DateTime(2026, 9, 9)),
    (TransactionTyp.expense, 'Gift for mom', 25.0, 'Gift',
        DateTime(2026, 9, 10)),
    (TransactionTyp.income, 'Gift from mom', 25.0, 'Gift',
        DateTime(2026, 9, 10)),
  ];
  for (final row in awkward) {
    await _add(app, clock, row.$1, row.$2, row.$3, row.$4, row.$5,
        tagIds: row.$2.startsWith('Café') ? [vacation.id, work.id] : const []);
  }

  // Edits: the second edit lands on the same pinned instant, which exercises
  // the +1 microsecond updatedAt bump.
  final model = app.transactionModel;
  final target = model.transactions.firstWhere((t) => t.description == 'round');
  clock.tick();
  await model.updateTransaction(
      target.id, target.copyWith(amount: 101.25, category: 'Groceries'));
  final edited = model.transactions.firstWhere((t) => t.id == target.id);
  await model.updateTransaction(
      edited.id, edited.copyWith(description: 'round (edited twice)'));
  final doomed = model.transactions.firstWhere((t) => t.description == 'tiny');
  clock.tick();
  await model.deleteTransactionById(doomed.id);

  // Budgets.
  clock.tick();
  await model.setCategoryBudgetLimit('Groceries', 400.0);
  clock.tick();
  await model.setCategoryBudgetLimit(' Eating Out ', 150.5);
  clock.tick();
  await model.setCategoryBudgetLimit('Pet Food', 60.0);
  clock.tick();
  await model.setCategoryBudgetLimit('Travel', 10.0);
  clock.tick();
  await model.removeCategoryBudgetLimit('Travel');

  // Savings goals.
  clock.tick();
  await model.addSavingsGoal(
      name: 'Vacation', targetAmount: 3000.0, targetDate: DateTime(2026, 12, 20));
  clock.tick();
  await model.addSavingsGoal(
      name: 'Emergency', targetAmount: 1000.0, targetDate: DateTime(2027, 6, 1));
  clock.tick();
  await model.allocateToSavingsGoal(model.savingsGoals.first.id, 500.0);
  clock.tick();
  await model.allocateToSavingsGoal(model.savingsGoals.last.id, 1000.0);

  // Net worth: past months (end-of-month sentinel snapshots), a carry
  // forward, a current-month update (now-stamped snapshot), a delete.
  clock.set(DateTime(2026, 4, 10, 11, 5, 7, 42, 9));
  await model.addNetWorthEntry(
      name: 'Checking',
      type: NetWorthEntryType.asset,
      amount: 2500.0,
      month: DateTime(2026, 1));
  await model.addNetWorthEntry(
      name: ' Mortgage ',
      type: NetWorthEntryType.liability,
      amount: 250000.0,
      month: DateTime(2026, 1));
  await model.addNetWorthEntry(
      name: 'Brokerage',
      type: NetWorthEntryType.asset,
      amount: 10000.5,
      recordedAt: DateTime(2026, 2, 14, 16, 30, 0, 0, 7));
  final checking =
      model.netWorthEntries.firstWhere((e) => e.name == 'Checking');
  await model.updateNetWorthEntry(
      id: checking.id,
      name: 'Checking',
      type: NetWorthEntryType.asset,
      amount: 2750.25,
      month: DateTime(2026, 2));
  await model.carryNetWorthMonthForward(DateTime(2026, 3));
  clock.tick();
  await model.updateNetWorthEntry(
      id: checking.id,
      name: 'Checking',
      type: NetWorthEntryType.asset,
      amount: 3100.0,
      month: DateTime(2026, 4));
  clock.tick();
  await model.updateNetWorthEntry(
      id: checking.id,
      name: 'Checking',
      type: NetWorthEntryType.asset,
      amount: 3150.0,
      month: DateTime(2026, 4));
  final mortgage =
      model.netWorthEntries.firstWhere((e) => e.name == 'Mortgage');
  await model.deleteNetWorthSnapshot(
      entryId: mortgage.id,
      recordedAt: mortgage.snapshots.last.recordedAt);
  await model.selectNetWorthMonth(DateTime(2026, 2, 17));

  // Recurring templates across every pattern, a day-31 monthly, a
  // time-of-day start (form default), and a paused template.
  final recurring = app.recurringModel;
  Future<void> addTemplate(RecurringTransaction t) async {
    clock.tick();
    if (!await recurring.addRecurringTransaction(t)) {
      throw StateError('template save failed');
    }
  }

  await addTemplate(RecurringTransaction(
      type: TransactionTyp.expense,
      description: 'Gym',
      amount: 45.0,
      category: 'Health',
      pattern: RecurrencePattern.weekly,
      startDate: DateTime(2026, 2, 22),
      dayOfWeek: DateTime(2026, 2, 22).weekday));
  await addTemplate(RecurringTransaction(
      type: TransactionTyp.income,
      description: 'Paycheck',
      amount: 1850.0,
      category: 'Salary',
      pattern: RecurrencePattern.biweekly,
      startDate: DateTime(2026, 2, 23),
      dayOfWeek: DateTime(2026, 2, 23).weekday));
  await addTemplate(RecurringTransaction(
      type: TransactionTyp.expense,
      description: 'Rent (recurring)',
      amount: 1500.0,
      category: 'Housing',
      pattern: RecurrencePattern.monthly,
      startDate: DateTime(2026, 1, 31),
      dayOfMonth: 31));
  await addTemplate(RecurringTransaction(
      type: TransactionTyp.expense,
      description: 'Streaming',
      amount: 15.99,
      category: 'Entertainment',
      pattern: RecurrencePattern.monthly,
      startDate: DateTime(2026, 3, 15, 14, 32, 11, 123, 456),
      dayOfMonth: 15));
  await addTemplate(RecurringTransaction(
      type: TransactionTyp.expense,
      description: 'Paused magazine',
      amount: 9.0,
      category: 'Entertainment',
      pattern: RecurrencePattern.monthly,
      startDate: DateTime(2026, 1, 5),
      dayOfMonth: 5,
      isActive: false));

  clock.set(DateTime(2026, 4, 10, 10, 30));
  await TransactionGenerator(
    transactionModel: model,
    recurringModel: recurring,
  ).generateDueTransactions();

  // Final store revision is whatever these calls produced.
  await AtomicFinancialStore.instance.read();
}

/// Old-schema rows as earlier app versions wrote them (keys missing, legacy
/// snapshot shape, lenient savings goal values). Written as raw sections.
Map<String, dynamic> oldSchemaSections() => {
      'transactions': [
        {
          'type': 'expense',
          'description': 'no id, no timestamps, no tags',
          'amount': 12,
          'category': 'Groceries',
          'date': '2025-03-04T00:00:00.000',
        },
        {
          'id': 'dup-id',
          'type': 'income',
          'description': 'first dup',
          'amount': 100.0,
          'category': 'Salary',
          'date': '2025-03-01T00:00:00.000',
          'recurringTemplateId': null,
          'tagIds': [],
        },
        {
          'id': 'dup-id',
          'type': 'expense',
          'description': 'second dup',
          'amount': 5.5,
          'category': 'General',
          'date': '2025-03-02T08:00:00.000',
          'createdAt': 12345,
        },
        {
          'id': '   ',
          'type': 'EXPENSE',
          'description': 'blank id, odd type',
          'amount': 1.25,
          'category': 'General',
          'date': '2025-03-05T00:00:00.000',
          'tagIds': ['t1', 7, null],
        },
      ],
      'netWorthEntries': [
        {
          'id': 'nw-legacy',
          'name': 'Legacy Savings',
          'type': 'asset',
          'createdAt': '2024-12-01T10:00:00.000',
          'snapshots': [
            {'monthKey': '2024-12', 'amount': 800},
            {
              'monthKey': '2025-01',
              'updatedAt': '2025-01-15T09:30:00.000',
              'amount': 900.5
            },
            {
              'monthKey': '2025-02',
              'updatedAt': '2025-03-02T09:30:00.000',
              'amount': 950.0
            },
          ],
        },
      ],
      'recurringTransactions': [
        {
          'id': 'rt-old',
          'type': 'expense',
          'description': 'Old template without isActive',
          'amount': 20.0,
          'category': 'General',
          'pattern': 'monthly',
          'startDate': '2025-01-10T00:00:00.000',
          'nextOccurrence': '2025-04-10T00:00:00.000',
          'dayOfMonth': 10,
        },
      ],
      'savingsGoals': [
        {
          'name': '  ',
          'targetAmount': '1500.50',
          'currentAmount': -3,
          'targetDate': '',
        },
      ],
      'categoryBudgetLimits': {'Groceries': 250, 'Zero': 0, 'Negative': -5.0},
      'categories': [
        {'id': 'expense-general', 'name': 'General'},
        {
          'id': 'income-salary',
          'type': 'income',
          'name': 'Salary',
          'sortOrder': 3.0,
        },
      ],
      'selectedNetWorthMonth': '2025-02-17T13:00:00.000',
    };

/// Unknown future data: a whole unknown section, unknown keys inside known
/// rows, and an unknown key in appSettings.
Map<String, dynamic> unknownDataSections(Map<String, dynamic> base) {
  final sections = Map<String, dynamic>.from(base);
  final transactions = (sections['transactions'] as List)
      .map((row) => Map<String, dynamic>.from(row as Map))
      .toList();
  transactions[0] = {
    ...transactions[0],
    'merchant': {'name': 'ACME', 'mcc': 5411, 'score': 0.75},
    'splits': [],
  };
  sections['transactions'] = transactions;
  sections['appSettings'] = {
    ...Map<String, dynamic>.from(sections['appSettings'] as Map),
    'futureToggle': true,
  };
  sections['futureFeature'] = {
    'enabled': true,
    'weights': [1, 2.5, -0.0, 1e-7, 1e+21],
    'nested': {'z': 1, 'a': null, 'emoji': '🙂', 'escape': 'line\nbreak "q"'},
  };
  return sections;
}
