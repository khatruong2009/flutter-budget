import 'package:uuid/uuid.dart';

class TransactionTag {
  final String id;
  final String name;
  final String colorToken;

  TransactionTag({
    String? id,
    required String name,
    this.colorToken = 'accent',
  })  : id = id ?? const Uuid().v4(),
        name = name.trim();

  factory TransactionTag.fromJson(Map<String, dynamic> json) {
    return TransactionTag(
      id: json['id'] as String?,
      name: json['name'] as String? ?? '',
      colorToken: json['colorToken'] as String? ?? 'accent',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'colorToken': colorToken,
      };
}
