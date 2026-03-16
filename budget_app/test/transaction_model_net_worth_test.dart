import 'package:budget_app/net_worth_entry.dart';
import 'package:budget_app/transaction.dart';
import 'package:budget_app/transaction_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('net worth is driven by manual asset and liability balances', () async {
    final model = TransactionModel();
    final month = DateTime(2026, 3);

    model.selectMonth(month);
    await model.selectNetWorthMonth(month);
    await model.addNetWorthEntry(
      name: 'Checking',
      type: NetWorthEntryType.asset,
      amount: 1000,
      month: month,
    );
    await model.addNetWorthEntry(
      name: 'Credit Card',
      type: NetWorthEntryType.liability,
      amount: 400,
      month: month,
    );

    model.addTransaction(
      TransactionTyp.income,
      'Salary',
      250,
      'Income',
      DateTime(2026, 3, 15),
    );
    model.addTransaction(
      TransactionTyp.expense,
      'Groceries',
      100,
      'Food',
      DateTime(2026, 3, 16),
    );

    expect(model.totalIncome, 250);
    expect(model.totalExpenses, 100);
    expect(model.totalAssets, 1000);
    expect(model.totalLiabilities, 400);
    expect(model.netWorth, 600);
  });

  test('monthly balances can be carried forward and updated manually', () async {
    final model = TransactionModel();
    final january = DateTime(2026, 1);
    final february = DateTime(2026, 2);

    await model.selectNetWorthMonth(january);
    await model.addNetWorthEntry(
      name: 'Brokerage',
      type: NetWorthEntryType.asset,
      amount: 200000,
      month: january,
    );
    await model.addNetWorthEntry(
      name: 'Mortgage',
      type: NetWorthEntryType.liability,
      amount: 150000,
      month: january,
    );

    final mortgage = model.netWorthEntries.firstWhere(
      (entry) => entry.name == 'Mortgage',
    );

    final didCarryForward = await model.carryNetWorthMonthForward(february);
    await model.updateNetWorthEntry(
      id: mortgage.id,
      name: mortgage.name,
      type: mortgage.type,
      amount: 149500,
      month: february,
    );

    expect(didCarryForward, isTrue);
    expect(model.getTotalAssetsForMonth(february), 200000);
    expect(model.getTotalLiabilitiesForMonth(february), 149500);
    expect(model.getNetWorthForMonth(february), 50500);
    expect(model.getTrackedNetWorthEntryCountForMonth(february), 2);
    expect(model.getUpdatedNetWorthEntryCountForMonth(february), 2);
    expect(model.getStaleNetWorthEntryCountForMonth(february), 0);
  });

  test('available months include tracked snapshot months and selected month', () async {
    final model = TransactionModel();
    final january = DateTime(2026, 1);
    final march = DateTime(2026, 3);

    await model.selectNetWorthMonth(march);
    await model.addNetWorthEntry(
      name: 'Savings',
      type: NetWorthEntryType.asset,
      amount: 5000,
      month: january,
    );

    final months = model.getNetWorthAvailableMonths();

    expect(months, contains(march));
    expect(months, contains(january));
    expect(months.first, march);
  });

  test('legacy baseline values migrate into tracked accounts', () async {
    SharedPreferences.setMockInitialValues({
      'starting_assets': 3200.0,
      'starting_liabilities': 900.0,
    });

    final model = TransactionModel();
    await model.getTransactions();

    expect(model.netWorthEntries.length, 2);
    expect(model.totalAssets, 3200.0);
    expect(model.totalLiabilities, 900.0);
    expect(model.netWorth, 2300.0);
  });
}
