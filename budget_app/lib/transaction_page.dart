import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'transaction_model.dart';
import 'transaction.dart';
import 'transaction_form.dart';
import 'design_system.dart';
import 'widgets/modern_transaction_list_item.dart';
import 'widgets/empty_state.dart';
import 'utils/platform_utils.dart';

class TransactionPage extends StatefulWidget {
  const TransactionPage({Key? key}) : super(key: key);

  @override
  State<TransactionPage> createState() => _TransactionPageState();
}

class _TransactionPageState extends State<TransactionPage> {
  DateTime? selectedMonth;

  @override
  Widget build(BuildContext context) {
    return Consumer<TransactionModel>(
      builder: (context, transactionModel, child) {
        List<DateTime> availableMonths = transactionModel.getAvailableMonths();

        // Set initial selected month to most recent month if not set
        if (selectedMonth == null && availableMonths.isNotEmpty) {
          selectedMonth = availableMonths.first;
        }

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
          body: Container(
            color: AppDesign.getBackgroundColor(context),
            child: availableMonths.isEmpty
                ? EmptyState.noData(
                    title: 'No Transactions Yet',
                    message: 'Start tracking your finances by adding your first transaction',
                    actionLabel: 'Add Transaction',
                    onAction: () {
                      showTransactionForm(
                        context,
                        TransactionTyp.expense,
                        transactionModel.addTransaction,
                      );
                    },
                    icon: CupertinoIcons.money_dollar_circle,
                  )
                : Column(
                    children: [
                      // Month selector dropdown
                      Padding(
                        padding: const EdgeInsets.all(AppDesign.spacingM),
                        child: ElevatedCard(
                          elevation: AppDesign.elevationS,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppDesign.spacingM,
                            vertical: AppDesign.spacingXS,
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<DateTime>(
                              isExpanded: true,
                              value: selectedMonth,
                              dropdownColor: Theme.of(context).brightness == Brightness.dark
                                  ? const Color(0xFF1E1E1E)
                                  : Colors.white,
                              icon: Icon(
                                CupertinoIcons.chevron_down,
                                color: AppDesign.getTextPrimary(context),
                              ),
                              items: availableMonths.map((DateTime month) {
                                return DropdownMenuItem<DateTime>(
                                  value: month,
                                  child: Text(
                                    DateFormat.yMMMM().format(month),
                                    style: AppTypography.bodyLarge.copyWith(
                                      color: AppDesign.getTextPrimary(context),
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (DateTime? newValue) {
                                setState(() {
                                  selectedMonth = newValue;
                                });
                              },
                            ),
                          ),
                        ),
                      ),

                      // Monthly summary card
                      if (selectedMonth != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppDesign.spacingM,
                          ),
                          child: ElevatedCard(
                            elevation: AppDesign.elevationS,
                            child: _buildMonthlySummary(
                              transactionModel.getMonthlySummary(selectedMonth!),
                            ),
                          ),
                        ),

                      const SizedBox(height: AppDesign.spacingM),

                      // Transaction list with grouped headers
                      Expanded(
                        child: selectedMonth == null
                            ? Center(
                                child: Text(
                                  'Select a month',
                                  style: AppTypography.bodyLarge.copyWith(
                                    color: AppDesign.getTextSecondary(context),
                                  ),
                                ),
                              )
                            : _buildGroupedTransactionList(
                                transactionModel,
                                transactionModel.getTransactionsForMonth(selectedMonth!),
                              ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _buildMonthlySummary(Map<String, double> summary) {
    double income = summary['income'] ?? 0.0;
    double expenses = summary['expenses'] ?? 0.0;
    double net = summary['net'] ?? 0.0;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSummaryItem('Income', income, AppColors.income),
            _buildSummaryItem('Expenses', expenses, AppColors.expense),
          ],
        ),
        Divider(
          height: AppDesign.spacingL,
          color: AppDesign.getTextTertiary(context).withValues(alpha: 0.3),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Net Cash Flow',
                style: AppTypography.bodyLarge.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppDesign.getTextPrimary(context),
                ),
              ),
            ),
            const SizedBox(width: AppDesign.spacingS),
            Flexible(
              child: Text(
                '\$${NumberFormat("#,##0.00", "en_US").format(net)}',
                style: AppTypography.headingMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: net >= 0 ? AppColors.income : AppColors.expense,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryItem(String label, double amount, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.bodyMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: AppDesign.getTextSecondary(context),
            ),
          ),
          const SizedBox(height: AppDesign.spacingXS),
          Text(
            '\$${NumberFormat("#,##0.00", "en_US").format(amount)}',
            style: AppTypography.headingMedium.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// Builds a grouped transaction list with sticky date headers
  Widget _buildGroupedTransactionList(
    TransactionModel transactionModel,
    List<Transaction> transactions,
  ) {
    if (transactions.isEmpty) {
      return EmptyState.noData(
        title: 'No Transactions',
        message: 'No transactions for this month',
        icon: CupertinoIcons.tray,
      );
    }

    // Sort transactions by date (newest first)
    final sortedTransactions = List<Transaction>.from(transactions)
      ..sort((a, b) => b.date.compareTo(a.date));

    // Group transactions by date
    final Map<String, List<Transaction>> groupedTransactions = {};
    for (var transaction in sortedTransactions) {
      final dateKey = DateFormat.yMMMd().format(transaction.date);
      if (!groupedTransactions.containsKey(dateKey)) {
        groupedTransactions[dateKey] = [];
      }
      groupedTransactions[dateKey]!.add(transaction);
    }

    return CustomScrollView(
      physics: PlatformUtils.platformScrollPhysics,
      slivers: [
        // Build sliver list for each date group
        ...groupedTransactions.entries.map((entry) {
          final dateKey = entry.key;
          final dateTransactions = entry.value;

          return SliverMainAxisGroup(
            slivers: [
              // Sticky date header
              SliverPersistentHeader(
                pinned: true,
                delegate: _DateHeaderDelegate(
                  dateKey: dateKey,
                  context: context,
                ),
              ),
              // Transaction items for this date
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDesign.spacingM,
                ),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final transaction = dateTransactions[index];
                      return Padding(
                        padding: const EdgeInsets.only(
                          bottom: AppDesign.spacingS,
                        ),
                        child: ModernTransactionListItem(
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
                        ),
                      );
                    },
                    childCount: dateTransactions.length,
                    // Optimize list performance
                    addAutomaticKeepAlives: false,
                    addRepaintBoundaries: true,
                  ),
                ),
              ),
            ],
          );
        }),
        // Bottom padding
        const SliverPadding(
          padding: EdgeInsets.only(bottom: AppDesign.spacingL),
        ),
      ],
    );
  }
}

/// Delegate for sticky date headers in the transaction list
class _DateHeaderDelegate extends SliverPersistentHeaderDelegate {
  final String dateKey;
  final BuildContext context;

  _DateHeaderDelegate({
    required this.dateKey,
    required this.context,
  });

  @override
  double get minExtent => 48.0;

  @override
  double get maxExtent => 48.0;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDesign.spacingM,
        vertical: AppDesign.spacingS,
      ),
      color: AppDesign.getBackgroundColor(context),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDesign.spacingM,
              vertical: AppDesign.spacingXS,
            ),
            decoration: BoxDecoration(
              color: AppDesign.getSurfaceColor(context),
              borderRadius: BorderRadius.circular(AppDesign.radiusS),
              border: Border.all(
                color: AppDesign.getBorderColor(context),
                width: AppDesign.borderThin,
              ),
            ),
            child: Text(
              dateKey,
              style: AppTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: AppDesign.getTextPrimary(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _DateHeaderDelegate oldDelegate) {
    return dateKey != oldDelegate.dateKey;
  }
}
