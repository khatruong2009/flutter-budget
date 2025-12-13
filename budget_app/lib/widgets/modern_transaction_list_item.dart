import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import '../transaction.dart';
import '../design_system.dart';
import '../common.dart';
import '../utils/accessibility_utils.dart';

/// ModernTransactionListItem is an enhanced transaction list item component
/// featuring elevated cards, solid color icon containers, and swipe-to-delete
class ModernTransactionListItem extends StatelessWidget {
  /// The transaction to display
  final Transaction transaction;
  
  /// Callback when the item is tapped (for editing)
  final VoidCallback onTap;
  
  /// Callback when the item is deleted via swipe
  final VoidCallback onDelete;

  const ModernTransactionListItem({
    super.key,
    required this.transaction,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isExpense = transaction.type == TransactionTyp.EXPENSE;
    final categoryColor = isExpense
        ? AppDesign.getExpenseColor(context)
        : AppDesign.getIncomeColor(context);

    // Create semantic label for screen readers
    final semanticLabel = AccessibilityUtils.formatTransactionForScreenReader(
      description: transaction.description,
      amount: transaction.amount,
      isExpense: isExpense,
      category: transaction.category,
      date: transaction.date,
    );

    // Wrap in RepaintBoundary to optimize list scrolling performance
    return RepaintBoundary(
      child: Semantics(
        label: semanticLabel,
        hint: 'Double tap to edit, swipe left to delete',
        button: true,
        child: Dismissible(
      key: ValueKey(transaction.description + transaction.date.toString()),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        // Trigger haptic feedback when swipe threshold is reached
        await MicroInteractions.mediumImpact();
        if (!context.mounted) return false;
        return _showDeleteConfirmation(context);
      },
      onDismissed: (direction) {
        // Trigger heavy haptic feedback on delete
        MicroInteractions.heavyImpact();
        onDelete();
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppDesign.spacingL),
        decoration: BoxDecoration(
          color: AppDesign.getExpenseColor(context),
          borderRadius: BorderRadius.circular(AppDesign.radiusM),
        ),
        child: Semantics(
          label: 'Delete transaction',
          child: const Icon(
            CupertinoIcons.delete,
            color: Colors.white,
            size: AppDesign.iconM,
          ),
        ),
      ),
      child: ElevatedCard(
        elevation: AppDesign.elevationS,
        onTap: onTap,
        padding: const EdgeInsets.all(AppDesign.spacingM),
        child: ExcludeSemantics(
          // Exclude individual elements since we have a parent semantic label
          child: Row(
            children: [
              // Category icon with solid color background
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: categoryColor,
                  borderRadius: BorderRadius.circular(AppDesign.radiusM),
                ),
                child: Icon(
                  _getCategoryIcon(transaction.category, isExpense),
                  color: AppColors.textOnPrimary,
                  size: AppDesign.iconM,
                ),
              ),
            const SizedBox(width: AppDesign.spacingM),
            // Transaction details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.description,
                    style: AppTypography.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppDesign.getTextPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${transaction.category} • ${DateFormat.MMMd().format(transaction.date)}',
                    style: AppTypography.caption.copyWith(
                      color: AppDesign.getTextTertiary(context),
                    ),
                  ),
                ],
              ),
            ),
            // Transaction amount
            Text(
              '\$${NumberFormat("#,##0.00").format(transaction.amount)}',
              style: AppTypography.headingMedium.copyWith(
                color: isExpense 
                    ? AppDesign.getExpenseColor(context)
                    : AppDesign.getIncomeColor(context),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        ),
      ),
      ),
      ),
    );
  }

  /// Shows a confirmation dialog before deleting the transaction
  Future<bool?> _showDeleteConfirmation(BuildContext context) {
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
            onPressed: () {
              Navigator.of(context).pop(false);
            },
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Delete'),
            onPressed: () {
              Navigator.of(context).pop(true);
            },
          ),
        ],
      ),
    );
  }

  /// Gets the appropriate icon for the transaction category
  IconData _getCategoryIcon(String category, bool isExpense) {
    if (isExpense) {
      return expenseCategories[category] ?? CupertinoIcons.square_grid_2x2;
    } else {
      return incomeCategories[category] ?? CupertinoIcons.square_grid_2x2;
    }
  }
}
