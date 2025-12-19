import 'transaction_model.dart';
import 'recurring_transaction.dart';
import 'recurring_transaction_model.dart';

/// Service responsible for generating actual transactions from recurring templates
/// Checks for due recurring transactions and creates corresponding transactions
class TransactionGenerator {
  final TransactionModel transactionModel;
  final RecurringTransactionModel recurringModel;

  TransactionGenerator({
    required this.transactionModel,
    required this.recurringModel,
  });

  /// Main entry point - called on app launch
  /// Checks all recurring transactions and generates due transactions
  Future<void> generateDueTransactions() async {
    final now = DateTime.now();
    final dueRecurring = recurringModel.getDueRecurringTransactions(now);

    for (var recurring in dueRecurring) {
      await _generateMissedTransactions(recurring, now);
    }
  }

  /// Generate all missed occurrences up to current date
  /// Implements 90-day lookback limit to prevent generating too many old transactions
  Future<void> _generateMissedTransactions(
    RecurringTransaction recurring,
    DateTime upTo,
  ) async {
    // 90-day lookback limit
    final maxLookback = upTo.subtract(const Duration(days: 90));
    DateTime current = recurring.nextOccurrence;

    // Generate transactions for all missed occurrences
    while (current.isBefore(upTo) || _isSameDay(current, upTo)) {
      // Only generate if within lookback window
      if (current.isAfter(maxLookback) || _isSameDay(current, maxLookback)) {
        final transaction = recurring.generateTransaction(current);
        transactionModel.addTransaction(
          transaction.type,
          transaction.description,
          transaction.amount,
          transaction.category,
          transaction.date,
          recurringTemplateId: recurring.id,
        );
      }
      
      // Calculate next occurrence
      current = _calculateNextOccurrence(recurring, current);
    }

    // Update the recurring transaction's next occurrence date
    final updatedRecurring = recurring.copyWith(nextOccurrence: current);
    recurringModel.updateRecurringTransaction(recurring.id, updatedRecurring);
  }

  /// Calculate next occurrence based on recurrence pattern
  DateTime _calculateNextOccurrence(
    RecurringTransaction recurring,
    DateTime from,
  ) {
    switch (recurring.pattern) {
      case RecurrencePattern.weekly:
        return from.add(const Duration(days: 7));
      case RecurrencePattern.biweekly:
        return from.add(const Duration(days: 14));
      case RecurrencePattern.monthly:
        return _calculateNextMonthlyOccurrence(from, recurring.dayOfMonth!);
    }
  }

  /// Handle monthly recurrence with day-of-month logic
  /// Handles edge cases like day 31 in months with fewer days
  DateTime _calculateNextMonthlyOccurrence(DateTime from, int dayOfMonth) {
    int nextMonth = from.month + 1;
    int nextYear = from.year;

    // Handle year boundary
    if (nextMonth > 12) {
      nextMonth = 1;
      nextYear++;
    }

    // Handle months with fewer days
    // Get the last day of the next month
    int daysInMonth = DateTime(nextYear, nextMonth + 1, 0).day;
    int actualDay = dayOfMonth > daysInMonth ? daysInMonth : dayOfMonth;

    return DateTime(nextYear, nextMonth, actualDay);
  }

  /// Helper method to check if two dates are the same day
  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
