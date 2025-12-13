import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:animated_digit/animated_digit.dart';
import 'transaction.dart';
import 'transaction_model.dart';
import 'transaction_form.dart';
import 'package:provider/provider.dart';
import 'design_system.dart';
import 'utils/platform_utils.dart';

class SpendingPage extends StatefulWidget {
  final List<Transaction> transactions = [];

  SpendingPage({
    Key? key,
  }) : super(key: key);

  @override
  SpendingPageState createState() => SpendingPageState();
}

class SpendingPageState extends State<SpendingPage> {
  List<String> months = [
    "January",
    "February",
    "March",
    "April",
    "May",
    "June",
    "July",
    "August",
    "September",
    "October",
    "November",
    "December"
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
        .where((transaction) => transaction.type == TransactionTyp.INCOME)
        .map((transaction) => transaction.amount)
        .fold(0, (previousValue, amount) => previousValue + amount);
  }

  // calculate total expenses
  double calculateTotalExpenses(List<Transaction> transactions) {
    return transactions
        .where((transaction) => transaction.type == TransactionTyp.EXPENSE)
        .map((transaction) => transaction.amount)
        .fold(0, (previousValue, amount) => previousValue + amount);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TransactionModel>(
      builder: (context, transactionModel, child) {
        double totalIncome =
            calculateTotalIncome(transactionModel.currentMonthTransactions);
        double totalExpenses =
            calculateTotalExpenses(transactionModel.currentMonthTransactions);
        ValueNotifier<double> netDifference = ValueNotifier<double>(0.0);
        netDifference.value = totalIncome - totalExpenses;

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
            child: SingleChildScrollView(
              physics: PlatformUtils.platformScrollPhysics,
              padding: const EdgeInsets.all(AppDesign.spacingM),
              child: Builder(
                builder: (context) {
                  final isDark = Theme.of(context).brightness == Brightness.dark;
                    
                    return Column(
                      children: <Widget>[
                        // Income and Expenses Metric Cards
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
                    const SizedBox(height: AppDesign.spacingL),

                    // Month Selector - Enhanced with better styling
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
                                ? Column(
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
                                                DateTime(DateTime.now().year, index + 1));
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
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppDesign.spacingL),

                    // Cash Flow Display - Enhanced with animations
                    ElevatedCard(
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
                                "Cash Flow",
                                style: AppTypography.headingMedium.copyWith(
                                  color: AppDesign.getTextSecondary(context),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppDesign.spacingL),
                          ValueListenableBuilder<double>(
                            valueListenable: netDifference,
                            builder: (context, value, child) {
                              final isPositive = value >= 0;
                              final displayColor = isPositive
                                  ? AppDesign.getIncomeColor(context)
                                  : AppDesign.getExpenseColor(context);
                              
                              return Column(
                                children: [
                                  // Animated color indicator
                                  AnimatedContainer(
                                    duration: AppAnimations.normal,
                                    curve: AppAnimations.easeInOut,
                                    width: 60,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: displayColor,
                                      borderRadius: BorderRadius.circular(AppDesign.radiusS),
                                    ),
                                  ),
                                  const SizedBox(height: AppDesign.spacingM),
                                  // Animated value display
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
                                        child: Text('\$'),
                                      ),
                                      AnimatedDigitWidget(
                                        key: ValueKey<int>(value.sign.toInt()),
                                        fractionDigits: 2,
                                        value: value.abs(),
                                        textStyle: AppTypography.displayLarge.copyWith(
                                          color: displayColor,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        enableSeparator: true,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: AppDesign.spacingS),
                                  // Status text
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
                        ],
                      ),
                    ),

                    const SizedBox(height: AppDesign.spacingXL),

                    // Add Expense and Add Income Buttons - Enhanced
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
                                TransactionTyp.EXPENSE,
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
                                TransactionTyp.INCOME,
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
