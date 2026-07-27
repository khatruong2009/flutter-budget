import 'package:budget_app/categorization_rule.dart';
import 'package:budget_app/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('matches merchant, type, and amount constraints deterministically', () {
    final rule = CategorizationRule(
      merchantPattern: 'Whole Foods',
      transactionType: TransactionTyp.expense,
      minimumAmount: 10,
      maximumAmount: 200,
      category: 'Groceries',
    );

    expect(
      rule.matches(
        type: TransactionTyp.expense,
        description: 'WHOLE FOODS MARKET',
        amount: 52,
      ),
      isTrue,
    );
    expect(
      rule.matches(
        type: TransactionTyp.income,
        description: 'Whole Foods refund',
        amount: 52,
      ),
      isFalse,
    );
    expect(
      rule.matches(
        type: TransactionTyp.expense,
        description: 'Whole Foods',
        amount: 250,
      ),
      isFalse,
    );
  });

  test('round trips tags and matching mode', () {
    final original = CategorizationRule(
      merchantPattern: 'ACME',
      matchType: MerchantMatchType.exact,
      category: 'General',
      tagIds: const ['work'],
      priority: 3,
    );

    final decoded = CategorizationRule.fromJson(original.toJson());
    expect(decoded.id, original.id);
    expect(decoded.matchType, MerchantMatchType.exact);
    expect(decoded.tagIds, ['work']);
    expect(decoded.priority, 3);
  });
}
