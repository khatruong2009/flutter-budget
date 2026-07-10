import 'package:animated_digit/animated_digit.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import 'common.dart';
import 'design_system.dart';
import 'transaction.dart';
import 'transaction_form.dart';
import 'transaction_model.dart';
import 'transaction_page.dart';
import 'utils/platform_utils.dart';
import 'widgets/voice_recording_sheet.dart';

class SpendingPage extends StatefulWidget {
  const SpendingPage({super.key});

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

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
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
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BudgetLimitSheet(
        category: category,
        currentLimit: _getCategoryBudgetLimit(model, category),
        onSave: (limit) => _setCategoryBudgetLimit(model, category, limit),
        onRemove: () => _removeCategoryBudgetLimit(model, category),
      ),
    );
  }

  /// Bound to the `EDIT` link: pick a category, then open the existing limit
  /// sheet for it. Categories with a limit already set are marked.
  Future<void> _showEditBudgetsSheet(
    BuildContext context,
    TransactionModel model,
  ) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.getCard(isDark),
            border: Border.all(color: AppColors.getCardBorder(isDark)),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.getTextTertiaryColor(isDark)
                          .withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                  child: Text(
                    'Edit budgets',
                    style: AppTypography.sectionHeader.copyWith(
                      color: AppColors.getTextColor(isDark),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                  child: Text(
                    'Choose a category to set or change its monthly limit.',
                    style: AppTypography.rowSubtitle.copyWith(
                      color: AppColors.getTextSecondaryColor(isDark),
                    ),
                  ),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                    children: [
                      for (final category in expenseCategories.keys)
                        _EditBudgetCategoryTile(
                          category: category,
                          icon: expenseCategories[category] ??
                              CupertinoIcons.square_grid_2x2,
                          limit: model.getCategoryBudgetLimit(category),
                          onTap: () => Navigator.of(sheetContext).pop(category),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selected != null && context.mounted) {
      await _showBudgetLimitSheet(context, model, selected);
    }
  }

  /// Long-press shortcut for the main add button. Selecting a category first
  /// lets the transaction form focus immediately on its amount and details.
  Future<void> _showQuickExpenseCategoryPicker(
    TransactionModel transactionModel,
  ) async {
    final selectedCategory = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _QuickExpenseCategorySheet(),
    );

    if (!mounted || selectedCategory == null) return;

    await showTransactionForm(
      context,
      TransactionTyp.expense,
      transactionModel.addTransaction,
      initialCategory: selectedCategory,
    );
  }

  /// Days remaining in the selected month. For the current calendar month this
  /// is days after today; for any other month it is the month's total length.
  int _daysLeftInMonth(DateTime month) {
    final now = DateTime.now();
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    if (month.year == now.year && month.month == now.month) {
      return (daysInMonth - now.day).clamp(0, daysInMonth);
    }
    return daysInMonth;
  }

  /// Percent change vs the previous month, guarding division by zero.
  /// Returns null when there is no meaningful baseline to compare against.
  double? _percentDelta(double current, double previous) {
    if (previous == 0) {
      if (current == 0) return null;
      return 100;
    }
    return (current - previous) / previous * 100;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TransactionModel>(
      builder: (context, transactionModel, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;

        final totalIncome =
            calculateTotalIncome(transactionModel.currentMonthTransactions);
        final totalExpenses =
            calculateTotalExpenses(transactionModel.currentMonthTransactions);
        final safeToSpend = totalIncome - totalExpenses;
        final recentTransactions =
            transactionModel.getAllTransactionsSorted().take(3).toList();
        final selectedBudgetMonth = DateTime(
          transactionModel.selectedMonth.year,
          transactionModel.selectedMonth.month,
        );

        // Previous month figures for the delta lines.
        final previousMonth = DateTime(
          selectedBudgetMonth.year,
          selectedBudgetMonth.month - 1,
        );
        final previousSummary =
            transactionModel.getMonthlySummary(previousMonth);
        final previousIncome = previousSummary['income'] ?? 0.0;
        final previousExpenses = previousSummary['expenses'] ?? 0.0;
        final incomeDelta = _percentDelta(totalIncome, previousIncome);
        final expenseDelta = _percentDelta(totalExpenses, previousExpenses);
        final previousMonthLabel = DateFormat.MMMM().format(previousMonth);

        final daysLeft = _daysLeftInMonth(selectedBudgetMonth);

        final budgets =
            _buildBudgetProgressItems(transactionModel, selectedBudgetMonth);

        return BudgiePageScaffold(
          fab: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (PlatformUtils.isMobile) ...[
                GlowFab(
                  size: 44,
                  icon: Symbols.mic_rounded,
                  semanticLabel: 'Add by voice',
                  onPressed: () => startVoiceExpenseFlow(context),
                ),
                const SizedBox(height: 12),
              ],
              GlowFab(
                onPressed: () => showTransactionForm(
                  context,
                  TransactionTyp.expense,
                  transactionModel.addTransaction,
                ),
                onLongPress: () =>
                    _showQuickExpenseCategoryPicker(transactionModel),
                semanticLabel: 'Add transaction',
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: EdgeInsets.only(
              bottom: DockMetrics.contentBottomPadding(context),
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  BudgieHeader(
                    showLogo: true,
                    centerTrailing: true,
                    trailing: MonthPill(
                      label: DateFormat.yMMMM()
                          .format(transactionModel.selectedMonth),
                      onTap: () => setState(() => isExpanded = !isExpanded),
                    ),
                  ),
                  _MonthPickerPanel(
                    isExpanded: isExpanded,
                    months: months,
                    scrollController: scrollController,
                    onSelected: (index) {
                      setState(() => currentMonthIndex = index);
                      transactionModel.selectMonth(
                        DateTime(
                          transactionModel.selectedMonth.year,
                          index + 1,
                        ),
                      );
                    },
                  ),
                  _HeroSafeToSpend(
                    amount: safeToSpend,
                    income: totalIncome,
                    daysLeft: daysLeft,
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _SpendGauge(
                      spent: totalExpenses,
                      income: totalIncome,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: _FlowChip(
                            label: 'Income',
                            amount: totalIncome,
                            dotColor: AppColors.getIncome(isDark),
                            delta: incomeDelta,
                            deltaColor: AppColors.getIncome(isDark),
                            previousMonthLabel: previousMonthLabel,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _FlowChip(
                            label: 'Expenses',
                            amount: totalExpenses,
                            dotColor: AppColors.getDanger(isDark),
                            delta: expenseDelta,
                            deltaColor: AppColors.getDanger(isDark),
                            previousMonthLabel: previousMonthLabel,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SectionHeader(
                          title: 'Budgets',
                          linkLabel: 'EDIT',
                          onLinkTap: () => _showEditBudgetsSheet(
                            context,
                            transactionModel,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _BudgetsCard(
                          budgets: budgets,
                          onRowTap: (category) => _showBudgetLimitSheet(
                            context,
                            transactionModel,
                            category,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SectionHeader(
                          title: 'Recent activity',
                          linkLabel: 'SEE ALL',
                          onLinkTap: () => _openTransactionsPage(context),
                        ),
                        const SizedBox(height: 12),
                        _RecentActivityCard(
                          transactions: recentTransactions,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: PillButton(
                            label: 'Expense',
                            icon: Symbols.remove_rounded,
                            color: AppColors.getDanger(isDark),
                            onPressed: () => showTransactionForm(
                              context,
                              TransactionTyp.expense,
                              transactionModel.addTransaction,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: PillButton(
                            label: 'Income',
                            icon: Symbols.add_rounded,
                            color: AppColors.getIncome(isDark),
                            onPressed: () => showTransactionForm(
                              context,
                              TransactionTyp.income,
                              transactionModel.addTransaction,
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
        );
      },
    );
  }
}

/// Category-first entry sheet opened by long-pressing the main transaction
/// button. It is intentionally limited to expenses because that is the action
/// represented by the primary add button on the Spending tab.
class _QuickExpenseCategorySheet extends StatelessWidget {
  const _QuickExpenseCategorySheet();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final categoryEntries = expenseCategories.entries.toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.66,
      minChildSize: 0.36,
      maxChildSize: 0.9,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: AppColors.getCard(isDark),
          border: Border.all(color: AppColors.getCardBorder(isDark)),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.getTextTertiaryColor(isDark)
                        .withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
                child: Text(
                  'Add expense',
                  style: AppTypography.sectionHeader.copyWith(
                    color: AppColors.getTextColor(isDark),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                child: Text(
                  'Choose a category, then enter the amount and description.',
                  style: AppTypography.rowSubtitle.copyWith(
                    color: AppColors.getTextSecondaryColor(isDark),
                  ),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  itemCount: categoryEntries.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    color: AppColors.getCardBorder(isDark),
                  ),
                  itemBuilder: (context, index) {
                    final entry = categoryEntries[index];
                    return Semantics(
                      button: true,
                      label: 'Choose ${entry.key}',
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          MicroInteractions.selectionClick();
                          Navigator.of(context).pop(entry.key);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 14,
                          ),
                          child: Row(
                            children: [
                              IconTile(
                                icon: entry.value,
                                color: AppColors.getDanger(isDark),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                entry.key,
                                style: AppTypography.rowTitle.copyWith(
                                  color: AppColors.getTextColor(isDark),
                                ),
                              ),
                              const Spacer(),
                              Icon(
                                CupertinoIcons.chevron_right,
                                size: 18,
                                color: AppColors.getTextSecondaryColor(isDark),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Restyled inline month picker, driven by the header [MonthPill]. Preserves
/// the original expand/collapse + CupertinoPicker + selectMonth behavior.
/// Sheet for setting/removing a category's monthly limit. Owns its
/// TextEditingController: the route's future resolves at pop, before the
/// exit animation finishes, so a controller disposed by the caller would
/// still be rebuilt against while the sheet animates out.
class _BudgetLimitSheet extends StatefulWidget {
  final String category;
  final double? currentLimit;
  final Future<void> Function(double limit) onSave;
  final Future<void> Function() onRemove;

  const _BudgetLimitSheet({
    required this.category,
    required this.currentLimit,
    required this.onSave,
    required this.onRemove,
  });

  @override
  State<_BudgetLimitSheet> createState() => _BudgetLimitSheetState();
}

class _BudgetLimitSheetState extends State<_BudgetLimitSheet> {
  late final TextEditingController _controller;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.currentLimit == null
          ? ''
          : NumberFormat('#,##0.##', 'en_US').format(widget.currentLimit),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double? _parseBudgetLimit(String rawValue) {
    final normalized = rawValue.replaceAll(RegExp(r'[^0-9.]'), '');
    if (normalized.isEmpty) {
      return null;
    }
    return double.tryParse(normalized);
  }

  Future<void> _saveLimit() async {
    final limit = _parseBudgetLimit(_controller.text);
    if (_isSaving || limit == null || limit <= 0) {
      return;
    }
    setState(() => _isSaving = true);
    await widget.onSave(limit);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _removeLimit() async {
    setState(() => _isSaving = true);
    await widget.onRemove();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final parsedLimit = _parseBudgetLimit(_controller.text);
    final canSave = !_isSaving && parsedLimit != null && parsedLimit > 0;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.getCard(isDark),
          border: Border.all(color: AppColors.getCardBorder(isDark)),
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(28),
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
                      color: AppColors.getTextTertiaryColor(isDark)
                          .withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: AppDesign.spacingM),
                Row(
                  children: [
                    IconTile(
                      icon: expenseCategories[widget.category] ??
                          CupertinoIcons.square_grid_2x2,
                      color: AppColors.getDanger(isDark),
                    ),
                    const SizedBox(width: AppDesign.spacingM),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.category,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.cardTitle.copyWith(
                              color: AppColors.getTextColor(isDark),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Monthly spending limit',
                            style: AppTypography.rowSubtitle.copyWith(
                              color: AppColors.getTextSecondaryColor(isDark),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDesign.spacingL),
                TextField(
                  controller: _controller,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.done,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _saveLimit(),
                  style: AppTypography.numericMedium.copyWith(
                    color: AppColors.getTextColor(isDark),
                  ),
                  decoration: InputDecoration(
                    labelText: 'Limit',
                    prefixText: '\$',
                    hintText: '0.00',
                    helperText: 'Set a positive amount for this category.',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppDesign.radiusM),
                    ),
                  ),
                ),
                const SizedBox(height: AppDesign.spacingL),
                Row(
                  children: [
                    if (widget.currentLimit != null) ...[
                      Expanded(
                        child: AppButton.secondary(
                          label: 'Remove',
                          icon: CupertinoIcons.trash,
                          onPressed: _isSaving ? null : _removeLimit,
                        ),
                      ),
                      const SizedBox(width: AppDesign.spacingM),
                    ],
                    Expanded(
                      child: AppButton.primary(
                        label: 'Save',
                        icon: CupertinoIcons.check_mark_circled_solid,
                        onPressed: canSave ? _saveLimit : null,
                        isLoading: _isSaving,
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
  }
}

class _MonthPickerPanel extends StatelessWidget {
  final bool isExpanded;
  final List<String> months;
  final FixedExtentScrollController scrollController;
  final ValueChanged<int> onSelected;

  const _MonthPickerPanel({
    required this.isExpanded,
    required this.months,
    required this.scrollController,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return AnimatedSize(
      duration:
          reduceMotion ? Duration.zero : const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      child: isExpanded
          ? Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: GlowCard(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: SizedBox(
                  height: 128,
                  child: CupertinoPicker(
                    scrollController: scrollController,
                    itemExtent: 34,
                    onSelectedItemChanged: onSelected,
                    children: months
                        .map(
                          (month) => Center(
                            child: Text(
                              month,
                              style: AppTypography.rowTitle.copyWith(
                                fontSize: 16,
                                color: AppColors.getTextColor(isDark),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}

/// Centered hero: `SAFE TO SPEND` eyebrow, two-tone amount with accent glow
/// (danger tint + glow when negative), and the income / days-left subline.
class _HeroSafeToSpend extends StatelessWidget {
  final double amount;
  final double income;
  final int daysLeft;

  const _HeroSafeToSpend({
    required this.amount,
    required this.income,
    required this.daysLeft,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isNegative = amount < 0;
    final glowColor =
        isNegative ? AppColors.getDanger(isDark) : AppColors.getAccent(isDark);
    final integerColor = isNegative
        ? AppColors.getDanger(isDark)
        : AppColors.getTextColor(isDark);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    // Round once at the cent boundary so cents stay in [0, 99] and whole-
    // dollar carries land in the integer part (float sums like 12874.999...
    // must render as $12,875.00, not $12,874.100).
    final totalCents = (amount.abs() * 100).round();
    final integerPart = totalCents ~/ 100;
    final decimalString = (totalCents % 100).toString().padLeft(2, '0');

    final incomeLabel =
        NumberFormat.currency(locale: 'en_US', symbol: '\$', decimalDigits: 0)
            .format(income);
    final daysLabel = daysLeft == 1 ? '1 day left' : '$daysLeft days left';

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 36, 24, 0),
      child: Column(
        children: [
          Semantics(
            header: true,
            child: Text(
              'SAFE TO SPEND',
              textAlign: TextAlign.center,
              style: AppTypography.eyebrow.copyWith(
                color: AppColors.getTextSecondaryColor(isDark),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Semantics(
            label:
                'Safe to spend ${isNegative ? 'negative ' : ''}\$$integerPart.$decimalString',
            child: ExcludeSemantics(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    isNegative ? '-\$' : '\$',
                    style: AppTypography.hero.copyWith(
                      color: integerColor,
                      shadows: AppColors.textGlow(glowColor, isDark: isDark),
                    ),
                  ),
                  AnimatedDigitWidget(
                    value: integerPart,
                    enableSeparator: true,
                    animateAutoSize: false,
                    duration: reduceMotion
                        ? Duration.zero
                        : const Duration(milliseconds: 900),
                    textStyle: AppTypography.hero.copyWith(
                      color: integerColor,
                      shadows: AppColors.textGlow(glowColor, isDark: isDark),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 1),
                    child: Text(
                      '.$decimalString',
                      style: AppTypography.heroDecimals.copyWith(
                        color: AppColors.getTextSecondaryColor(isDark),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'of $incomeLabel income   ·   $daysLabel',
            textAlign: TextAlign.center,
            style: AppTypography.rowSubtitle.copyWith(
              fontSize: 14,
              color: AppColors.getTextSecondaryColor(isDark),
            ),
          ),
        ],
      ),
    );
  }
}

/// 14px accent-gradient spend gauge with thumb + justified mono labels.
class _SpendGauge extends StatelessWidget {
  final double spent;
  final double income;

  const _SpendGauge({required this.spent, required this.income});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = AppColors.getAccent(isDark);
    final value = income <= 0 ? 0.0 : spent / income;

    final spentLabel =
        NumberFormat.currency(locale: 'en_US', symbol: '\$', decimalDigits: 0)
            .format(spent);
    final incomeLabel =
        NumberFormat.currency(locale: 'en_US', symbol: '\$', decimalDigits: 0)
            .format(income);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlowProgressBar(
          value: value,
          color: accent,
          height: 14,
          fillInset: 2,
          showThumb: true,
          trackColor: AppColors.getChipSurface(isDark),
          trackBorder: Border.all(color: AppColors.getHairline(isDark)),
          gradient: LinearGradient(
            colors: [
              Color.alphaBlend(
                accent.withValues(alpha: 0.55),
                AppColors.getBackground(isDark),
              ),
              accent,
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _GaugeLabel(prefix: 'SPENT', value: spentLabel),
            _GaugeLabel(prefix: 'INCOME', value: incomeLabel),
          ],
        ),
      ],
    );
  }
}

class _GaugeLabel extends StatelessWidget {
  final String prefix;
  final String value;

  const _GaugeLabel({required this.prefix, required this.value});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text.rich(
      TextSpan(
        style: AppTypography.monoLabel.copyWith(
          color: AppColors.getTextTertiaryColor(isDark),
        ),
        children: [
          TextSpan(text: '$prefix  '),
          TextSpan(
            text: value,
            style: TextStyle(color: AppColors.getTextColor(isDark)),
          ),
        ],
      ),
    );
  }
}

/// Income / Expenses stat chip: glowing dot + label, amount, and the real
/// month-over-month delta line.
class _FlowChip extends StatelessWidget {
  final String label;
  final double amount;
  final Color dotColor;
  final double? delta;
  final Color deltaColor;
  final String previousMonthLabel;

  const _FlowChip({
    required this.label,
    required this.amount,
    required this.dotColor,
    required this.delta,
    required this.deltaColor,
    required this.previousMonthLabel,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final amountLabel =
        NumberFormat.currency(locale: 'en_US', symbol: '\$', decimalDigits: 0)
            .format(amount);

    final String deltaLabel;
    if (delta == null) {
      deltaLabel = 'No $previousMonthLabel data';
    } else {
      final sign = delta! >= 0 ? '+' : '';
      deltaLabel = '$sign${delta!.toStringAsFixed(1)}% vs $previousMonthLabel';
    }

    return GlowCard(
      radius: 22,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                  boxShadow: AppColors.glow(dotColor,
                      blurRadius: 10, alpha: 0.8, isDark: isDark),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppTypography.rowSubtitle.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.getTextSecondaryColor(isDark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              amountLabel,
              style: AppTypography.chipAmount.copyWith(
                color: AppColors.getTextColor(isDark),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            deltaLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.rowSubtitle.copyWith(
              color: delta == null
                  ? AppColors.getTextTertiaryColor(isDark)
                  : deltaColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// Budgets list card: one row per expense category with an IconTile, name,
/// sub, status pill, and a glowing progress bar underneath.
class _BudgetsCard extends StatelessWidget {
  final List<_CategoryBudgetProgress> budgets;
  final ValueChanged<String> onRowTap;

  const _BudgetsCard({required this.budgets, required this.onRowTap});

  @override
  Widget build(BuildContext context) {
    return GlowListCard(
      children: [
        for (final budget in budgets)
          _BudgetRow(
            budget: budget,
            onTap: () => onRowTap(budget.category),
          ),
      ],
    );
  }
}

class _BudgetRow extends StatelessWidget {
  final _CategoryBudgetProgress budget;
  final VoidCallback onTap;

  const _BudgetRow({required this.budget, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusColor = _statusColor(isDark);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        MicroInteractions.lightImpact();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        child: Column(
          children: [
            Row(
              children: [
                IconTile(icon: budget.icon, color: statusColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        budget.category,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.rowTitle.copyWith(
                          color: AppColors.getTextColor(isDark),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _subtitle(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.rowSubtitle.copyWith(
                          color: AppColors.getTextSecondaryColor(isDark),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _statusChip(isDark, statusColor),
              ],
            ),
            const SizedBox(height: 10),
            GlowProgressBar(
              value: budget.hasLimit ? budget.progress : 0,
              color: statusColor,
              height: 8,
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(bool isDark, Color statusColor) {
    if (!budget.hasLimit) {
      return PillChip(
        label: 'Set limit',
        color: AppColors.getAccent(isDark),
        outlined: true,
      );
    }
    if (budget.isOverBudget) {
      return PillChip(
        label: '${_formatCurrency(budget.remaining.abs())} over',
        color: statusColor,
      );
    }
    return PillChip(
      label: '${_formatCurrency(budget.remaining)} left',
      color: statusColor,
    );
  }

  Color _statusColor(bool isDark) {
    if (!budget.hasLimit) {
      return AppColors.getAccent(isDark);
    }
    if (budget.isOverBudget) {
      return AppColors.getDanger(isDark);
    }
    if (budget.progress >= 0.85) {
      return AppColors.getWarning(isDark);
    }
    return AppColors.getIncome(isDark);
  }

  String _subtitle() {
    if (!budget.hasLimit) {
      if (budget.spent == 0) {
        return 'No spending · no limit';
      }
      return '${_formatCurrency(budget.spent)} spent · no limit';
    }
    return '${_formatCurrency(budget.spent)} of ${_formatCurrency(budget.limit!)}';
  }

  String _formatCurrency(double value) {
    return NumberFormat.currency(
      locale: 'en_US',
      symbol: '\$',
      decimalDigits: value.abs() >= 100 ? 0 : 2,
    ).format(value);
  }
}

/// Recent activity list card: 3 latest transactions. Income rows use a green
/// south_west tile and colored `+` amount; expenses use the category icon in a
/// primary-tinted tile and a primary-text `−` amount.
class _RecentActivityCard extends StatelessWidget {
  final List<Transaction> transactions;

  const _RecentActivityCard({required this.transactions});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (transactions.isEmpty) {
      return GlowCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: Text(
              'No transactions yet.',
              style: AppTypography.rowSubtitle.copyWith(
                fontSize: 14,
                color: AppColors.getTextSecondaryColor(isDark),
              ),
            ),
          ),
        ),
      );
    }

    return GlowListCard(
      children: [
        for (final transaction in transactions)
          _RecentActivityRow(transaction: transaction),
      ],
    );
  }
}

class _RecentActivityRow extends StatelessWidget {
  final Transaction transaction;

  const _RecentActivityRow({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isExpense = transaction.type == TransactionTyp.expense;
    final income = AppColors.getIncome(isDark);
    final accent = AppColors.getAccent(isDark);

    final tileColor = isExpense ? accent : income;
    final tileIcon = isExpense
        ? (expenseCategories[transaction.category] ??
            CupertinoIcons.square_grid_2x2)
        : Symbols.south_west_rounded;

    final amountColor = isExpense ? AppColors.getTextColor(isDark) : income;
    final sign = isExpense ? '−' : '+';
    final amountLabel =
        '$sign\$${NumberFormat('#,##0.00', 'en_US').format(transaction.amount)}';

    final description = transaction.description.isEmpty
        ? 'Transaction'
        : transaction.description;

    return Semantics(
      label:
          '$description, ${transaction.category}, ${DateFormat.MMMd().format(transaction.date)}, '
          '${isExpense ? 'expense' : 'income'} '
          '\$${NumberFormat('#,##0.00', 'en_US').format(transaction.amount)}',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              IconTile(icon: tileIcon, color: tileColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.rowTitle.copyWith(
                        color: AppColors.getTextColor(isDark),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${transaction.category} · ${DateFormat.MMMd().format(transaction.date)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.rowSubtitle.copyWith(
                        color: AppColors.getTextSecondaryColor(isDark),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                amountLabel,
                style: AppTypography.amountSmall.copyWith(color: amountColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A category row in the `EDIT` picker sheet.
class _EditBudgetCategoryTile extends StatelessWidget {
  final String category;
  final IconData icon;
  final double? limit;
  final VoidCallback onTap;

  const _EditBudgetCategoryTile({
    required this.category,
    required this.icon,
    required this.limit,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasLimit = limit != null && limit! > 0;
    final subtitle = hasLimit
        ? '${NumberFormat.currency(locale: 'en_US', symbol: '\$', decimalDigits: 0).format(limit)} limit'
        : 'No limit set';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        MicroInteractions.lightImpact();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        child: Row(
          children: [
            IconTile(
              icon: icon,
              color: hasLimit
                  ? AppColors.getAccent(isDark)
                  : AppColors.getTextSecondaryColor(isDark),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.rowTitle.copyWith(
                      color: AppColors.getTextColor(isDark),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTypography.rowSubtitle.copyWith(
                      color: AppColors.getTextSecondaryColor(isDark),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Symbols.chevron_right_rounded,
              size: 20,
              weight: 500,
              color: AppColors.getTextTertiaryColor(isDark),
            ),
          ],
        ),
      ),
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
