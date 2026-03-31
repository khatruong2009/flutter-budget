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

  test('monthly balances can be carried forward and updated manually',
      () async {
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

  test('available months include tracked snapshot months and selected month',
      () async {
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

  test('same-month net worth updates create separate history points', () async {
    final model = TransactionModel();
    final march = DateTime(2026, 3);

    await model.selectNetWorthMonth(march);
    await model.addNetWorthEntry(
      name: 'Checking',
      type: NetWorthEntryType.asset,
      amount: 1000,
      month: march,
      recordedAt: DateTime(2026, 3, 10, 9),
    );

    final checking = model.netWorthEntries.single;

    await model.updateNetWorthEntry(
      id: checking.id,
      name: checking.name,
      type: checking.type,
      amount: 1400,
      month: march,
      recordedAt: DateTime(2026, 3, 25, 17),
    );

    final history = model.getNetWorthHistory(limit: 10);

    expect(history.map((point) => point.date).toList(), [
      DateTime(2026, 3, 25),
      DateTime(2026, 3, 10),
    ]);
    expect(history.map((point) => point.netWorth).toList(), [1400.0, 1000.0]);
    expect(history.map((point) => point.assetCount).toList(), [1, 1]);
    expect(history.map((point) => point.liabilityCount).toList(), [0, 0]);
    expect(
      history.every(
        (point) => point.granularity == NetWorthHistoryGranularity.day,
      ),
      isTrue,
    );
    expect(model.getNetWorthForMonth(march), 1400.0);
  });

  test(
      'older daily points compress into monthly snapshots when history is crowded',
      () async {
    final model = TransactionModel();

    await model.selectNetWorthMonth(DateTime(2026, 3));
    await model.addNetWorthEntry(
      name: 'Checking',
      type: NetWorthEntryType.asset,
      amount: 1000,
      month: DateTime(2026, 1),
      recordedAt: DateTime(2026, 1, 2, 9),
    );

    final checking = model.netWorthEntries.single;

    await model.updateNetWorthEntry(
      id: checking.id,
      name: checking.name,
      type: checking.type,
      amount: 1100,
      month: DateTime(2026, 1),
      recordedAt: DateTime(2026, 1, 10, 9),
    );
    await model.updateNetWorthEntry(
      id: checking.id,
      name: checking.name,
      type: checking.type,
      amount: 1200,
      month: DateTime(2026, 1),
      recordedAt: DateTime(2026, 1, 20, 9),
    );
    await model.updateNetWorthEntry(
      id: checking.id,
      name: checking.name,
      type: checking.type,
      amount: 1300,
      month: DateTime(2026, 2),
      recordedAt: DateTime(2026, 2, 5, 9),
    );
    await model.updateNetWorthEntry(
      id: checking.id,
      name: checking.name,
      type: checking.type,
      amount: 1400,
      month: DateTime(2026, 2),
      recordedAt: DateTime(2026, 2, 18, 9),
    );
    await model.updateNetWorthEntry(
      id: checking.id,
      name: checking.name,
      type: checking.type,
      amount: 1500,
      month: DateTime(2026, 3),
      recordedAt: DateTime(2026, 3, 8, 9),
    );

    final history = model.getNetWorthHistory(limit: 4);

    expect(history.length, 4);
    expect(history[0].date, DateTime(2026, 3, 8));
    expect(history[0].granularity, NetWorthHistoryGranularity.day);
    expect(history[1].date, DateTime(2026, 2, 18));
    expect(history[1].granularity, NetWorthHistoryGranularity.day);
    expect(history[2].date, DateTime(2026, 2, 5));
    expect(history[2].granularity, NetWorthHistoryGranularity.day);
    expect(history[3].date, DateTime(2026, 1, 31, 23, 59, 59, 999));
    expect(history[3].granularity, NetWorthHistoryGranularity.month);
    expect(history[3].netWorth, 1200.0);
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
