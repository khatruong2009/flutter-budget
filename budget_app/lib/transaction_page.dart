import 'package:budget_app/transaction_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'transaction.dart';
import 'package:provider/provider.dart';
import 'transaction_model.dart';
import 'design_system.dart';
import 'widgets/modern_transaction_list_item.dart';
import 'widgets/empty_state.dart';
import 'utils/platform_utils.dart';

class TransactionPage extends StatelessWidget {
  const TransactionPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<TransactionModel>(
      builder: (context, transactionModel, child) {
        final sortedTransactions =
            List.from(transactionModel.currentMonthTransactions)
              ..sort((a, b) => b.date.compareTo(a.date));
        
        return Scaffold(
          appBar: AppBar(
            title: Text(
              'Transactions',
              style: AppTypography.headingMedium.copyWith(
                color: AppDesign.getTextPrimary(context),
              ),
            ),
            centerTitle: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
          extendBodyBehindAppBar: false,
          backgroundColor: AppDesign.getBackgroundColor(context),
          body: sortedTransactions.isEmpty
                ? EmptyState.noData(
                    title: 'No Transactions Yet',
                    message: 'Start tracking your finances by adding your first transaction',
                    actionLabel: 'Add Transaction',
                    onAction: () {
                      showTransactionForm(
                        context,
                        TransactionTyp.EXPENSE,
                        transactionModel.addTransaction,
                      );
                    },
                    icon: CupertinoIcons.money_dollar_circle,
                  )
                : ListView.separated(
                    physics: PlatformUtils.platformScrollPhysics,
                    padding: const EdgeInsets.all(AppDesign.spacingM),
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: AppDesign.spacingS),
                    itemCount: sortedTransactions.length,
                    // Optimize list performance
                    addAutomaticKeepAlives: false,
                    addRepaintBoundaries: true,
                    itemBuilder: (context, index) {
                      final transaction = sortedTransactions[index];
                      return ModernTransactionListItem(
                        transaction: transaction,
                        onTap: () {
                          showTransactionForm(
                            context,
                            transaction.type,
                            transactionModel.addTransaction,
                            transaction,
                          );
                        },
                        onDelete: () {
                          transactionModel.deleteTransaction(transaction);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Transaction deleted'),
                              backgroundColor: AppColors.expense,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppDesign.radiusM),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
        );
      },
    );
  }
}
