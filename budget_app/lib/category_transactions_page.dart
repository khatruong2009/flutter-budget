import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'transaction_model.dart';
import 'transaction.dart';
import 'design_system.dart';
import 'widgets/empty_state.dart';
import 'widgets/recurrence_indicator.dart';
import 'utils/platform_utils.dart';
import 'money_formatter.dart';

/// Drill-in destination from a Categories breakdown row: shows every
/// transaction in [category] for [month], newest first, with the same
/// swipe-to-delete behavior as the rest of the app.
class CategoryTransactionsPage extends StatelessWidget {
  final String category;
  final Color categoryColor;
  final IconData? categoryIcon;
  final DateTime month;

  const CategoryTransactionsPage({
    Key? key,
    required this.category,
    required this.categoryColor,
    this.categoryIcon,
    required this.month,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<TransactionModel>(
      builder: (context, transactionModel, child) {
        // Filter transactions by category and month.
        final categoryTransactions = transactionModel
            .getTransactionsForMonth(month)
            .where((t) =>
                t.category == category && t.type == TransactionTyp.expense)
            .toList()
          ..sort(Transaction.compareNewestFirst);

        final double total = categoryTransactions.fold(
          0.0,
          (sum, transaction) => sum + transaction.amount,
        );

        return Scaffold(
          backgroundColor: AppColors.getBackground(isDark),
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(context, isDark),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: _buildSummaryCard(
                    context,
                    isDark,
                    total,
                    categoryTransactions.length,
                  ),
                ),
                if (categoryTransactions.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
                    child: Text(
                      'TRANSACTIONS',
                      style: AppTypography.eyebrow.copyWith(
                        color: AppColors.getTextTertiaryColor(isDark),
                      ),
                    ),
                  ),
                Expanded(
                  child: categoryTransactions.isEmpty
                      ? EmptyState(
                          type: EmptyStateType.noData,
                          title: 'No Transactions',
                          message: 'No transactions found in this category for '
                              '${DateFormat('MMMM').format(month)}',
                          icon: CupertinoIcons.square_list,
                        )
                      : ListView.separated(
                          physics: PlatformUtils.platformScrollPhysics,
                          padding: EdgeInsets.fromLTRB(
                            20,
                            12,
                            20,
                            DockMetrics.contentBottomPadding(context),
                          ),
                          itemCount: categoryTransactions.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final transaction = categoryTransactions[index];
                            return _TransactionRow(
                              transaction: transaction,
                              color: categoryColor,
                              icon: categoryIcon,
                              onDelete: () {
                                transactionModel.deleteTransaction(transaction);
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              MicroInteractions.lightImpact();
              Navigator.pop(context);
            },
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              child: Icon(
                Symbols.arrow_back_ios_new_rounded,
                size: 18,
                weight: 500,
                color: AppColors.getTextColor(isDark),
              ),
            ),
          ),
          Expanded(
            child: Text(
              category,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.cardTitle.copyWith(
                color: AppColors.getTextColor(isDark),
              ),
            ),
          ),
          const SizedBox(width: 36, height: 36),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    bool isDark,
    double total,
    int count,
  ) {
    final base = AppColors.getCard(isDark);

    return GlowCard(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.alphaBlend(categoryColor.withValues(alpha: 0.22), base),
          base,
        ],
      ),
      border: Border.all(color: categoryColor.withValues(alpha: 0.3)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'TOTAL SPENT',
                  style: AppTypography.eyebrow.copyWith(
                    color: AppColors.getTextSecondaryColor(isDark),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      MoneyFormatter.format(total),
                      style: AppTypography.heroSmall.copyWith(
                        color: AppColors.getTextColor(isDark),
                        shadows:
                            AppColors.textGlow(categoryColor, isDark: isDark),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    PillChip(
                      label: DateFormat('MMMM yyyy').format(month),
                      color: categoryColor,
                    ),
                    PillChip(
                      label: '$count transaction${count == 1 ? '' : 's'}',
                      color: categoryColor,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          IconTile(
            icon: categoryIcon ?? CupertinoIcons.square_grid_2x2,
            color: categoryColor,
            size: 56,
            radius: 18,
            iconSize: 28,
          ),
        ],
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  final Transaction transaction;
  final Color color;
  final IconData? icon;
  final VoidCallback onDelete;

  const _TransactionRow({
    required this.transaction,
    required this.color,
    required this.icon,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dismissible(
      key: ValueKey(transaction.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        await MicroInteractions.mediumImpact();
        if (!context.mounted) return false;
        return _confirmDelete(context);
      },
      onDismissed: (direction) {
        MicroInteractions.heavyImpact();
        onDelete();
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.getDanger(isDark),
          borderRadius: BorderRadius.circular(26),
        ),
        child: const Icon(
          Symbols.delete_rounded,
          color: Colors.white,
          size: 22,
          weight: 500,
        ),
      ),
      child: GlowCard(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        child: Row(
          children: [
            IconTile(
                icon: icon ?? CupertinoIcons.square_grid_2x2, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          transaction.description,
                          style: AppTypography.rowTitle.copyWith(
                            color: AppColors.getTextColor(isDark),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (transaction.isRecurring) ...[
                        const SizedBox(width: 6),
                        RecurrenceIndicator(
                          size: 16,
                          color: AppColors.getTextSecondaryColor(isDark),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat.MMMd().format(transaction.date),
                    style: AppTypography.rowSubtitle.copyWith(
                      color: AppColors.getTextTertiaryColor(isDark),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              MoneyFormatter.format(transaction.amount),
              style: AppTypography.amountSmall.copyWith(
                color: AppColors.getTextColor(isDark),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Delete Transaction'),
        content: const Text(
          'Are you sure you want to delete this transaction?',
        ),
        actions: <Widget>[
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Delete'),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
  }
}
