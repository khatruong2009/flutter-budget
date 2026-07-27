import 'package:budget_app/transaction.dart';
import 'package:budget_app/voice_expense_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final service = VoiceExpenseService();
  final today = DateTime(2026, 7, 10, 15);

  test('parses a typed expense locally into a transaction-form prefill',
      () async {
    final transaction =
        await service.parse(r'$12.50 lunch at Chipotle yesterday', today);

    expect(transaction.type, TransactionTyp.expense);
    expect(transaction.amount, 12.5);
    expect(transaction.category, 'Eating Out');
    expect(transaction.description, 'lunch at Chipotle');
    expect(transaction.date, DateTime(2026, 7, 9));
  });

  test('detects income and its category without a remote service', () async {
    final transaction = await service.parse('received salary 3,250', today);

    expect(transaction.type, TransactionTyp.income);
    expect(transaction.amount, 3250);
    expect(transaction.category, 'Salary');
  });

  test('unknown details use safe editable defaults', () async {
    final transaction = await service.parse('farmers market', today);

    expect(transaction.type, TransactionTyp.expense);
    expect(transaction.amount, 0);
    expect(transaction.category, 'General');
    expect(transaction.date, DateTime(2026, 7, 10));
  });

  test('empty text is rejected without any network fallback', () async {
    await expectLater(
      service.parse('   ', today),
      throwsA(isA<VoiceExpenseException>()),
    );
  });
}
