import 'package:uuid/uuid.dart';
import 'transaction.dart';

enum RecurrencePattern {
  weekly,
  biweekly,
  monthly,
}

class RecurringTransaction {
  final String id;
  final TransactionTyp type;
  final String description;
  final double amount;
  final String category;
  final RecurrencePattern pattern;
  final DateTime startDate;
  final DateTime nextOccurrence;
  final int? dayOfMonth; // For monthly: 1-31
  final int? dayOfWeek; // For weekly/biweekly: 1-7 (Monday-Sunday)
  final bool isActive;

  RecurringTransaction({
    String? id,
    required this.type,
    required this.description,
    required this.amount,
    required this.category,
    required this.pattern,
    required this.startDate,
    DateTime? nextOccurrence,
    this.dayOfMonth,
    this.dayOfWeek,
    this.isActive = true,
  })  : id = id ?? const Uuid().v4(),
        nextOccurrence = nextOccurrence ?? startDate;

  /// Serialization: Convert RecurringTransaction to JSON
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type == TransactionTyp.expense ? 'expense' : 'income',
        'description': description,
        'amount': amount,
        'category': category,
        'pattern': pattern.name,
        'startDate': startDate.toIso8601String(),
        'nextOccurrence': nextOccurrence.toIso8601String(),
        'dayOfMonth': dayOfMonth,
        'dayOfWeek': dayOfWeek,
        'isActive': isActive,
      };

  /// Deserialization: Convert JSON to RecurringTransaction
  factory RecurringTransaction.fromJson(Map<String, dynamic> json) {
    return RecurringTransaction(
      id: json['id'],
      type: json['type'] == 'expense'
          ? TransactionTyp.expense
          : TransactionTyp.income,
      description: json['description'],
      amount: json['amount'],
      category: json['category'],
      pattern: RecurrencePattern.values.firstWhere(
        (p) => p.name == json['pattern'],
      ),
      startDate: DateTime.parse(json['startDate']),
      nextOccurrence: DateTime.parse(json['nextOccurrence']),
      dayOfMonth: json['dayOfMonth'],
      dayOfWeek: json['dayOfWeek'],
      isActive: json['isActive'] ?? true,
    );
  }

  /// Calculate the next occurrence date based on the recurrence pattern
  DateTime calculateNextOccurrence() {
    switch (pattern) {
      case RecurrencePattern.weekly:
        return nextOccurrence.add(const Duration(days: 7));
      case RecurrencePattern.biweekly:
        return nextOccurrence.add(const Duration(days: 14));
      case RecurrencePattern.monthly:
        return _calculateNextMonthlyOccurrence(nextOccurrence, dayOfMonth!);
    }
  }

  /// Handle monthly recurrence with day-of-month logic
  DateTime _calculateNextMonthlyOccurrence(DateTime from, int dayOfMonth) {
    int nextMonth = from.month + 1;
    int nextYear = from.year;

    if (nextMonth > 12) {
      nextMonth = 1;
      nextYear++;
    }

    // Handle months with fewer days
    int daysInMonth = DateTime(nextYear, nextMonth + 1, 0).day;
    int actualDay = dayOfMonth > daysInMonth ? daysInMonth : dayOfMonth;

    return DateTime(nextYear, nextMonth, actualDay);
  }

  /// Generate a Transaction from this recurring template
  Transaction generateTransaction(DateTime date) {
    return Transaction(
      type: type,
      description: description,
      amount: amount,
      category: category,
      date: date,
    );
  }

  /// Create a copy with updated fields
  RecurringTransaction copyWith({
    String? id,
    TransactionTyp? type,
    String? description,
    double? amount,
    String? category,
    RecurrencePattern? pattern,
    DateTime? startDate,
    DateTime? nextOccurrence,
    int? dayOfMonth,
    int? dayOfWeek,
    bool? isActive,
  }) {
    return RecurringTransaction(
      id: id ?? this.id,
      type: type ?? this.type,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      pattern: pattern ?? this.pattern,
      startDate: startDate ?? this.startDate,
      nextOccurrence: nextOccurrence ?? this.nextOccurrence,
      dayOfMonth: dayOfMonth ?? this.dayOfMonth,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is RecurringTransaction &&
        other.id == id &&
        other.type == type &&
        other.description == description &&
        other.amount == amount &&
        other.category == category &&
        other.pattern == pattern &&
        other.startDate == startDate &&
        other.nextOccurrence == nextOccurrence &&
        other.dayOfMonth == dayOfMonth &&
        other.dayOfWeek == dayOfWeek &&
        other.isActive == isActive;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      type,
      description,
      amount,
      category,
      pattern,
      startDate,
      nextOccurrence,
      dayOfMonth,
      dayOfWeek,
      isActive,
    );
  }
}
