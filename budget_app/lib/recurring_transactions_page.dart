import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'recurring_transaction.dart';
import 'recurring_transaction_model.dart';
import 'recurring_transaction_form.dart';
import 'transaction.dart';
import 'transaction_model.dart';
import 'transaction_generator.dart';
import 'design_system.dart';
import 'widgets/recurrence_indicator.dart';
import 'common.dart';

/// RecurringTransactionsPage displays and manages all recurring transactions
/// Allows users to view, edit, and delete recurring transaction templates
class RecurringTransactionsPage extends StatelessWidget {
  const RecurringTransactionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesign.getBackgroundColor(context),
      appBar: ModernAppBar(
        title: 'Recurring Transactions',
        showGradient: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _generateDueTransactions(context),
            tooltip: 'Generate Due Transactions',
          ),
        ],
      ),
      body: Consumer<RecurringTransactionModel>(
        builder: (context, model, child) {
          final recurring = model.recurringTransactions;

          if (recurring.isEmpty) {
            return _buildEmptyState(context);
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppDesign.spacingM),
            itemCount: recurring.length,
            separatorBuilder: (context, index) =>
                const SizedBox(height: AppDesign.spacingS),
            itemBuilder: (context, index) {
              return _RecurringTransactionListItem(
                recurring: recurring[index],
                onEdit: () => _editRecurring(context, recurring[index]),
                onDelete: () => _deleteRecurring(context, recurring[index]),
              );
            },
          );
        },
      ),
    );
  }

  /// Build empty state when no recurring transactions exist
  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDesign.spacingXL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: AppDesign.getPrimaryGradient(context),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.repeat,
                size: 60,
                color: AppColors.textOnPrimary,
              ),
            ),
            const SizedBox(height: AppDesign.spacingL),
            Text(
              'No Recurring Transactions',
              style: AppTypography.headingLarge.copyWith(
                color: AppDesign.getTextPrimary(context),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDesign.spacingS),
            Text(
              'Create recurring transactions to automatically\ngenerate expenses and income on a schedule',
              style: AppTypography.bodyMedium.copyWith(
                color: AppDesign.getTextSecondary(context),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Edit an existing recurring transaction
  void _editRecurring(BuildContext context, RecurringTransaction recurring) {
    showRecurringTransactionForm(
      context,
      recurring.type,
      recurring,
    );
  }

  /// Manually trigger generation of due transactions
  Future<void> _generateDueTransactions(BuildContext context) async {
    final transactionModel = Provider.of<TransactionModel>(context, listen: false);
    final recurringModel = Provider.of<RecurringTransactionModel>(context, listen: false);
    
    final generator = TransactionGenerator(
      transactionModel: transactionModel,
      recurringModel: recurringModel,
    );
    
    await generator.generateDueTransactions();
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Due transactions generated and next occurrences updated'),
          backgroundColor: AppColors.income,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDesign.radiusM),
          ),
        ),
      );
    }
  }

  /// Delete a recurring transaction with confirmation
  Future<void> _deleteRecurring(
    BuildContext context,
    RecurringTransaction recurring,
  ) async {
    final confirmed = await _showDeleteConfirmation(context, recurring);
    if (confirmed == true && context.mounted) {
      final model =
          Provider.of<RecurringTransactionModel>(context, listen: false);
      model.deleteRecurringTransaction(recurring.id);

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Recurring transaction deleted'),
          backgroundColor: AppColors.income,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDesign.radiusM),
          ),
        ),
      );
    }
  }

  /// Show confirmation dialog before deleting
  Future<bool?> _showDeleteConfirmation(
    BuildContext context,
    RecurringTransaction recurring,
  ) async {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: AppDesign.getCardColor(context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDesign.radiusL),
          ),
          title: Text(
            'Delete Recurring Transaction?',
            style: AppTypography.headingMedium.copyWith(
              color: AppDesign.getTextPrimary(context),
            ),
          ),
          content: Text(
            'This will stop generating future transactions for "${recurring.description}". '
            'Previously generated transactions will not be affected.',
            style: AppTypography.bodyMedium.copyWith(
              color: AppDesign.getTextSecondary(context),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                'Cancel',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppDesign.getTextSecondary(context),
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                'Delete',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// List item widget for displaying a single recurring transaction
class _RecurringTransactionListItem extends StatelessWidget {
  final RecurringTransaction recurring;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _RecurringTransactionListItem({
    required this.recurring,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isExpense = recurring.type == TransactionTyp.expense;
    final categoryColor = isExpense
        ? AppDesign.getExpenseColor(context)
        : AppDesign.getIncomeColor(context);

    return ElevatedCard(
      elevation: AppDesign.elevationS,
      padding: const EdgeInsets.all(AppDesign.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with icon, description, and amount
          Row(
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
                  _getCategoryIcon(recurring.category, isExpense),
                  color: AppColors.textOnPrimary,
                  size: AppDesign.iconM,
                ),
              ),
              const SizedBox(width: AppDesign.spacingM),
              // Description and recurrence indicator
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            recurring.description,
                            style: AppTypography.bodyLarge.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppDesign.getTextPrimary(context),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const RecurrenceIndicator(size: 16.0),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      recurring.category,
                      style: AppTypography.caption.copyWith(
                        color: AppDesign.getTextTertiary(context),
                      ),
                    ),
                  ],
                ),
              ),
              // Amount
              Text(
                '\$${NumberFormat("#,##0.00", "en_US").format(recurring.amount)}',
                style: AppTypography.headingMedium.copyWith(
                  color: categoryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDesign.spacingM),
          // Divider
          Container(
            height: 1,
            color: AppDesign.getBorderColor(context),
          ),
          const SizedBox(height: AppDesign.spacingM),
          // Details row with pattern and next occurrence
          Row(
            children: [
              Expanded(
                child: _buildDetailItem(
                  context,
                  icon: Icons.repeat,
                  label: 'Pattern',
                  value: _getPatternDisplayName(recurring.pattern),
                ),
              ),
              const SizedBox(width: AppDesign.spacingM),
              Expanded(
                child: _buildDetailItem(
                  context,
                  icon: Icons.calendar_today,
                  label: 'Next Occurrence',
                  value: DateFormat('MMM dd, yyyy').format(recurring.nextOccurrence),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDesign.spacingM),
          // Action buttons
          Row(
            children: [
              Expanded(
                child: AppButton.secondary(
                  label: 'Edit',
                  icon: Icons.edit,
                  onPressed: onEdit,
                  size: AppButtonSize.small,
                ),
              ),
              const SizedBox(width: AppDesign.spacingS),
              Expanded(
                child: AppButton(
                  label: 'Delete',
                  icon: Icons.delete_outline,
                  onPressed: onDelete,
                  variant: AppButtonVariant.secondary,
                  size: AppButtonSize.small,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build a detail item with icon, label, and value
  Widget _buildDetailItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: AppDesign.iconS,
              color: AppDesign.getTextSecondary(context),
            ),
            const SizedBox(width: AppDesign.spacingXS),
            Text(
              label,
              style: AppTypography.caption.copyWith(
                color: AppDesign.getTextSecondary(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDesign.spacingXXS),
        Text(
          value,
          style: AppTypography.bodySmall.copyWith(
            color: AppDesign.getTextPrimary(context),
          ),
        ),
      ],
    );
  }

  /// Get category icon based on category name and type
  IconData _getCategoryIcon(String category, bool isExpense) {
    if (isExpense) {
      return expenseCategories[category] ?? Icons.shopping_bag;
    } else {
      return incomeCategories[category] ?? Icons.attach_money;
    }
  }

  /// Get display name for recurrence pattern
  String _getPatternDisplayName(RecurrencePattern pattern) {
    switch (pattern) {
      case RecurrencePattern.weekly:
        return 'Weekly';
      case RecurrencePattern.biweekly:
        return 'Bi-weekly';
      case RecurrencePattern.monthly:
        return 'Monthly';
    }
  }
}
