import 'package:flutter/foundation.dart';

enum BudgetCategoryType { expense, income }

@immutable
class BudgetCategory {
  final String id;
  final BudgetCategoryType type;
  final String name;
  final String iconIdentifier;
  final String colorToken;
  final int sortOrder;
  final bool isArchived;
  final bool isBuiltIn;

  const BudgetCategory({
    required this.id,
    required this.type,
    required this.name,
    required this.iconIdentifier,
    required this.colorToken,
    required this.sortOrder,
    required this.isArchived,
    required this.isBuiltIn,
  });

  factory BudgetCategory.fromJson(Map<String, dynamic> json) {
    return BudgetCategory(
      id: json['id'] as String,
      type: json['type'] == 'income'
          ? BudgetCategoryType.income
          : BudgetCategoryType.expense,
      name: json['name'] as String,
      iconIdentifier: json['iconIdentifier'] as String? ?? 'square_grid_2x2',
      colorToken: json['colorToken'] as String? ?? 'accent',
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      isArchived: json['isArchived'] as bool? ?? false,
      isBuiltIn: json['isBuiltIn'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'name': name,
        'iconIdentifier': iconIdentifier,
        'colorToken': colorToken,
        'sortOrder': sortOrder,
        'isArchived': isArchived,
        'isBuiltIn': isBuiltIn,
      };

  BudgetCategory copyWith({
    String? name,
    String? iconIdentifier,
    String? colorToken,
    int? sortOrder,
    bool? isArchived,
  }) {
    return BudgetCategory(
      id: id,
      type: type,
      name: name ?? this.name,
      iconIdentifier: iconIdentifier ?? this.iconIdentifier,
      colorToken: colorToken ?? this.colorToken,
      sortOrder: sortOrder ?? this.sortOrder,
      isArchived: isArchived ?? this.isArchived,
      isBuiltIn: isBuiltIn,
    );
  }
}
