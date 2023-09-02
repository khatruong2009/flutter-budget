import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'transaction.dart';
import 'common.dart';
import 'package:provider/provider.dart'; // Import to access the model
import 'transaction_model.dart';

Future<void> showTransactionForm(
    BuildContext context, TransactionTyp type, Function addTransaction,
    [Transaction? transactionToEdit]) async {
  final transactionModel =
      Provider.of<TransactionModel>(context, listen: false);

  final formKey = GlobalKey<FormState>();
  String description = '';
  final descriptionController = TextEditingController();
  String category = type == TransactionTyp.EXPENSE
      ? expenseCategories.keys.first
      : incomeCategories.keys.first;
  double amount = 0.0;
  DateTime selectedDate = DateTime.now();

  final amountController = TextEditingController();

  // Check if we are editing an existing transaction
  if (transactionToEdit != null) {
    description = transactionToEdit.description;
    category = transactionToEdit.category;
    amount = transactionToEdit.amount;
    selectedDate = transactionToEdit.date;
    amountController.text = amount.toString();
    descriptionController.text = description;
  }

  // show transaction form
  await showCupertinoDialog(
    context: context,
    builder: (BuildContext context) {
      return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
        final categoryMap = type == TransactionTyp.EXPENSE
            ? expenseCategories
            : incomeCategories;

        int initialCategoryIndex = categoryMap.keys.toList().indexOf(category);
        final categoryScrollController =
            FixedExtentScrollController(initialItem: initialCategoryIndex);

        return CupertinoAlertDialog(
          title: Text(
              type == TransactionTyp.EXPENSE ? 'Add Expense' : 'Add Income'),
          content: Form(
            key: formKey,
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 10.0),
                  child: CupertinoTextField(
                    controller: descriptionController,
                    placeholder: 'Description',
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.light
                          ? Colors.white
                          : Colors.grey[800],
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).brightness == Brightness.light
                          ? Colors.black
                          : Colors.white,
                    ),
                    onChanged: (value) {
                      description = value;
                    },
                  ),
                ),
                SizedBox(
                  height: 150,
                  child: CupertinoPicker(
                    scrollController: categoryScrollController,
                    itemExtent: 30,
                    onSelectedItemChanged: (index) {
                      setState(() {
                        category = categoryMap.keys.elementAt(index);
                      });
                    },
                    children: categoryMap.entries.map((entry) {
                      return Row(
                        children: <Widget>[
                          Icon(entry.value, size: 25),
                          const SizedBox(width: 10),
                          Text(entry.key),
                        ],
                      );
                    }).toList(),
                  ),
                ),
                CupertinoTextField(
                  controller: amountController,
                  placeholder: 'Amount',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.light
                        ? Colors.white
                        : Colors.grey[800],
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context).brightness == Brightness.light
                        ? Colors.black
                        : Colors.white,
                  ),
                  onChanged: (value) {
                    amount = double.tryParse(value) ?? 0.0;
                  },
                ),
                // IMPLEMENT LATER
                // CHOOSE DATE
                // SizedBox(
                //   height: 150,
                //   child: CupertinoDatePicker(
                //     mode: CupertinoDatePickerMode.date,
                //     minimumYear: DateTime.now().year,
                //     maximumYear: DateTime.now().year,
                //     initialDateTime: DateTime.now(),
                //     onDateTimeChanged: (DateTime newDate) {
                //       setState(() {
                //         selectedDate = newDate;
                //       });
                //     },
                //   ),
                // )
              ],
            ),
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            CupertinoDialogAction(
              child: const Text('Add',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () {
                if (amount > 0) {
                  if (transactionToEdit != null) {
                    // Update the existing transaction
                    transactionModel.deleteTransaction(transactionToEdit);
                    transactionModel.addTransaction(
                        type, description, amount, category, selectedDate);
                  } else {
                    // Add a new transaction
                    transactionModel.addTransaction(
                        type, description, amount, category, selectedDate);
                  }
                  Navigator.of(context).pop();
                } else {
                  // Show an error message
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Please enter a valid amount!')),
                  );
                }
              },
            ),
          ],
        );
      });
    },
  );
}
