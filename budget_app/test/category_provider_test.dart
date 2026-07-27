import 'dart:convert';

import 'package:budget_app/category_definition.dart';
import 'package:budget_app/category_provider.dart';
import 'package:budget_app/common.dart';
import 'package:budget_app/storage/storage_keys.dart';
import 'package:budget_app/transaction.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('seeds stable built-in categories and persists them', () async {
    final provider = CategoryProvider();
    await provider.load();

    final expenses = provider.categoriesFor(BudgetCategoryType.expense);
    expect(expenses.first.id, 'expense-general');
    expect(expenses.first.name, 'General');
    expect(expenseCategories.keys.first, 'General');

    final preferences = await SharedPreferences.getInstance();
    final saved = jsonDecode(
      preferences.getString(StorageKeys.categories)!,
    ) as List<dynamic>;
    expect(saved, isNotEmpty);
    expect(saved.first['id'], 'expense-general');
  });

  test('custom categories retain identity through edits and reload', () async {
    final provider = CategoryProvider();
    await provider.load();
    final category = await provider.addCategory(
      type: BudgetCategoryType.expense,
      name: 'Coffee',
      iconIdentifier: 'asterisk_circle',
      colorToken: 'orange',
    );

    await provider.updateCategory(
      category.id,
      name: 'Coffee shops',
      iconIdentifier: 'cart',
      colorToken: 'green',
    );

    final reloaded = CategoryProvider();
    await reloaded.load();
    final restored =
        reloaded.categories.firstWhere((item) => item.id == category.id);
    expect(restored.name, 'Coffee shops');
    expect(restored.iconIdentifier, 'cart');
    expect(expenseCategories, contains('Coffee shops'));
  });

  test('legacy transaction categories are added without changing transaction',
      () async {
    final provider = CategoryProvider();
    await provider.load();
    final transaction = Transaction(
      type: TransactionTyp.income,
      description: 'Side work',
      amount: 50,
      category: 'Freelance',
      date: DateTime(2026, 1, 1),
    );

    await provider.ensureLegacyCategories([transaction]);

    final category = provider
        .categoriesFor(BudgetCategoryType.income)
        .firstWhere((item) => item.name == 'Freelance');
    expect(category.id, 'income-freelance');
    expect(transaction.category, 'Freelance');
    expect(incomeCategories, contains('Freelance'));
  });

  test('cannot archive the last active category of a type', () async {
    final provider = CategoryProvider();
    await provider.load();
    final income = provider.categoriesFor(BudgetCategoryType.income);
    for (final category in income.skip(1)) {
      await provider.setArchived(category.id, true);
    }

    await expectLater(
      provider.setArchived(income.first.id, true),
      throwsA(isA<StateError>()),
    );
  });
}
