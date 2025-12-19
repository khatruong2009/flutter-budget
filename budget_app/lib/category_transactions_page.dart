import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'transaction_model.dart';
import 'transaction.dart';
import 'design_system.dart';
import 'widgets/empty_state.dart';
import 'widgets/modern_transaction_list_item.dart';
import 'utils/platform_utils.dart';

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
    return Consumer<TransactionModel>(
      builder: (context, transactionModel, child) {
        // Filter transactions by category and month
        final categoryTransactions = transactionModel.currentMonthTransactions
            .where((t) => t.category == category && t.type == TransactionTyp.expense)
            .toList();

        // Sort by date (newest first)
        categoryTransactions.sort((a, b) => b.date.compareTo(a.date));

        // Calculate total for this category
        final double total = categoryTransactions.fold(
          0.0,
          (sum, transaction) => sum + transaction.amount,
        );

        return Scaffold(
          appBar: AppBar(
            title: Text(category),
            centerTitle: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(
                CupertinoIcons.back,
                color: AppDesign.getTextPrimary(context),
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          extendBodyBehindAppBar: true,
          body: Container(
            color: AppDesign.getBackgroundColor(context),
            child: SafeArea(
              child: Column(
                children: [
                  // Header with category info
                  Padding(
                    padding: const EdgeInsets.all(AppDesign.spacingL),
                    child: ElevatedCard(
                      padding: const EdgeInsets.all(AppDesign.spacingL),
                      child: Column(
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: categoryColor,
                              borderRadius: BorderRadius.circular(AppDesign.radiusL),
                              boxShadow: AppDesign.shadowM,
                            ),
                            child: Icon(
                              categoryIcon ?? CupertinoIcons.square_grid_2x2,
                              color: AppColors.textOnPrimary,
                              size: AppDesign.iconL,
                            ),
                          ),
                          const SizedBox(height: AppDesign.spacingM),
                          Text(
                            category,
                            style: AppTypography.headingLarge.copyWith(
                              color: AppDesign.getTextPrimary(context),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: AppDesign.spacingXS),
                          Text(
                            DateFormat('MMMM yyyy').format(month),
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppDesign.getTextSecondary(context),
                            ),
                          ),
                          const SizedBox(height: AppDesign.spacingM),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '\$${NumberFormat("#,##0.00", "en_US").format(total)}',
                                style: AppTypography.displaySmall.copyWith(
                                  color: categoryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppDesign.spacingXS),
                          Text(
                            '${categoryTransactions.length} transaction${categoryTransactions.length != 1 ? 's' : ''}',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppDesign.getTextSecondary(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Transaction list
                  Expanded(
                    child: categoryTransactions.isEmpty
                        ? EmptyState(
                            type: EmptyStateType.noData,
                            title: 'No Transactions',
                            message: 'No transactions found in this category for ${DateFormat('MMMM').format(month)}',
                            icon: CupertinoIcons.square_list,
                          )
                        : ListView.separated(
                            physics: PlatformUtils.platformScrollPhysics,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppDesign.spacingM,
                              vertical: AppDesign.spacingS,
                            ),
                            itemCount: categoryTransactions.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: AppDesign.spacingS),
                            itemBuilder: (context, index) {
                              final transaction = categoryTransactions[index];
                              return ModernTransactionListItem(
                                transaction: transaction,
                                onTap: () {
                                  // Optional: Add edit functionality
                                },
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
          ),
        );
      },
    );
  }
}
