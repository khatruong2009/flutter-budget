import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'category_definition.dart';
import 'common.dart';
import 'storage/storage_keys.dart';
import 'storage/atomic_financial_store.dart';
import 'transaction.dart';

class CategoryProvider extends ChangeNotifier {
  final List<BudgetCategory> _categories = [];
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;
  List<BudgetCategory> get categories => List.unmodifiable(_categories);

  List<BudgetCategory> categoriesFor(
    BudgetCategoryType type, {
    bool includeArchived = false,
  }) {
    final result = _categories
        .where((category) =>
            category.type == type && (includeArchived || !category.isArchived))
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return result;
  }

  Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    final snapshot = await AtomicFinancialStore.instance.read();
    final stored = snapshot.sections[FinancialSections.categories];
    final encoded = stored is List
        ? jsonEncode(stored)
        : preferences.getString(StorageKeys.categories);
    _categories
      ..clear()
      ..addAll(_decodeOrSeed(encoded));
    _normalizeSortOrders();
    _syncCompatibilityMaps();
    _isLoaded = true;
    await _persist();
    notifyListeners();
  }

  List<BudgetCategory> _decodeOrSeed(String? encoded) {
    if (encoded == null || encoded.isEmpty) {
      return _builtInCategories();
    }
    try {
      final decoded = jsonDecode(encoded) as List<dynamic>;
      final categories = decoded
          .map((item) => BudgetCategory.fromJson(item as Map<String, dynamic>))
          .toList();
      if (categories.isEmpty) return _builtInCategories();
      return categories;
    } catch (_) {
      // A corrupt category preference must not make transaction forms
      // unusable. Preserve the raw value for diagnostics and restore defaults.
      return _builtInCategories();
    }
  }

  /// Adds definitions for category names found in legacy transactions or
  /// recurring templates. Transactions continue storing their display string,
  /// which keeps old backups and category budget keys compatible.
  Future<void> ensureLegacyCategories(
      Iterable<Transaction> transactions) async {
    await ensureLegacyCategoryNames(
      transactions.map(
        (transaction) => (
          transaction.type == TransactionTyp.income
              ? BudgetCategoryType.income
              : BudgetCategoryType.expense,
          transaction.category,
        ),
      ),
    );
  }

  Future<void> ensureLegacyCategoryNames(
    Iterable<(BudgetCategoryType, String)> names,
  ) async {
    var changed = false;
    for (final (type, name) in names) {
      if (_containsName(type, name)) continue;
      _categories.add(
        BudgetCategory(
          id: _uniqueId(type, name),
          type: type,
          name: name,
          iconIdentifier: 'square_grid_2x2',
          colorToken: 'accent',
          sortOrder: categoriesFor(type, includeArchived: true).length,
          isArchived: false,
          isBuiltIn: false,
        ),
      );
      changed = true;
    }
    if (changed) {
      _normalizeSortOrders();
      await _saveAndNotify();
    }
  }

  Future<BudgetCategory> addCategory({
    required BudgetCategoryType type,
    required String name,
    required String iconIdentifier,
    required String colorToken,
  }) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Category name is required');
    }
    if (_containsName(type, normalizedName)) {
      throw ArgumentError.value(
          name, 'name', 'A category with this name already exists');
    }
    final category = BudgetCategory(
      id: _uniqueId(type, normalizedName),
      type: type,
      name: normalizedName,
      iconIdentifier: categoryIconRegistry.containsKey(iconIdentifier)
          ? iconIdentifier
          : 'square_grid_2x2',
      colorToken: colorToken,
      sortOrder: categoriesFor(type, includeArchived: true).length,
      isArchived: false,
      isBuiltIn: false,
    );
    _categories.add(category);
    await _saveAndNotify();
    return category;
  }

  Future<void> restoreFromBackup(List<BudgetCategory> categories) async {
    final restored =
        categories.isEmpty ? _builtInCategories() : List.of(categories);
    final ids = restored.map((category) => category.id).toSet();
    if (ids.length != restored.length) {
      throw const FormatException('Backup contains duplicate category IDs');
    }
    for (final type in BudgetCategoryType.values) {
      if (!restored
          .any((category) => category.type == type && !category.isArchived)) {
        throw const FormatException(
            'Backup must contain an active income and expense category');
      }
    }
    _categories
      ..clear()
      ..addAll(restored);
    _normalizeSortOrders();
    _isLoaded = true;
    await _saveAndNotify();
  }

  Future<void> updateCategory(
    String id, {
    required String name,
    required String iconIdentifier,
    required String colorToken,
  }) async {
    final index = _categories.indexWhere((category) => category.id == id);
    if (index < 0) return;
    final existing = _categories[index];
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Category name is required');
    }
    final duplicate = _categories.any((category) =>
        category.id != id &&
        category.type == existing.type &&
        category.name.toLowerCase() == normalizedName.toLowerCase());
    if (duplicate) {
      throw ArgumentError.value(
          name, 'name', 'A category with this name already exists');
    }
    _categories[index] = existing.copyWith(
      name: normalizedName,
      iconIdentifier: categoryIconRegistry.containsKey(iconIdentifier)
          ? iconIdentifier
          : 'square_grid_2x2',
      colorToken: colorToken,
    );
    await _saveAndNotify();
  }

  Future<void> setArchived(String id, bool archived) async {
    final index = _categories.indexWhere((category) => category.id == id);
    if (index < 0 || _categories[index].isArchived == archived) return;
    final category = _categories[index];
    final activeOfType =
        categoriesFor(category.type).where((item) => item.id != id).length;
    if (archived && activeOfType == 0) {
      throw StateError('At least one category must remain active');
    }
    _categories[index] = category.copyWith(isArchived: archived);
    await _saveAndNotify();
  }

  Future<void> moveCategory(String id, int offset) async {
    final category = _categories.firstWhere((item) => item.id == id);
    final ordered = categoriesFor(category.type, includeArchived: true);
    final from = ordered.indexWhere((item) => item.id == id);
    final to = (from + offset).clamp(0, ordered.length - 1);
    if (from == to) return;
    final moved = ordered.removeAt(from);
    ordered.insert(to, moved);
    for (var i = 0; i < ordered.length; i++) {
      final index = _categories.indexWhere((item) => item.id == ordered[i].id);
      _categories[index] = ordered[i].copyWith(sortOrder: i);
    }
    await _saveAndNotify();
  }

  bool _containsName(BudgetCategoryType type, String name) =>
      _categories.any((category) =>
          category.type == type &&
          category.name.toLowerCase() == name.trim().toLowerCase());

  String _uniqueId(BudgetCategoryType type, String name) {
    final slug = name
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final candidate = '${type.name}-${slug.isEmpty ? 'category' : slug}';
    if (_categories.every((category) => category.id != candidate)) {
      return candidate;
    }
    return '${type.name}-${const Uuid().v4()}';
  }

  void _normalizeSortOrders() {
    for (final type in BudgetCategoryType.values) {
      final ordered = categoriesFor(type, includeArchived: true);
      for (var i = 0; i < ordered.length; i++) {
        final index =
            _categories.indexWhere((item) => item.id == ordered[i].id);
        _categories[index] = ordered[i].copyWith(sortOrder: i);
      }
    }
  }

  Future<void> _saveAndNotify() async {
    _syncCompatibilityMaps();
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final serialized =
        _categories.map((category) => category.toJson()).toList();
    await AtomicFinancialStore.instance.updateSection(
      FinancialSections.categories,
      serialized,
    );
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      StorageKeys.categories,
      jsonEncode(serialized),
    );
  }

  void _syncCompatibilityMaps() {
    expenseCategories
      ..clear()
      ..addEntries(
        categoriesFor(BudgetCategoryType.expense).map((category) => MapEntry(
              category.name,
              categoryIconRegistry[category.iconIdentifier] ??
                  categoryIconRegistry['square_grid_2x2']!,
            )),
      );
    incomeCategories
      ..clear()
      ..addEntries(
        categoriesFor(BudgetCategoryType.income).map((category) => MapEntry(
              category.name,
              categoryIconRegistry[category.iconIdentifier] ??
                  categoryIconRegistry['square_grid_2x2']!,
            )),
      );
  }
}

