class SavingsGoal {
  static int _idCounter = 0;
  static const Object _unset = Object();

  final String id;
  final String name;
  final double targetAmount;
  final double currentAmount;
  final DateTime targetDate;
  final DateTime createdAt;
  final DateTime? completedAt;

  SavingsGoal({
    String? id,
    required String name,
    required double targetAmount,
    double currentAmount = 0.0,
    required this.targetDate,
    DateTime? createdAt,
    this.completedAt,
  })  : id = id ?? _generateId(),
        name = name.trim(),
        targetAmount = targetAmount < 0 ? 0.0 : targetAmount,
        currentAmount = currentAmount < 0 ? 0.0 : currentAmount,
        createdAt = createdAt ?? DateTime.now();

  double get progress {
    if (targetAmount <= 0) {
      return 0.0;
    }

    final value = currentAmount / targetAmount;
    if (value < 0) {
      return 0.0;
    }
    if (value > 1) {
      return 1.0;
    }
    return value;
  }

  int get progressPercent => (progress * 100).round();

  double get remainingAmount {
    final remaining = targetAmount - currentAmount;
    return remaining <= 0 ? 0.0 : remaining;
  }

  bool get isCompleted => targetAmount > 0 && currentAmount >= targetAmount;

  bool get isOverdue {
    final today = DateTime.now();
    final normalizedToday = DateTime(today.year, today.month, today.day);
    final normalizedTarget =
        DateTime(targetDate.year, targetDate.month, targetDate.day);
    return !isCompleted && normalizedTarget.isBefore(normalizedToday);
  }

  int get daysRemaining {
    final today = DateTime.now();
    final normalizedToday = DateTime(today.year, today.month, today.day);
    final normalizedTarget =
        DateTime(targetDate.year, targetDate.month, targetDate.day);
    return normalizedTarget.difference(normalizedToday).inDays;
  }

  double get suggestedMonthlyContribution {
    if (isCompleted || remainingAmount <= 0) {
      return 0.0;
    }

    final now = DateTime.now();
    final monthsRemaining =
        ((targetDate.year - now.year) * 12) + targetDate.month - now.month + 1;
    if (monthsRemaining <= 1) {
      return remainingAmount;
    }
    return remainingAmount / monthsRemaining;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'targetAmount': targetAmount,
        'currentAmount': currentAmount,
        'targetDate': targetDate.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
      };

  factory SavingsGoal.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    final parsedTargetDate = _readDate(json['targetDate']) ?? now;
    final parsedCreatedAt = _readDate(json['createdAt']) ?? now;

    return SavingsGoal(
      id: json['id'] as String?,
      name: (json['name'] as String?)?.trim().isNotEmpty == true
          ? (json['name'] as String).trim()
          : 'Savings Goal',
      targetAmount: _readDouble(json['targetAmount']),
      currentAmount: _readDouble(json['currentAmount']),
      targetDate: parsedTargetDate,
      createdAt: parsedCreatedAt,
      completedAt: _readDate(json['completedAt']),
    );
  }

  SavingsGoal copyWith({
    String? id,
    String? name,
    double? targetAmount,
    double? currentAmount,
    DateTime? targetDate,
    DateTime? createdAt,
    Object? completedAt = _unset,
  }) {
    return SavingsGoal(
      id: id ?? this.id,
      name: name ?? this.name,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      targetDate: targetDate ?? this.targetDate,
      createdAt: createdAt ?? this.createdAt,
      completedAt:
          completedAt == _unset ? this.completedAt : completedAt as DateTime?,
    );
  }

  SavingsGoal withAllocation(double amount) {
    final nextAmount = currentAmount + amount;
    final nextCompletedAt =
        !isCompleted && targetAmount > 0 && nextAmount >= targetAmount
            ? DateTime.now()
            : completedAt;

    return copyWith(
      currentAmount: nextAmount,
      completedAt: nextAmount < targetAmount ? null : nextCompletedAt,
    );
  }

  static String _generateId() {
    final timestamp = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final counter = (_idCounter++).toRadixString(36);
    return 'savings_goal_${timestamp}_$counter';
  }

  static double _readDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  static DateTime? _readDate(dynamic value) {
    if (value is DateTime) {
      return value;
    }
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is SavingsGoal &&
        other.id == id &&
        other.name == name &&
        other.targetAmount == targetAmount &&
        other.currentAmount == currentAmount &&
        other.targetDate == targetDate &&
        other.createdAt == createdAt &&
        other.completedAt == completedAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      name,
      targetAmount,
      currentAmount,
      targetDate,
      createdAt,
      completedAt,
    );
  }
}
