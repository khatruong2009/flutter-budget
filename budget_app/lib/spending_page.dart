import 'package:animated_digit/animated_digit.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'common.dart';
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

  Map<String, double> _categoryBudgetLimits(TransactionModel model) {
    return model.categoryBudgetLimits;
  }

  double? _getCategoryBudgetLimit(
    TransactionModel model,
    String category,
  ) {
    return model.getCategoryBudgetLimit(category);
  }

  double _getCategorySpendingForMonth(
    TransactionModel model,
    String category,
    DateTime month,
  ) {
    return model.getCategorySpendingForMonth(category, month);
  }

  Future<void> _setCategoryBudgetLimit(
    TransactionModel model,
    String category,
    double limit,
  ) async {
    await model.setCategoryBudgetLimit(category, limit);
  }

  Future<void> _removeCategoryBudgetLimit(
    TransactionModel model,
    String category,
  ) async {
    await model.removeCategoryBudgetLimit(category);
  }

  double? _parseBudgetLimit(String rawValue) {
    final normalized = rawValue.replaceAll(RegExp(r'[^0-9.]'), '');
    if (normalized.isEmpty) {
      return null;
    }
    return double.tryParse(normalized);
  }

  List<_CategoryBudgetProgress> _buildBudgetProgressItems(
    TransactionModel model,
    DateTime month,
  ) {
    final budgetLimits = _categoryBudgetLimits(model);
    final items = expenseCategories.keys.map((category) {
      final limit =
          _getCategoryBudgetLimit(model, category) ?? budgetLimits[category];
      final spent = _getCategorySpendingForMonth(model, category, month);

      return _CategoryBudgetProgress(
        category: category,
        icon: expenseCategories[category] ?? CupertinoIcons.square_grid_2x2,
        spent: spent,
        limit: limit,
      );
    }).toList();

    items.sort((a, b) {
      final aHasLimit = a.hasLimit ? 1 : 0;
      final bHasLimit = b.hasLimit ? 1 : 0;
      if (aHasLimit != bHasLimit) {
        return bHasLimit.compareTo(aHasLimit);
      }

      final spentCompare = b.spent.compareTo(a.spent);
      if (spentCompare != 0) {
        return spentCompare;
      }

      return a.category.compareTo(b.category);
    });

    return items;
  }

  Future<void> _showBudgetLimitSheet(
    BuildContext context,
    TransactionModel model,
    String category,
  ) async {
    final currentLimit = _getCategoryBudgetLimit(model, category);
    final controller = TextEditingController(
      text: currentLimit == null
          ? ''
          : NumberFormat('#,##0.##', 'en_US').format(currentLimit),
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        var isSaving = false;

        return StatefulBuilder(
          builder: (context, setModalState) {
            final parsedLimit = _parseBudgetLimit(controller.text);
            final canSave = !isSaving && parsedLimit != null && parsedLimit > 0;

            Future<void> saveLimit() async {
              final limit = parsedLimit;
              if (isSaving || limit == null || limit <= 0) {
                return;
              }
              setModalState(() => isSaving = true);
              await _setCategoryBudgetLimit(model, category, limit);
              if (sheetContext.mounted) {
                Navigator.of(sheetContext).pop();
              }
            }

            Future<void> removeLimit() async {
              setModalState(() => isSaving = true);
              await _removeCategoryBudgetLimit(model, category);
              if (sheetContext.mounted) {
                Navigator.of(sheetContext).pop();
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: AppDesign.getCardColor(context),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppDesign.radiusXL),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(AppDesign.spacingM),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 44,
                            height: 4,
                            decoration: BoxDecoration(
                              color: AppDesign.getTextTertiary(context)
                                  .withValues(alpha: 0.35),
                              borderRadius:
                                  BorderRadius.circular(AppDesign.radiusRound),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppDesign.spacingM),
                        Row(
                          children: [
                            _CategoryIcon(
                              icon: expenseCategories[category] ??
                                  CupertinoIcons.square_grid_2x2,
                              color: AppDesign.getExpenseColor(context),
                            ),
                            const SizedBox(width: AppDesign.spacingM),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    category,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.headingSmall.copyWith(
                                      color: AppDesign.getTextPrimary(context),
                                    ),
                                  ),
                                  const SizedBox(
                                    height: AppDesign.spacingXXS,
                                  ),
                                  Text(
                                    'Monthly spending limit',
                                    style: AppTypography.bodySmall.copyWith(
                                      color:
                                          AppDesign.getTextSecondary(context),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppDesign.spacingL),
                        TextField(
                          controller: controller,
                          autofocus: true,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          textInputAction: TextInputAction.done,
                          onChanged: (_) => setModalState(() {}),
                          onSubmitted: (_) => saveLimit(),
                          style: AppTypography.numericMedium.copyWith(
                            color: AppDesign.getTextPrimary(context),
                          ),
                          decoration: InputDecoration(
                            labelText: 'Limit',
                            prefixText: '\$',
                            hintText: '0.00',
                            helperText:
                                'Set a positive amount for this category.',
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(AppDesign.radiusM),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppDesign.spacingL),
                        Row(
                          children: [
                            if (currentLimit != null) ...[
                              Expanded(
                                child: AppButton.secondary(
                                  label: 'Remove',
                                  icon: CupertinoIcons.trash,
                                  onPressed: isSaving ? null : removeLimit,
                                ),
                              ),
                              const SizedBox(width: AppDesign.spacingM),
                            ],
                            Expanded(
                              child: AppButton.primary(
                                label: 'Save',
                                icon: CupertinoIcons.check_mark_circled_solid,
                                onPressed: canSave ? saveLimit : null,
                                isLoading: isSaving,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    controller.dispose();
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
        final selectedBudgetMonth = DateTime(
          transactionModel.selectedMonth.year,
          transactionModel.selectedMonth.month,
        );

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
                  final isDark =
                      Theme.of(context).brightness == Brightness.dark;

                  return Column(
                    children: <Widget>[
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.only(
                            bottom: AppDesign.spacingS,
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: AnimatedMetricCard(
                                      label: 'Income',
                                      value: totalIncome,
                                      icon:
                                          CupertinoIcons.arrow_down_circle_fill,
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
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            months[currentMonthIndex],
                                            style: AppTypography.bodyMedium
                                                .copyWith(
                                              color: AppDesign.getTextPrimary(
                                                  context),
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
                                              color: AppDesign.getTextSecondary(
                                                  context),
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
                                                  const SizedBox(
                                                    height: AppDesign.spacingS,
                                                  ),
                                                  Expanded(
                                                    child: CupertinoPicker(
                                                      scrollController:
                                                          scrollController,
                                                      itemExtent: 32,
                                                      onSelectedItemChanged:
                                                          (int index) {
                                                        setState(() {
                                                          currentMonthIndex =
                                                              index;
                                                        });
                                                        transactionModel
                                                            .selectMonth(
                                                          DateTime(
                                                            DateTime.now().year,
                                                            index + 1,
                                                          ),
                                                        );
                                                      },
                                                      children: months
                                                          .map((String month) {
                                                        return Center(
                                                          child: Text(
                                                            month,
                                                            style: AppTypography
                                                                .bodyMedium
                                                                .copyWith(
                                                              color: AppDesign
                                                                  .getTextPrimary(
                                                                      context),
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
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
                              ElevatedCard(
                                elevation: AppDesign.elevationM,
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          CupertinoIcons.chart_bar_alt_fill,
                                          size: AppDesign.iconM,
                                          color: AppDesign.getTextSecondary(
                                            context,
                                          ),
                                        ),
                                        const SizedBox(
                                          width: AppDesign.spacingS,
                                        ),
                                        Text(
                                          'Cash Flow',
                                          style: AppTypography.headingMedium
                                              .copyWith(
                                            color: AppDesign.getTextSecondary(
                                              context,
                                            ),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: AppDesign.spacingL),
                                    Builder(
                                      builder: (context) {
                                        final isPositive = netDifference >= 0;
                                        final displayColor = isPositive
                                            ? AppDesign.getIncomeColor(context)
                                            : AppDesign.getExpenseColor(
                                                context,
                                              );

                                        return Column(
                                          children: [
                                            AnimatedContainer(
                                              duration: AppAnimations.normal,
                                              curve: AppAnimations.easeInOut,
                                              width: 60,
                                              height: 4,
                                              decoration: BoxDecoration(
                                                color: displayColor,
                                                borderRadius:
                                                    BorderRadius.circular(
                                                  AppDesign.radiusS,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(
                                              height: AppDesign.spacingM,
                                            ),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                AnimatedDefaultTextStyle(
                                                  duration:
                                                      AppAnimations.normal,
                                                  curve:
                                                      AppAnimations.easeInOut,
                                                  style: AppTypography
                                                      .displayLarge
                                                      .copyWith(
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
                                                        netDifference.sign
                                                            .toInt(),
                                                      ),
                                                      fractionDigits: 2,
                                                      value:
                                                          netDifference.abs(),
                                                      textStyle: AppTypography
                                                          .displayLarge
                                                          .copyWith(
                                                        color: displayColor,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                      enableSeparator: true,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(
                                              height: AppDesign.spacingS,
                                            ),
                                            AnimatedSwitcher(
                                              duration: AppAnimations.normal,
                                              child: Text(
                                                isPositive
                                                    ? 'Surplus'
                                                    : 'Deficit',
                                                key: ValueKey<bool>(
                                                  isPositive,
                                                ),
                                                style: AppTypography.bodyMedium
                                                    .copyWith(
                                                  color: AppDesign
                                                      .getTextSecondary(
                                                    context,
                                                  ),
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
                              const SizedBox(height: AppDesign.spacingM),
                              ElevatedCard(
                                elevation: AppDesign.elevationM,
                                onTap: () => _openTransactionsPage(context),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Transactions',
                                                style: AppTypography
                                                    .headingMedium
                                                    .copyWith(
                                                  color:
                                                      AppDesign.getTextPrimary(
                                                    context,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(
                                                height: AppDesign.spacingXXS,
                                              ),
                                              Text(
                                                'Tap to view the full list.',
                                                style: AppTypography.bodySmall
                                                    .copyWith(
                                                  color: AppDesign
                                                      .getTextSecondary(
                                                    context,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Icon(
                                          CupertinoIcons.chevron_right,
                                          size: AppDesign.iconS,
                                          color: AppDesign.getTextTertiary(
                                            context,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: AppDesign.spacingM),
                                    if (recentTransactions.isEmpty)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: AppDesign.spacingL,
                                        ),
                                        child: Center(
                                          child: Text(
                                            'No transactions yet.',
                                            style: AppTypography.bodyMedium
                                                .copyWith(
                                              color: AppDesign.getTextSecondary(
                                                  context),
                                            ),
                                          ),
                                        ),
                                      )
                                    else
                                      Column(
                                        children: [
                                          for (int index = 0;
                                              index < recentTransactions.length;
                                              index++) ...[
                                            SizedBox(
                                              height: 52,
                                              child: _RecentTransactionRow(
                                                transaction:
                                                    recentTransactions[index],
                                              ),
                                            ),
                                            if (index <
                                                recentTransactions.length - 1)
                                              Divider(
                                                height: AppDesign.spacingS,
                                                color: AppDesign.getBorderColor(
                                                  context,
                                                ),
                                              ),
                                          ],
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: AppDesign.spacingM),
                              SizedBox(
                                width: double.infinity,
                                child: _BudgetProgressSection(
                                  month: selectedBudgetMonth,
                                  budgets: _buildBudgetProgressItems(
                                    transactionModel,
                                    selectedBudgetMonth,
                                  ),
                                  onEditCategory: (category) =>
                                      _showBudgetLimitSheet(
                                    context,
                                    transactionModel,
                                    category,
                                  ),
                                ),
                              ),
                            ],
                          ),
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

class _CategoryBudgetProgress {
  final String category;
  final IconData icon;
  final double spent;
  final double? limit;

  const _CategoryBudgetProgress({
    required this.category,
    required this.icon,
    required this.spent,
    required this.limit,
  });

  bool get hasLimit => limit != null && limit! > 0;

  double get remaining => (limit ?? 0) - spent;

  bool get isOverBudget => hasLimit && remaining < 0;

  double get progress => hasLimit ? spent / limit! : 0;
}

class _BudgetProgressSection extends StatelessWidget {
  final DateTime month;
  final List<_CategoryBudgetProgress> budgets;
  final ValueChanged<String> onEditCategory;

  const _BudgetProgressSection({
    required this.month,
    required this.budgets,
    required this.onEditCategory,
  });

  @override
  Widget build(BuildContext context) {
    final activeBudgets = budgets.where((budget) => budget.hasLimit).toList();
    final totalLimit = activeBudgets.fold<double>(
      0,
      (total, budget) => total + (budget.limit ?? 0),
    );
    final totalSpent = activeBudgets.fold<double>(
      0,
      (total, budget) => total + budget.spent,
    );
    final remaining = totalLimit - totalSpent;
    final overBudgetCount =
        activeBudgets.where((budget) => budget.isOverBudget).length;
    final statusColor = overBudgetCount > 0
        ? AppDesign.getErrorColor(context)
        : AppDesign.getIncomeColor(context);

    return ElevatedCard(
      elevation: AppDesign.elevationM,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _CategoryIcon(
                icon: CupertinoIcons.speedometer,
                color: statusColor,
              ),
              const SizedBox(width: AppDesign.spacingM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Budget Limits',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.headingMedium.copyWith(
                        color: AppDesign.getTextPrimary(context),
                      ),
                    ),
                    const SizedBox(height: AppDesign.spacingXXS),
                    Text(
                      DateFormat.yMMMM().format(month),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppDesign.getTextSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDesign.spacingM),
          if (activeBudgets.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppDesign.spacingM),
              decoration: BoxDecoration(
                color:
                    AppDesign.getSurfaceColor(context).withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(AppDesign.radiusM),
                border: Border.all(
                  color: AppDesign.getBorderColor(context),
                ),
              ),
              child: Text(
                'Set category limits to track monthly spending progress.',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppDesign.getTextSecondary(context),
                ),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: _BudgetSummaryMetric(
                    label: 'Spent',
                    value: totalSpent,
                    color: AppDesign.getExpenseColor(context),
                  ),
                ),
                const SizedBox(width: AppDesign.spacingS),
                Expanded(
                  child: _BudgetSummaryMetric(
                    label: 'Limit',
                    value: totalLimit,
                    color: AppDesign.getTextPrimary(context),
                  ),
                ),
                const SizedBox(width: AppDesign.spacingS),
                Expanded(
                  child: _BudgetSummaryMetric(
                    label: remaining >= 0 ? 'Left' : 'Over',
                    value: remaining.abs(),
                    color: statusColor,
                  ),
                ),
              ],
            ),
          const SizedBox(height: AppDesign.spacingM),
          for (int index = 0; index < budgets.length; index++) ...[
            _CategoryBudgetRow(
              budget: budgets[index],
              onTap: () => onEditCategory(budgets[index].category),
            ),
            if (index < budgets.length - 1)
              Divider(
                height: AppDesign.spacingM,
                color: AppDesign.getBorderColor(context),
              ),
          ],
        ],
      ),
    );
  }
}

class _BudgetSummaryMetric extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _BudgetSummaryMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDesign.spacingS,
        vertical: AppDesign.spacingS,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDesign.radiusM),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.captionSmall.copyWith(
              color: AppDesign.getTextSecondary(context),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppDesign.spacingXS),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              NumberFormat.currency(
                locale: 'en_US',
                symbol: '\$',
                decimalDigits: 0,
              ).format(value),
              style: AppTypography.numericSmall.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryBudgetRow extends StatelessWidget {
  final _CategoryBudgetProgress budget;
  final VoidCallback onTap;

  const _CategoryBudgetRow({
    required this.budget,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(context);
    final limit = budget.limit;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDesign.radiusM),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppDesign.spacingS),
          child: Column(
            children: [
              Row(
                children: [
                  _CategoryIcon(
                    icon: budget.icon,
                    color: statusColor,
                  ),
                  const SizedBox(width: AppDesign.spacingM),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          budget.category,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppDesign.getTextPrimary(context),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: AppDesign.spacingXXS),
                        Text(
                          _detailText(context),
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
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 112),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        _statusText(),
                        style: AppTypography.labelMedium.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppDesign.spacingS),
                  Icon(
                    CupertinoIcons.chevron_right,
                    size: AppDesign.iconXS,
                    color: AppDesign.getTextTertiary(context),
                  ),
                ],
              ),
              const SizedBox(height: AppDesign.spacingS),
              _BudgetProgressBar(
                progress: budget.progress,
                color: statusColor,
                isActive: limit != null && limit > 0,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(BuildContext context) {
    if (!budget.hasLimit) {
      return AppDesign.getInfoColor(context);
    }
    if (budget.isOverBudget) {
      return AppDesign.getErrorColor(context);
    }
    if (budget.progress >= 0.85) {
      return AppDesign.getWarningColor(context);
    }
    return AppDesign.getIncomeColor(context);
  }

  String _detailText(BuildContext context) {
    final spent = _formatCurrency(budget.spent);
    if (!budget.hasLimit) {
      if (budget.spent == 0) {
        return 'No spending this month';
      }
      return '$spent spent this month';
    }

    return '$spent spent of ${_formatCurrency(budget.limit!)}';
  }

  String _statusText() {
    if (!budget.hasLimit) {
      return 'Set limit';
    }
    if (budget.isOverBudget) {
      return '${_formatCurrency(budget.remaining.abs())} over';
    }
    return '${_formatCurrency(budget.remaining)} left';
  }

  String _formatCurrency(double value) {
    return NumberFormat.currency(
      locale: 'en_US',
      symbol: '\$',
      decimalDigits: value.abs() >= 100 ? 0 : 2,
    ).format(value);
  }
}

class _BudgetProgressBar extends StatelessWidget {
  final double progress;
  final Color color;
  final bool isActive;

  const _BudgetProgressBar({
    required this.progress,
    required this.color,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final fill = progress.clamp(0, 1).toDouble();

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppDesign.radiusRound),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Container(
            height: 8,
            color: AppDesign.getBorderColor(context).withValues(alpha: 0.45),
            child: Align(
              alignment: Alignment.centerLeft,
              child: AnimatedContainer(
                duration: AppAnimations.normal,
                curve: AppAnimations.easeInOut,
                width: isActive ? constraints.maxWidth * fill : 0,
                height: 8,
                color: color,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CategoryIcon extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _CategoryIcon({
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppDesign.radiusM),
      ),
      child: Icon(
        icon,
        color: color,
        size: AppDesign.iconS,
      ),
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