List<BudgetCategory> _builtInCategories() {
  const expenses = <(String, String, String)>[
    ('General', 'square_grid_2x2', 'accent'),
    ('Eating Out', 'asterisk_circle', 'orange'),
    ('Groceries', 'cart', 'green'),
    ('Housing', 'house', 'blue'),
    ('Transportation', 'car', 'purple'),
    ('Travel', 'airplane', 'cyan'),
    ('Clothing', 'bag', 'pink'),
    ('Gift', 'gift', 'purple'),
    ('Health', 'heart', 'red'),
    ('Entertainment', 'film', 'orange'),
    ('Pets', 'paw', 'green'),
    ('Family', 'people', 'blue'),
    ('Loan Payment', 'money', 'red'),
  ];
  const incomes = <(String, String, String)>[
    ('Salary', 'money', 'green'),
    ('Investment', 'chart', 'blue'),
    ('Gift', 'gift', 'purple'),
    ('Other', 'square_grid_2x2', 'accent'),
  ];
  return [
    for (var i = 0; i < expenses.length; i++)
      BudgetCategory(
        id: 'expense-${expenses[i].$1.toLowerCase().replaceAll(' ', '-')}',
        type: BudgetCategoryType.expense,
        name: expenses[i].$1,
        iconIdentifier: expenses[i].$2,
        colorToken: expenses[i].$3,
        sortOrder: i,
        isArchived: false,
        isBuiltIn: true,
      ),
    for (var i = 0; i < incomes.length; i++)
      BudgetCategory(
        id: 'income-${incomes[i].$1.toLowerCase().replaceAll(' ', '-')}',
        type: BudgetCategoryType.income,
        name: incomes[i].$1,
        iconIdentifier: incomes[i].$2,
        colorToken: incomes[i].$3,
        sortOrder: i,
        isArchived: false,
        isBuiltIn: true,
      ),
  ];
}
