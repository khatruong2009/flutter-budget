import 'package:budget_app/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

Transaction _expense({
  required String description,
  required DateTime date,
  required DateTime createdAt,
}) {
  return Transaction(
    type: TransactionTyp.expense,
    description: description,
    amount: 10,
    category: 'Dining',
    date: date,
    createdAt: createdAt,
  );
}

void main() {
  test('same-day entries order by when they were recorded, newest first', () {
    // The picker and voice parsing produce midnight; the form defaults to now.
    final morningEntry = _expense(
      description: 'Coffee',
      date: DateTime(2026, 7, 28, 9, 15),
      createdAt: DateTime(2026, 7, 28, 9, 15),
    );
    final midnightEntry = _expense(
      description: 'Lunch',
      date: DateTime(2026, 7, 28),
      createdAt: DateTime(2026, 7, 28, 12, 40),
    );
    final latestEntry = _expense(
      description: 'Groceries',
      date: DateTime(2026, 7, 28, 18, 5),
      createdAt: DateTime(2026, 7, 28, 18, 5),
    );

    final sorted = [morningEntry, latestEntry, midnightEntry]
      ..sort(Transaction.compareNewestFirst);

    expect(
      sorted.map((t) => t.description).toList(),
      ['Groceries', 'Lunch', 'Coffee'],
    );
  });

  test('days still order newest first regardless of time component', () {
    final today = _expense(
      description: 'Today',
      date: DateTime(2026, 7, 28),
      createdAt: DateTime(2026, 7, 28, 8),
    );
    final yesterdayEvening = _expense(
      description: 'Yesterday',
      date: DateTime(2026, 7, 27, 23, 30),
      createdAt: DateTime(2026, 7, 27, 23, 30),
    );

    final sorted = [yesterdayEvening, today]
      ..sort(Transaction.compareNewestFirst);

    expect(sorted.map((t) => t.description).toList(), ['Today', 'Yesterday']);
  });

  test('identical timestamps still order deterministically', () {
    final timestamp = DateTime(2026, 7, 28);
    final a = _expense(
      description: 'A',
      date: timestamp,
      createdAt: timestamp,
    );
    final b = _expense(
      description: 'B',
      date: timestamp,
      createdAt: timestamp,
    );

    final first = [a, b]..sort(Transaction.compareNewestFirst);
    final second = [b, a]..sort(Transaction.compareNewestFirst);

    expect(first.map((t) => t.id).toList(), second.map((t) => t.id).toList());
  });
}
