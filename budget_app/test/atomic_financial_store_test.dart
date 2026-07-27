import 'dart:convert';

import 'package:budget_app/storage/atomic_financial_store.dart';
import 'package:budget_app/storage/storage_keys.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('migrates legacy financial sections into one snapshot', () async {
    SharedPreferences.setMockInitialValues({
      StorageKeys.transactions: jsonEncode([
        {'description': 'Coffee'}
      ]),
      StorageKeys.categoryBudgetLimits: jsonEncode({'Eating Out': 100}),
    });

    final snapshot = await AtomicFinancialStore.instance.read();

    expect(
      (snapshot.sections[FinancialSections.transactions] as List).single,
      {'description': 'Coffee'},
    );
    expect(
      snapshot.sections[FinancialSections.categoryBudgetLimits],
      {'Eating Out': 100},
    );
  });

  test('updates multiple sections in one revision', () async {
    final initial = await AtomicFinancialStore.instance.read();

    await AtomicFinancialStore.instance.updateSections({
      FinancialSections.transactions: [
        {'description': 'Rent'}
      ],
      FinancialSections.savingsGoals: [
        {'name': 'Emergency fund'}
      ],
    });

    final updated = await AtomicFinancialStore.instance.read();
    expect(updated.revision, initial.revision + 1);
    expect(
      (updated.sections[FinancialSections.transactions] as List).single,
      {'description': 'Rent'},
    );
    expect(
      (updated.sections[FinancialSections.savingsGoals] as List).single,
      {'name': 'Emergency fund'},
    );
  });

  test('recovers the last-known-good backup when primary is malformed',
      () async {
    SharedPreferences.setMockInitialValues({
      StorageKeys.transactions: jsonEncode([
        {'description': 'Last known good'}
      ]),
    });
    await AtomicFinancialStore.instance.read();
    await AtomicFinancialStore.instance.updateSection(
      FinancialSections.transactions,
      [
        {'description': 'Newest'}
      ],
    );

    final prefs = await SharedPreferences.getInstance();
    final primaryKey = prefs.getKeys().singleWhere(
          (key) =>
              key.startsWith('financial_store_v1') && !key.endsWith('_backup'),
        );
    await prefs.setString(primaryKey, '{"corrupt":true}');

    final recovered = await AtomicFinancialStore.instance.read();

    expect(
      (recovered.sections[FinancialSections.transactions] as List).single,
      {'description': 'Last known good'},
    );
    expect(prefs.getString(primaryKey), isNot('{"corrupt":true}'));
  });
}
