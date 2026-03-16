import 'package:animated_digit/animated_digit.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'design_system.dart';
import 'transaction.dart';
import 'transaction_form.dart';
import 'transaction_model.dart';
import 'transaction_page.dart';

class SpendingPage extends StatefulWidget {
  final List<Transaction> transactions = [];

  SpendingPage({
    Key? key,
  }) : super(key: key);

  @override
  SpendingPageState createState() => SpendingPageState();
}

class SpendingPageState extends State<SpendingPage> {
  final List<String> months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  // current month
  int currentMonthIndex = DateTime.now().month - 1;
  late FixedExtentScrollController scrollController;
  bool isExpanded = false;

  @override
  void initState() {
    super.initState();
    scrollController =
        FixedExtentScrollController(initialItem: currentMonthIndex);
  }

  // calculate total income
  double calculateTotalIncome(List<Transaction> transactions) {
    return transactions
        .where((transaction) => transaction.type == TransactionTyp.income)
        .map((transaction) => transaction.amount)
        .fold(0, (previousValue, amount) => previousValue + amount);
  }

  // calculate total expenses
  double calculateTotalExpenses(List<Transaction> transactions) {
    return transactions
        .where((transaction) => transaction.type == TransactionTyp.expense)
        .map((transaction) => transaction.amount)
        .fold(0, (previousValue, amount) => previousValue + amount);
  }

