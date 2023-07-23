import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'Transaction.dart';

Future<void> showTransactionForm(
    BuildContext context, TransactionType type, Function addTransaction) async {
  // categories and their icons
  final Map<String, IconData> expenseCategories = {
    'General': CupertinoIcons.square_grid_2x2,
    'Eating Out': CupertinoIcons.drop_triangle,
    'Groceries': CupertinoIcons.cart,
    'Housing': CupertinoIcons.house,
    'Transportation': CupertinoIcons.car_detailed,
    'Travel': CupertinoIcons.airplane,
    'Clothing': CupertinoIcons.bag,
    'Gift': CupertinoIcons.gift,
    'Health': CupertinoIcons.heart,
    'Entertainment': CupertinoIcons.film,
  };

  final Map<String, IconData> incomeCategories = {
    'Salary': CupertinoIcons.money_dollar,
    'Investment': CupertinoIcons.chart_bar,
    'Gift': CupertinoIcons.gift,
    'Other': CupertinoIcons.square_grid_2x2,
  };

  final _formKey = GlobalKey<FormState>();
  String description = '';
  String category = type == TransactionType.EXPENSE
      ? expenseCategories.keys.first
      : incomeCategories.keys.first;
  double amount = 0.0;

  // show transaction form
  await showCupertinoDialog(
    context: context,
    builder: (BuildContext context) {
      return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
        final categoryMap = type == TransactionType.EXPENSE
            ? expenseCategories
            : incomeCategories;

        return CupertinoAlertDialog(
          title: Text(
              type == TransactionType.EXPENSE ? 'Add Expense' : 'Add Income'),
          content: Form(
            key: _formKey,
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 10.0),
                  child: CupertinoTextField(
                    placeholder: 'Description',
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    onChanged: (value) {
                      description = value;
                    },
                  ),
                ),
                SizedBox(
                  height: 150,
                  child: CupertinoPicker(
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
                  placeholder: 'Amount',
                  keyboardType: TextInputType.number,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  onChanged: (value) {
                    amount = double.parse(value);
                  },
                ),
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
              child: const Text('Add'),
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  // add transaction
                  addTransaction(type, description, amount, category);
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      });
    },
  );
}
