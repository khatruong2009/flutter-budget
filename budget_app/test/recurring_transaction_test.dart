import 'package:flutter_test/flutter_test.dart';
import 'package:budget_app/recurring_transaction.dart';
import 'package:budget_app/transaction.dart';

void main() {
  group('RecurringTransaction Model Tests', () {
    test('should create a recurring transaction with all fields', () {
      final recurring = RecurringTransaction(
        type: TransactionTyp.expense,
        description: 'Netflix Subscription',
        amount: 15.99,
        category: 'Entertainment',
        pattern: RecurrencePattern.monthly,
        startDate: DateTime(2024, 1, 1),
        dayOfMonth: 1,
      );

      expect(recurring.id, isNotEmpty);
      expect(recurring.type, TransactionTyp.expense);
      expect(recurring.description, 'Netflix Subscription');
      expect(recurring.amount, 15.99);
      expect(recurring.category, 'Entertainment');
      expect(recurring.pattern, RecurrencePattern.monthly);
      expect(recurring.dayOfMonth, 1);
      expect(recurring.isActive, true);
    });

    test('should serialize and deserialize correctly', () {
      final original = RecurringTransaction(
        id: 'test-id',
        type: TransactionTyp.income,
        description: 'Salary',
        amount: 5000.0,
        category: 'Income',
        pattern: RecurrencePattern.monthly,
        startDate: DateTime(2024, 1, 15),
        nextOccurrence: DateTime(2024, 2, 15),
        dayOfMonth: 15,
      );

      final json = original.toJson();
      final deserialized = RecurringTransaction.fromJson(json);

      expect(deserialized.id, original.id);
      expect(deserialized.type, original.type);
      expect(deserialized.description, original.description);
      expect(deserialized.amount, original.amount);
      expect(deserialized.category, original.category);
      expect(deserialized.pattern, original.pattern);
      expect(deserialized.startDate, original.startDate);
      expect(deserialized.nextOccurrence, original.nextOccurrence);
      expect(deserialized.dayOfMonth, original.dayOfMonth);
      expect(deserialized.isActive, original.isActive);
    });

    test('should calculate next weekly occurrence', () {
      final recurring = RecurringTransaction(
        type: TransactionTyp.expense,
        description: 'Weekly Expense',
        amount: 50.0,
        category: 'Food',
        pattern: RecurrencePattern.weekly,
        startDate: DateTime(2024, 1, 1),
        nextOccurrence: DateTime(2024, 1, 1),
        dayOfWeek: 1,
      );

      final nextOccurrence = recurring.calculateNextOccurrence();
      expect(nextOccurrence, DateTime(2024, 1, 8));
    });

    test('should calculate next biweekly occurrence', () {
      final recurring = RecurringTransaction(
        type: TransactionTyp.expense,
        description: 'Biweekly Expense',
        amount: 100.0,
        category: 'Bills',
        pattern: RecurrencePattern.biweekly,
        startDate: DateTime(2024, 1, 1),
        nextOccurrence: DateTime(2024, 1, 1),
        dayOfWeek: 1,
      );

      final nextOccurrence = recurring.calculateNextOccurrence();
      expect(nextOccurrence, DateTime(2024, 1, 15));
    });

    test('should calculate next monthly occurrence', () {
      final recurring = RecurringTransaction(
        type: TransactionTyp.expense,
        description: 'Monthly Rent',
        amount: 1500.0,
        category: 'Housing',
        pattern: RecurrencePattern.monthly,
        startDate: DateTime(2024, 1, 15),
        nextOccurrence: DateTime(2024, 1, 15),
        dayOfMonth: 15,
      );

      final nextOccurrence = recurring.calculateNextOccurrence();
      expect(nextOccurrence, DateTime(2024, 2, 15));
    });

    test('should handle month with fewer days (day 31 in February)', () {
      final recurring = RecurringTransaction(
        type: TransactionTyp.expense,
        description: 'Monthly Bill',
        amount: 100.0,
        category: 'Bills',
        pattern: RecurrencePattern.monthly,
        startDate: DateTime(2024, 1, 31),
        nextOccurrence: DateTime(2024, 1, 31),
        dayOfMonth: 31,
      );

      final nextOccurrence = recurring.calculateNextOccurrence();
      // February 2024 is a leap year with 29 days
      expect(nextOccurrence, DateTime(2024, 2, 29));
    });

    test('should handle year boundary transition', () {
      final recurring = RecurringTransaction(
        type: TransactionTyp.expense,
        description: 'Monthly Subscription',
        amount: 20.0,
        category: 'Entertainment',
        pattern: RecurrencePattern.monthly,
        startDate: DateTime(2024, 12, 15),
        nextOccurrence: DateTime(2024, 12, 15),
        dayOfMonth: 15,
      );

      final nextOccurrence = recurring.calculateNextOccurrence();
      expect(nextOccurrence, DateTime(2025, 1, 15));
    });

    test('should generate transaction from template', () {
      final recurring = RecurringTransaction(
        type: TransactionTyp.expense,
        description: 'Gym Membership',
        amount: 50.0,
        category: 'Health',
        pattern: RecurrencePattern.monthly,
        startDate: DateTime(2024, 1, 1),
        dayOfMonth: 1,
      );

      final transaction = recurring.generateTransaction(DateTime(2024, 2, 1));

      expect(transaction.type, recurring.type);
      expect(transaction.description, recurring.description);
      expect(transaction.amount, recurring.amount);
      expect(transaction.category, recurring.category);
      expect(transaction.date, DateTime(2024, 2, 1));
    });

    test('should create copy with updated fields', () {
      final original = RecurringTransaction(
        type: TransactionTyp.expense,
        description: 'Original',
        amount: 100.0,
        category: 'Category',
        pattern: RecurrencePattern.monthly,
        startDate: DateTime(2024, 1, 1),
        dayOfMonth: 1,
      );

      final updated = original.copyWith(
        description: 'Updated',
        amount: 200.0,
      );

      expect(updated.id, original.id);
      expect(updated.description, 'Updated');
      expect(updated.amount, 200.0);
      expect(updated.category, original.category);
    });
  });
}
