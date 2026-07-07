import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'transaction.dart';
import 'common.dart';
import 'package:provider/provider.dart';
import 'transaction_model.dart';
import 'design_system.dart';
import 'recurring_transaction_form.dart';
import 'widgets/modern_text_field.dart';

Future<void> showTransactionForm(
    BuildContext context, TransactionTyp type, Function addTransaction,
    {Transaction? transactionToEdit, Transaction? prefill}) async {
  final transactionModel =
      Provider.of<TransactionModel>(context, listen: false);

  final formKey = GlobalKey<FormState>();
  String description = '';
  final descriptionController = TextEditingController();
  String category = type == TransactionTyp.expense
      ? expenseCategories.keys.first
      : incomeCategories.keys.first;
  double amount = 0.0;
  DateTime selectedDate = DateTime.now();

  final amountController = TextEditingController();
  final amountFocusNode = FocusNode();
  final descriptionFocusNode = FocusNode();

  // Validation state
  String? amountError;
  String? descriptionError;

  // Check if we are editing an existing transaction
  if (transactionToEdit != null) {
    description = transactionToEdit.description;
    category = transactionToEdit.category;
    amount = transactionToEdit.amount;
    selectedDate = transactionToEdit.date;
    amountController.text = amount.toStringAsFixed(2);
    descriptionController.text = description;
  } else if (prefill != null) {
    description = prefill.description;
    category = prefill.category;
    amount = prefill.amount;
    selectedDate = prefill.date;
    if (prefill.amount > 0) {
      amountController.text = amount.toStringAsFixed(2);
    }
    descriptionController.text = description;
  }

  // show transaction form
  await showDialog(
    context: context,
    barrierDismissible: prefill == null,
    builder: (BuildContext dialogContext) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        FocusScope.of(dialogContext).requestFocus(amountFocusNode);
      });

      return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
        final categoryMap = type == TransactionTyp.expense
            ? expenseCategories
            : incomeCategories;

        int initialCategoryIndex = categoryMap.keys.toList().indexOf(category);
        final categoryScrollController =
            FixedExtentScrollController(initialItem: initialCategoryIndex);

        // Validation function
        void validateForm() {
          setState(() {
            // Validate amount
            if (amountController.text.isEmpty) {
              amountError = 'Amount is required';
            } else {
              final parsedAmount = double.tryParse(amountController.text);
              if (parsedAmount == null) {
                amountError = 'Please enter a valid number';
              } else if (parsedAmount <= 0) {
                amountError = 'Amount must be greater than 0';
              } else {
                amountError = null;
                amount = parsedAmount;
              }
            }

            // Validate description (optional but show warning if empty)
            if (descriptionController.text.trim().isEmpty) {
              descriptionError = 'Description is recommended';
            } else {
              descriptionError = null;
              description = descriptionController.text.trim();
            }
          });
        }

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: AppDesign.spacingL,
            vertical: AppDesign.spacingXL,
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            decoration: BoxDecoration(
              color: AppDesign.getCardColor(context),
              borderRadius: BorderRadius.circular(AppDesign.radiusXL),
              boxShadow: AppDesign.shadowXL,
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(AppDesign.spacingM),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Title
                      Text(
                        type == TransactionTyp.expense
                            ? 'Add Expense'
                            : 'Add Income',
                        style: AppTypography.headingMedium.copyWith(
                          color: AppDesign.getTextPrimary(context),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppDesign.spacingM),

                      // Amount Input Field with floating label
                      ModernTextField(
                        controller: amountController,
                        focusNode: amountFocusNode,
                        label: 'Amount',
                        hint: '0.00',
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        prefixIcon: Icons.attach_money,
                        errorText: amountError,
                        onChanged: (value) {
                          // Clear error on change
                          if (amountError != null) {
                            setState(() {
                              amountError = null;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: AppDesign.spacingS),

                      // Description Input Field with floating label
                      ModernTextField(
                        controller: descriptionController,
                        focusNode: descriptionFocusNode,
                        label: 'Description',
                        hint: 'What was this for?',
                        prefixIcon: Icons.description_outlined,
                        errorText: descriptionError,
                        onChanged: (value) {
                          // Clear error on change
                          if (descriptionError != null) {
                            setState(() {
                              descriptionError = null;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: AppDesign.spacingS),

                      // Category Picker Label
                      Padding(
                        padding: const EdgeInsets.only(
                          left: AppDesign.spacingS,
                          bottom: AppDesign.spacingXS,
                        ),
                        child: Text(
                          'Category',
                          style: AppTypography.caption.copyWith(
                            color: AppDesign.getTextSecondary(context),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                      // Category Picker with modern styling
                      Container(
                        height: 90,
                        decoration: BoxDecoration(
                          color: AppDesign.getCardColor(context),
                          borderRadius:
                              BorderRadius.circular(AppDesign.radiusM),
                          border: Border.all(
                            color: AppDesign.getBorderColor(context),
                            width: AppDesign.borderMedium,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius:
                              BorderRadius.circular(AppDesign.radiusM),
                          child: CupertinoPicker(
                            scrollController: categoryScrollController,
                            itemExtent: 32,
                            onSelectedItemChanged: (index) {
                              MicroInteractions.selectionClick();
                              setState(() {
                                category = categoryMap.keys.elementAt(index);
                              });
                            },
                            children: categoryMap.entries.map((entry) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppDesign.spacingM,
                                ),
                                child: Row(
                                  children: <Widget>[
                                    Container(
                                      padding: const EdgeInsets.all(
                                          AppDesign.spacingXS),
                                      decoration: BoxDecoration(
                                        color: type == TransactionTyp.expense
                                            ? AppColors.expense
                                            : AppColors.income,
                                        borderRadius: BorderRadius.circular(
                                          AppDesign.radiusS,
                                        ),
                                      ),
                                      child: Icon(
                                        entry.value,
                                        size: AppDesign.iconS,
                                        color: AppColors.textOnPrimary,
                                      ),
                                    ),
                                    const SizedBox(width: AppDesign.spacingM),
                                    Text(
                                      entry.key,
                                      style: AppTypography.bodyMedium.copyWith(
                                        color:
                                            AppDesign.getTextPrimary(context),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppDesign.spacingM),

                      // Date Picker
                      _DatePickerTile(
                        label: 'Date',
                        value: DateFormat('MMM dd, yyyy').format(selectedDate),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setState(() {
                              selectedDate = picked;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: AppDesign.spacingM),

                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: AppButton.secondary(
                              label: 'Cancel',
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                            ),
                          ),
                          const SizedBox(width: AppDesign.spacingM),
                          Expanded(
                            child: AppButton.primary(
                              label:
                                  transactionToEdit != null ? 'Update' : 'Add',
                              gradient: type == TransactionTyp.expense
                                  ? AppColors.getExpenseGradient(
                                      Theme.of(context).brightness ==
                                          Brightness.dark)
                                  : AppColors.getIncomeGradient(
                                      Theme.of(context).brightness ==
                                          Brightness.dark),
                              onPressed: () {
                                validateForm();

                                // Only proceed if no errors
                                if (amountError == null) {
                                  if (transactionToEdit != null) {
                                    // Update the existing transaction
                                    transactionModel.deleteTransaction(
                                      transactionToEdit,
                                    );
                                    transactionModel.addTransaction(
                                      type,
                                      description.isEmpty
                                          ? 'Transaction'
                                          : description,
                                      amount,
                                      category,
                                      selectedDate,
                                    );
                                    Navigator.of(context).pop();
                                  } else {
                                    // Add a new transaction
                                    final messenger =
                                        ScaffoldMessenger.of(context);
                                    final isDark =
                                        Theme.of(context).brightness ==
                                            Brightness.dark;
                                    transactionModel.addTransaction(
                                      type,
                                      description.isEmpty
                                          ? 'Transaction'
                                          : description,
                                      amount,
                                      category,
                                      selectedDate,
                                    );
                                    Navigator.of(context).pop();
                                    final selectedMonth =
                                        transactionModel.selectedMonth;
                                    if (selectedDate.year !=
                                            selectedMonth.year ||
                                        selectedDate.month !=
                                            selectedMonth.month) {
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Added to ${DateFormat('MMMM').format(selectedDate)}',
                                          ),
                                          backgroundColor:
                                              AppColors.getSuccess(isDark),
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              AppDesign.radiusM,
                                            ),
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                }
                              },
                            ),
                          ),
                        ],
                      ),

                      // Recurring Transaction Link
                      if (prefill == null) ...[
                        const SizedBox(height: AppDesign.spacingM),
                        Center(
                          child: GestureDetector(
                            onTap: () {
                              Navigator.of(context).pop(); // Close current form
                              showRecurringTransactionForm(context, type);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppDesign.spacingM,
                                vertical: AppDesign.spacingS,
                              ),
                              decoration: BoxDecoration(
                                color: AppDesign.getCardColor(context)
                                    .withValues(alpha: 0.5),
                                borderRadius:
                                    BorderRadius.circular(AppDesign.radiusM),
                                border: Border.all(
                                  color: AppDesign.getBorderColor(context),
                                  width: AppDesign.borderMedium,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.repeat,
                                    size: AppDesign.iconS,
                                    color: AppDesign.getTextSecondary(context),
                                  ),
                                  const SizedBox(width: AppDesign.spacingS),
                                  Text(
                                    'Make this recurring',
                                    style: AppTypography.caption.copyWith(
                                      color:
                                          AppDesign.getTextSecondary(context),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      });
    },
  );
}

class _DatePickerTile extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _DatePickerTile({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondary = AppColors.getTextSecondaryColor(isDark);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        MicroInteractions.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.getChipSurface(isDark),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.getCardBorder(isDark)),
        ),
        child: Row(
          children: [
            Icon(Symbols.event_rounded,
                size: 20, weight: 500, color: secondary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTypography.rowSubtitle.copyWith(
                      fontSize: 12,
                      color: secondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: AppTypography.rowTitle.copyWith(
                      color: AppColors.getTextColor(isDark),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Symbols.chevron_right_rounded,
              size: 20,
              weight: 500,
              color: secondary,
            ),
          ],
        ),
      ),
    );
  }
}
