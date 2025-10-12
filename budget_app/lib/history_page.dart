import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'transaction_model.dart';
import 'transaction.dart';
import 'transaction_form.dart';
import 'common.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({Key? key}) : super(key: key);

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  DateTime? selectedMonth;

  @override
  Widget build(BuildContext context) {
    return Consumer<TransactionModel>(
      builder: (context, transactionModel, child) {
        List<DateTime> availableMonths = transactionModel.getAvailableMonths();

        // Set initial selected month if not set
        if (selectedMonth == null && availableMonths.isNotEmpty) {
          selectedMonth = availableMonths.first;
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'Transaction History',
              textAlign: TextAlign.center,
            ),
            centerTitle: true,
          ),
          body: availableMonths.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        CupertinoIcons.doc_text_search,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No transaction history yet',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Start adding transactions to see your history',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Month selector dropdown
                    Container(
                      padding: const EdgeInsets.all(16.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<DateTime>(
                            isExpanded: true,
                            value: selectedMonth,
                            items: availableMonths.map((DateTime month) {
                              return DropdownMenuItem<DateTime>(
                                value: month,
                                child: Text(
                                  DateFormat.yMMMM().format(month),
                                  style: const TextStyle(fontSize: 16),
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
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Card(
                          elevation: 4,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: _buildMonthlySummary(
                              transactionModel
                                  .getMonthlySummary(selectedMonth!),
                            ),
                          ),
                        ),
                      ),

                    const SizedBox(height: 16),

                    // Transaction list
                    Expanded(
                      child: selectedMonth == null
                          ? const Center(child: Text('Select a month'))
                          : _buildTransactionList(
                              transactionModel,
                              transactionModel
                                  .getTransactionsForMonth(selectedMonth!),
                            ),
                    ),
                  ],
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
            _buildSummaryItem('Income', income, Colors.green),
            _buildSummaryItem('Expenses', expenses, Colors.red),
          ],
        ),
        const Divider(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Net Cash Flow',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Text(
              '\$${NumberFormat("#,##0.00", "en_US").format(net)}',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: net >= 0 ? Colors.green : Colors.red,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryItem(String label, double amount, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '\$${NumberFormat("#,##0.00", "en_US").format(amount)}',
          style: TextStyle(
            fontSize: 18,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionList(
    TransactionModel transactionModel,
    List<Transaction> transactions,
  ) {
    if (transactions.isEmpty) {
      return Center(
        child: Text(
          'No transactions for this month',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey.shade600,
          ),
        ),
      );
    }

    final sortedTransactions = List.from(transactions)
      ..sort((a, b) => b.date.compareTo(a.date));

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      separatorBuilder: (context, index) =>
          Divider(color: Colors.grey.shade300),
      itemCount: sortedTransactions.length,
      itemBuilder: (context, index) {
        final transaction = sortedTransactions[index];
        return Dismissible(
          key: ValueKey(transaction.description + transaction.date.toString()),
          direction: DismissDirection.endToStart,
          confirmDismiss: (direction) => showDialog(
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
                  child: const Text(
                    'Delete',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop(true);
                  },
                ),
              ],
            ),
          ),
          onDismissed: (direction) {
            transactionModel.deleteTransaction(transaction);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Transaction deleted'),
              ),
            );
          },
          background: Container(
            color: Colors.red,
            padding: const EdgeInsets.only(right: 20),
            alignment: Alignment.centerRight,
            child: const Icon(
              CupertinoIcons.delete,
              color: Colors.white,
            ),
          ),
          child: ListTile(
            onTap: () {
              showTransactionForm(
                context,
                transaction.type,
                transactionModel.addTransaction,
                transaction,
              );
            },
            contentPadding: const EdgeInsets.symmetric(
              vertical: 10.0,
              horizontal: 15.0,
            ),
            title: Text(
              transaction.description,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              'Category: ${transaction.category}\nDate: ${DateFormat.yMMMd().format(transaction.date)}',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: Text(
              '\$${NumberFormat("#,##0.00", "en_US").format(transaction.amount)}',
              style: TextStyle(
                fontSize: 16,
                color: transaction.type == TransactionTyp.EXPENSE
                    ? (Theme.of(context).brightness == Brightness.light
                        ? Colors.red
                        : Colors.red[300])
                    : (Theme.of(context).brightness == Brightness.light
                        ? Colors.green
                        : Colors.green[300]),
              ),
            ),
            leading: Icon(
              transaction.type == TransactionTyp.EXPENSE
                  ? expenseCategories[transaction.category] ??
                      CupertinoIcons.down_arrow
                  : incomeCategories[transaction.category] ??
                      CupertinoIcons.up_arrow,
              color: transaction.type == TransactionTyp.EXPENSE
                  ? Colors.red
                  : Colors.green,
            ),
          ),
        );
      },
    );
  }
}