  Future<void> _openTransactionsPage(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const TransactionPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TransactionModel>(
      builder: (context, transactionModel, child) {
        final totalIncome =
            calculateTotalIncome(transactionModel.currentMonthTransactions);
        final totalExpenses =
            calculateTotalExpenses(transactionModel.currentMonthTransactions);
        final netDifference = totalIncome - totalExpenses;
        final recentTransactions =
            transactionModel.getAllTransactionsSorted().take(3).toList();

        return Scaffold(
          appBar: AppBar(
            title: Text(
              'Spending',
              style: AppTypography.headingLarge.copyWith(
                color: AppDesign.getTextPrimary(context),
              ),
            ),
            centerTitle: true,
            backgroundColor: AppDesign.getBackgroundColor(context),
            elevation: 0,
          ),
          backgroundColor: AppDesign.getBackgroundColor(context),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppDesign.spacingM),
              child: LayoutBuilder(
                builder: (context, _) {
                  final isDark = Theme.of(context).brightness == Brightness.dark;

                  return Column(
                    children: <Widget>[
                      Row(
                        children: [
                          Expanded(
                            child: AnimatedMetricCard(
                              label: 'Income',
                              value: totalIncome,
                              icon: CupertinoIcons.arrow_down_circle_fill,
                              color: AppColors.getIncome(isDark),
                              prefix: '\$',
                            ),
                          ),
                          const SizedBox(width: AppDesign.spacingM),
                          Expanded(
                            child: AnimatedMetricCard(
                              label: 'Expenses',
                              value: totalExpenses,
                              icon: CupertinoIcons.arrow_up_circle_fill,
                              color: AppColors.getExpense(isDark),
                              prefix: '\$',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppDesign.spacingM),
                      ElevatedCard(
                        elevation: AppDesign.elevationM,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDesign.spacingM,
                          vertical: AppDesign.spacingS,
                        ),
                        child: Column(
                          children: [
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  isExpanded = !isExpanded;
                                });
                              },
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    months[currentMonthIndex],
                                    style: AppTypography.bodyMedium.copyWith(
                                      color: AppDesign.getTextPrimary(context),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  AnimatedRotation(
                                    turns: isExpanded ? 0.5 : 0,
                                    duration: AppAnimations.normal,
                                    curve: AppAnimations.easeInOut,
                                    child: Icon(
                                      CupertinoIcons.chevron_down,
                                      size: AppDesign.iconS,
                                      color: AppDesign.getTextSecondary(context),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            AnimatedContainer(
                              height: isExpanded ? 120 : 0,
                              duration: AppAnimations.normal,
                              curve: AppAnimations.easeInOut,
                              child: isExpanded
                                  ? ClipRect(
                                      child: Column(
                                        children: [
                                          const SizedBox(height: AppDesign.spacingS),
                                          Expanded(
                                            child: CupertinoPicker(
                                              scrollController: scrollController,
                                              itemExtent: 32,
                                              onSelectedItemChanged: (int index) {
                                                setState(() {
                                                  currentMonthIndex = index;
                                                });
                                                transactionModel.selectMonth(
                                                  DateTime(DateTime.now().year, index + 1),
                                                );
                                              },
                                              children: months.map((String month) {
                                                return Center(
                                                  child: Text(
                                                    month,
                                                    style: AppTypography.bodyMedium.copyWith(
                                                      color: AppDesign.getTextPrimary(context),
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                );
                                              }).toList(),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppDesign.spacingM),
                      Expanded(
                        child: Column(
                          children: [
                            Expanded(
                              flex: 3,
                              child: ElevatedCard(
                                elevation: AppDesign.elevationM,
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          CupertinoIcons.chart_bar_alt_fill,
                                          size: AppDesign.iconM,
                                          color: AppDesign.getTextSecondary(context),
                                        ),
                                        const SizedBox(width: AppDesign.spacingS),
                                        Text(
                                          'Cash Flow',
                                          style: AppTypography.headingMedium.copyWith(
                                            color: AppDesign.getTextSecondary(context),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Spacer(),
                                    Builder(
                                      builder: (context) {
                                        final isPositive = netDifference >= 0;
                                        final displayColor = isPositive
                                            ? AppDesign.getIncomeColor(context)
                                            : AppDesign.getExpenseColor(context);

                                        return Column(
                                          children: [
                                            AnimatedContainer(
                                              duration: AppAnimations.normal,
                                              curve: AppAnimations.easeInOut,
                                              width: 60,
                                              height: 4,
                                              decoration: BoxDecoration(
                                                color: displayColor,
                                                borderRadius: BorderRadius.circular(
                                                  AppDesign.radiusS,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: AppDesign.spacingM),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                AnimatedDefaultTextStyle(
                                                  duration: AppAnimations.normal,
                                                  curve: AppAnimations.easeInOut,
                                                  style: AppTypography.displayLarge.copyWith(
                                                    color: displayColor,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                  child: const Text('\$'),
                                                ),
                                                Flexible(
                                                  child: FittedBox(
                                                    fit: BoxFit.scaleDown,
                                                    child: AnimatedDigitWidget(
                                                      key: ValueKey<int>(
                                                        netDifference.sign.toInt(),
                                                      ),
                                                      fractionDigits: 2,
                                                      value: netDifference.abs(),
                                                      textStyle: AppTypography.displayLarge.copyWith(
                                                        color: displayColor,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                      enableSeparator: true,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: AppDesign.spacingS),
                                            AnimatedSwitcher(
                                              duration: AppAnimations.normal,
                                              child: Text(
                                                isPositive ? 'Surplus' : 'Deficit',
                                                key: ValueKey<bool>(isPositive),
                                                style: AppTypography.bodyMedium.copyWith(
                                                  color: AppDesign.getTextSecondary(context),
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                    const Spacer(),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: AppDesign.spacingM),
                            Expanded(
                              flex: 4,
                              child: ElevatedCard(
                                elevation: AppDesign.elevationM,
                                onTap: () => _openTransactionsPage(context),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Transactions',
                                                style: AppTypography.headingMedium.copyWith(
                                                  color: AppDesign.getTextPrimary(context),
                                                ),
                                              ),
                                              const SizedBox(height: AppDesign.spacingXXS),
                                              Text(
                                                'Tap to view the full list.',
                                                style: AppTypography.bodySmall.copyWith(
                                                  color: AppDesign.getTextSecondary(context),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Icon(
                                          CupertinoIcons.chevron_right,
                                          size: AppDesign.iconS,
                                          color: AppDesign.getTextTertiary(context),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: AppDesign.spacingM),
                                    Expanded(
                                      child: recentTransactions.isEmpty
                                          ? Center(
                                              child: Text(
                                                'No transactions yet.',
                                                style: AppTypography.bodyMedium.copyWith(
                                                  color: AppDesign.getTextSecondary(context),
                                                ),
                                              ),
                                            )
                                          : Column(
                                              children: [
                                                for (int index = 0;
                                                    index < recentTransactions.length;
                                                    index++) ...[
                                                  Expanded(
                                                    child: _RecentTransactionRow(
                                                      transaction: recentTransactions[index],
                                                    ),
                                                  ),
                                                  if (index <
                                                      recentTransactions.length - 1)
                                                    Divider(
                                                      height: AppDesign.spacingS,
                                                      color: AppDesign.getBorderColor(context),
                                                    ),
                                                ],
                                                if (recentTransactions.length < 3)
                                                  Expanded(
                                                    child: Align(
                                                      alignment: Alignment.centerLeft,
                                                      child: Text(
                                                        'Recent activity will appear here as you add more transactions.',
                                                        style: AppTypography.bodySmall.copyWith(
                                                          color: AppDesign.getTextTertiary(context),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppDesign.spacingM),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: AppButton.primary(
                              label: 'Add Expense',
                              icon: CupertinoIcons.minus_circle_fill,
                              gradient: AppDesign.getExpenseGradient(context),
                              onPressed: () {
                                showTransactionForm(
                                  context,
                                  TransactionTyp.expense,
                                  transactionModel.addTransaction,
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: AppDesign.spacingM),
                          Expanded(
                            child: AppButton.primary(
                              label: 'Add Income',
                              icon: CupertinoIcons.plus_circle_fill,
                              gradient: AppDesign.getIncomeGradient(context),
                              onPressed: () {
                                showTransactionForm(
                                  context,
                                  TransactionTyp.income,
                                  transactionModel.addTransaction,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RecentTransactionRow extends StatelessWidget {
  final Transaction transaction;

  const _RecentTransactionRow({
    required this.transaction,
  });

  @override
  Widget build(BuildContext context) {
    final isExpense = transaction.type == TransactionTyp.expense;
    final amountColor = isExpense
        ? AppDesign.getExpenseColor(context)
        : AppDesign.getIncomeColor(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxHeight < 44;

        return Row(
          children: [
            Container(
              width: isCompact ? 32 : 36,
              height: isCompact ? 32 : 36,
              decoration: BoxDecoration(
                color: amountColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(AppDesign.radiusM),
              ),
              child: Icon(
                isExpense
                    ? CupertinoIcons.arrow_up_circle_fill
                    : CupertinoIcons.arrow_down_circle_fill,
                color: amountColor,
                size: isCompact ? AppDesign.iconS : AppDesign.iconM,
              ),
            ),
            const SizedBox(width: AppDesign.spacingM),
            Expanded(
              child: isCompact
                  ? Text(
                      '${transaction.description} • ${DateFormat.MMMd().format(transaction.date)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppDesign.getTextPrimary(context),
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          transaction.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppDesign.getTextPrimary(context),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: AppDesign.spacingXXS),
                        Text(
                          '${transaction.category} • ${DateFormat.MMMd().format(transaction.date)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppDesign.getTextSecondary(context),
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(width: AppDesign.spacingS),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '${isExpense ? '-' : '+'}\$${NumberFormat("#,##0.00", "en_US").format(transaction.amount)}',
                  style: AppTypography.bodyMedium.copyWith(
                    color: amountColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
