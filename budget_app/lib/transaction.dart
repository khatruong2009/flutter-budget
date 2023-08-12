enum TransactionTyp {
  INCOME,
  EXPENSE,
}

class Transaction {
  final TransactionTyp type;
  final String description;
  final double amount;
  final String category;
  final DateTime date;

  Transaction({
    required this.type,
    required this.description,
    required this.amount,
    required this.category,
    required this.date,
  });

  // convert transaction object into a map
  Map<String, dynamic> toJson() => {
        'type': type == TransactionTyp.EXPENSE ? 'expense' : 'income',
        'description': description,
        'amount': amount,
        'category': category,
        'date': date.toIso8601String(),
      };

  // convert map into a transaction object
  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      type: json['type'] == 'expense'
          ? TransactionTyp.EXPENSE
          : TransactionTyp.INCOME,
      description: json['description'],
      amount: json['amount'],
      category: json['category'],
      date: DateTime.parse(json['date']),
    );
  }
}
