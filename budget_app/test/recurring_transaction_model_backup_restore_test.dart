import 'package:budget_app/recurring_transaction.dart';
import 'package:budget_app/recurring_transaction_model.dart';
import 'package:budget_app/transaction.dart';
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
}
