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
import 'widgets/month_selector.dart';

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
        final isDark = Theme.of(context).brightness == Brightness.dark;
        List<DateTime> availableMonths = transactionModel.getAvailableMonths();

        // Set initial selected month to most recent month if not set
        if (selectedMonth == null && availableMonths.isNotEmpty) {
          selectedMonth = availableMonths.first;
        }

        return Scaffold(
          backgroundColor: AppColors.getBackground(isDark),
          appBar: AppBar(
            title: Text(
              'Transactions',
              style: AppTypography.sectionHeader.copyWith(
                color: AppColors.getTextColor(isDark),
              ),
            ),
            centerTitle: true,
            backgroundColor: AppColors.getBackground(isDark),
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            iconTheme: IconThemeData(color: AppColors.getTextColor(isDark)),
          ),
          extendBodyBehindAppBar: false,
          body: Container(
            color: AppColors.getBackground(isDark),
            child: availableMonths.isEmpty
                ? EmptyState.noData(
                    title: 'No Transactions Yet',
                    message:
                        'Start tracking your finances by adding your first transaction',
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
                      // Month selector
                      MonthSelector(
                        selectedMonth: selectedMonth,
                        availableMonths: availableMonths,
                        onMonthChanged: (DateTime newMonth) {
                          setState(() {
                            selectedMonth = newMonth;
                          });
                        },
                      ),

                      // Monthly summary card
                      if (selectedMonth != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppDesign.spacingM,
                          ),
                          child: _MonthlySummaryCard(
                            summary: transactionModel
                                .getMonthlySummary(selectedMonth!),
                          ),
                        ),

                      const SizedBox(height: AppDesign.spacingM),

                      // Transaction list with grouped headers
                      Expanded(
                        child: selectedMonth == null
                            ? Center(
                                child: Text(
                                  'Select a month',
                                  style: AppTypography.rowTitle.copyWith(
                                    fontSize: 16,
                                    color:
                                        AppColors.getTextSecondaryColor(isDark),
                                  ),
                                ),
                              )
                            : _buildGroupedTransactionList(
                                transactionModel,
                                transactionModel
                                    .getTransactionsForMonth(selectedMonth!),
                              ),
                      ),
                    ],
                  ),
          ),
        );
      },
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
                              transactionToEdit: transaction,
                            );
                          },
                          onDelete: () {
                            transactionModel.deleteTransaction(transaction);
                            final isDark =
                                Theme.of(context).brightness == Brightness.dark;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Transaction deleted'),
                                backgroundColor: AppColors.getDanger(isDark),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(AppDesign.radiusM),
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
        // Bottom padding clears the floating dock.
        SliverPadding(
          padding: EdgeInsets.only(
            bottom: DockMetrics.contentBottomPadding(context),
          ),
        ),
      ],
    );
  }
}

/// Monthly income / expenses / net summary styled to the dark token system.
class _MonthlySummaryCard extends StatelessWidget {
  final Map<String, double> summary;

  const _MonthlySummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final income = summary['income'] ?? 0.0;
    final expenses = summary['expenses'] ?? 0.0;
    final net = summary['net'] ?? 0.0;

    return GlowCard(
      padding: const EdgeInsets.all(AppDesign.spacingM),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _summaryItem(
                  'Income', income, AppColors.getIncome(isDark), isDark),
              _summaryItem(
                  'Expenses', expenses, AppColors.getDanger(isDark), isDark),
            ],
          ),
          Divider(
            height: AppDesign.spacingL,
            color: AppColors.getHairline(isDark),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Net Cash Flow',
                  style: AppTypography.rowTitle.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.getTextColor(isDark),
                  ),
                ),
              ),
              const SizedBox(width: AppDesign.spacingS),
              Flexible(
                child: Text(
                  '\$${NumberFormat("#,##0.00", "en_US").format(net)}',
                  style: AppTypography.amount.copyWith(
                    fontSize: 20,
                    color: net >= 0
                        ? AppColors.getIncome(isDark)
                        : AppColors.getDanger(isDark),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, double amount, Color color, bool isDark) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.rowSubtitle.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.getTextSecondaryColor(isDark),
            ),
          ),
          const SizedBox(height: AppDesign.spacingXS),
          Text(
            '\$${NumberFormat("#,##0.00", "en_US").format(amount)}',
            style: AppTypography.amount.copyWith(
              fontSize: 20,
              color: color,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Must fill the declared min/maxExtent exactly — a shorter child makes
    // the pinned sliver's geometry invalid and blanks the whole list.
    return Container(
      height: maxExtent,
      padding: const EdgeInsets.symmetric(horizontal: AppDesign.spacingM),
      color: AppColors.getBackground(isDark),
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDesign.spacingM,
              vertical: AppDesign.spacingXS,
            ),
            decoration: BoxDecoration(
              color: AppColors.getChipSurface(isDark),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: AppColors.getCardBorder(isDark),
              ),
            ),
            child: Text(
              dateKey,
              style: AppTypography.monoLabel.copyWith(
                color: AppColors.getTextSecondaryColor(isDark),
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
