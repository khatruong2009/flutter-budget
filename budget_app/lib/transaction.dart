import 'package:uuid/uuid.dart';

enum TransactionTyp {
  income,
  expense,
}

class Transaction {
  static const Uuid _uuid = Uuid();

  final String id;
  final TransactionTyp type;
  final String description;
  final double amount;
  final String category;
  final DateTime date;
  final String? recurringTemplateId;
  final List<String> tagIds;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Transaction({
    String? id,
    required TransactionTyp type,
    required String description,
    required double amount,
    required String category,
    required DateTime date,
    String? recurringTemplateId,
    List<String> tagIds = const [],
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    final timestamp = DateTime.now();
    final resolvedCreatedAt = createdAt ?? timestamp;
    return Transaction._(
      id: _validId(id) ? id! : _uuid.v4(),
      type: type,
      description: description,
      amount: amount,
      category: category,
      date: date,
      recurringTemplateId: recurringTemplateId,
      tagIds: List<String>.unmodifiable(tagIds),
      createdAt: resolvedCreatedAt,
      updatedAt: updatedAt ?? resolvedCreatedAt,
    );
  }

  const Transaction._({
    required this.id,
    required this.type,
    required this.description,
    required this.amount,
    required this.category,
    required this.date,
    required this.recurringTemplateId,
    required this.tagIds,
    required this.createdAt,
    required this.updatedAt,
  });

  // Check if transaction is from recurring template
  bool get isRecurring => recurringTemplateId != null;

  static bool _validId(String? value) =>
      value != null && value.trim().isNotEmpty;

  static String generateId() => _uuid.v4();

  // convert transaction object into a map
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type == TransactionTyp.expense ? 'expense' : 'income',
        'description': description,
        'amount': amount,
        'category': category,
        'date': date.toIso8601String(),
        'recurringTemplateId': recurringTemplateId,
        'tagIds': tagIds,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  // convert map into a transaction object
  factory Transaction.fromJson(Map<String, dynamic> json) {
    final parsedDate = DateTime.parse(json['date']);
    final parsedCreatedAt = _parseDate(json['createdAt']) ?? parsedDate;
    return Transaction(
      id: json['id'] as String?,
      type: json['type'] == 'expense'
          ? TransactionTyp.expense
          : TransactionTyp.income,
      description: json['description'],
      amount: (json['amount'] as num).toDouble(),
      category: json['category'],
      date: parsedDate,
      recurringTemplateId: json['recurringTemplateId'] as String?,
      tagIds: (json['tagIds'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
      createdAt: parsedCreatedAt,
      updatedAt: _parseDate(json['updatedAt']) ?? parsedCreatedAt,
    );
  }

  Transaction copyWith({
    String? id,
    TransactionTyp? type,
    String? description,
    double? amount,
    String? category,
    DateTime? date,
    String? recurringTemplateId,
    List<String>? tagIds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Transaction(
      id: id ?? this.id,
      type: type ?? this.type,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      date: date ?? this.date,
      recurringTemplateId: recurringTemplateId ?? this.recurringTemplateId,
      tagIds: tagIds ?? this.tagIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    return value is String ? DateTime.tryParse(value) : null;
  }
}
