import 'package:budget_app/recurring_transaction.dart';
import 'package:budget_app/recurring_transaction_model.dart';
import 'package:budget_app/transaction.dart';
import 'package:budget_app/transaction_generator.dart';
import 'package:budget_app/transaction_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  final replacements = <RecurringTransaction>[
    RecurringTransaction(
      id: 'new-1',
      type: TransactionTyp.income,
      description: 'Paycheck',
      amount: 2000.0,
      category: 'Income',
      pattern: RecurrencePattern.biweekly,
      startDate: DateTime(2026, 1, 1),
      nextOccurrence: DateTime(2026, 1, 15),
      dayOfWeek: 5,
    ),
    RecurringTransaction(
      id: 'new-2',
      type: TransactionTyp.expense,
      description: 'Rent',
      amount: 1500.0,
      category: 'Housing',
      pattern: RecurrencePattern.monthly,
      startDate: DateTime(2026, 1, 1),
      nextOccurrence: DateTime(2026, 2, 1),
      dayOfMonth: 1,
    ),
  ];

  test('restore replaces templates and persists them', () async {
    final model = RecurringTransactionModel();
    model.addRecurringTransaction(
      RecurringTransaction(
        id: 'old-1',
        type: TransactionTyp.expense,
        description: 'Old Gym',
        amount: 40.0,
        category: 'Health',
        pattern: RecurrencePattern.weekly,
        startDate: DateTime(2025, 1, 1),
        nextOccurrence: DateTime(2025, 1, 8),
        dayOfWeek: 4,
      ),
    );

    await model.restoreFromBackup(replacements);

    expect(model.recurringTransactions, replacements);
    expect(
      model.recurringTransactions.any((r) => r.id == 'old-1'),
      isFalse,
    );

    final reloaded = RecurringTransactionModel();
    await reloaded.loadRecurringTransactions();
    expect(reloaded.recurringTransactions, replacements);
  });

  test('generator fills occurrences due since the restored cursor', () async {
    // A restored backup carries each template's cursor as of export time;
    // running the generator right after restore must create the occurrences
    // that came due since then (the restore flow in settings does this).
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = today.subtract(const Duration(days: 10));

    final recurringModel = RecurringTransactionModel();
    final transactionModel = TransactionModel();

    await recurringModel.restoreFromBackup([
      RecurringTransaction(
        id: 'rec-restored',
        type: TransactionTyp.expense,
        description: 'Rent',
        amount: 900.0,
        category: 'Housing',
        pattern: RecurrencePattern.weekly,
        startDate: start,
        nextOccurrence: start,
      ),
    ]);

    await TransactionGenerator(
      transactionModel: transactionModel,
      recurringModel: recurringModel,
    ).generateDueTransactions();

    // Weekly from 10 days ago: occurrences at day -10 and day -3.
    expect(transactionModel.transactions.length, 2);
    expect(
      transactionModel.transactions
          .every((t) => t.recurringTemplateId == 'rec-restored'),
      isTrue,
    );
    expect(
      recurringModel.recurringTransactions.single.nextOccurrence.isAfter(now),
      isTrue,
    );
  });
}
