import 'package:uuid/uuid.dart';

import 'transaction.dart';

enum MerchantMatchType { contains, startsWith, exact }

class CategorizationRule {
  final String id;
  final String merchantPattern;
  final MerchantMatchType matchType;
  final TransactionTyp? transactionType;
  final double? minimumAmount;
  final double? maximumAmount;
  final String category;
  final List<String> tagIds;
  final int priority;
  final bool isEnabled;

  CategorizationRule({
    String? id,
    required String merchantPattern,
    this.matchType = MerchantMatchType.contains,
    this.transactionType,
    this.minimumAmount,
    this.maximumAmount,
    required this.category,
    this.tagIds = const [],
    this.priority = 0,
    this.isEnabled = true,
  })  : id = id ?? const Uuid().v4(),
        merchantPattern = merchantPattern.trim();

  factory CategorizationRule.fromJson(Map<String, dynamic> json) {
    final typeName = json['transactionType'] as String?;
    return CategorizationRule(
      id: json['id'] as String?,
      merchantPattern: json['merchantPattern'] as String? ?? '',
      matchType: MerchantMatchType.values.firstWhere(
        (value) => value.name == json['matchType'],
        orElse: () => MerchantMatchType.contains,
      ),
      transactionType: typeName == null
          ? null
          : TransactionTyp.values.firstWhere(
              (value) => value.name == typeName,
              orElse: () => TransactionTyp.expense,
            ),
      minimumAmount: (json['minimumAmount'] as num?)?.toDouble(),
      maximumAmount: (json['maximumAmount'] as num?)?.toDouble(),
      category: json['category'] as String? ?? 'General',
      tagIds: (json['tagIds'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
      priority: (json['priority'] as num?)?.toInt() ?? 0,
      isEnabled: json['isEnabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'merchantPattern': merchantPattern,
        'matchType': matchType.name,
        'transactionType': transactionType?.name,
        'minimumAmount': minimumAmount,
        'maximumAmount': maximumAmount,
        'category': category,
        'tagIds': tagIds,
        'priority': priority,
        'isEnabled': isEnabled,
      };

  bool matches({
    required TransactionTyp type,
    required String description,
    required double amount,
  }) {
    if (!isEnabled || merchantPattern.isEmpty) return false;
    if (transactionType != null && transactionType != type) return false;
    if (minimumAmount != null && amount < minimumAmount!) return false;
    if (maximumAmount != null && amount > maximumAmount!) return false;

    final candidate = description.trim().toLowerCase();
    final pattern = merchantPattern.toLowerCase();
    return switch (matchType) {
      MerchantMatchType.contains => candidate.contains(pattern),
      MerchantMatchType.startsWith => candidate.startsWith(pattern),
      MerchantMatchType.exact => candidate == pattern,
    };
  }
}
