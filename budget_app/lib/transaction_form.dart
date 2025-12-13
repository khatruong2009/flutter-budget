import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'transaction.dart';
import 'common.dart';
import 'package:provider/provider.dart';
import 'transaction_model.dart';
import 'design_system.dart';

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
    amountController.text = amount.toString();
    descriptionController.text = description;
  }

  // show transaction form
  await showDialog(
    context: context,
    barrierDismissible: true,
    builder: (BuildContext dialogContext) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        FocusScope.of(dialogContext).requestFocus(amountFocusNode);
      });

      return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
        final categoryMap = type == TransactionTyp.EXPENSE
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
                padding: const EdgeInsets.all(AppDesign.spacingL),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                            // Title
                            Text(
                              type == TransactionTyp.EXPENSE
                                  ? 'Add Expense'
                                  : 'Add Income',
                              style: AppTypography.headingLarge.copyWith(
                                color: AppDesign.getTextPrimary(context),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: AppDesign.spacingL),

                            // Amount Input Field with floating label
                            _ModernTextField(
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
                            const SizedBox(height: AppDesign.spacingM),

                            // Description Input Field with floating label
                            _ModernTextField(
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
                            const SizedBox(height: AppDesign.spacingM),

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
                              height: 150,
                              decoration: BoxDecoration(
                                color: AppDesign.getCardColor(context),
                                borderRadius: BorderRadius.circular(AppDesign.radiusM),
                                border: Border.all(
                                  color: AppDesign.getBorderColor(context),
                                  width: AppDesign.borderMedium,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(AppDesign.radiusM),
                                child: CupertinoPicker(
                                  scrollController: categoryScrollController,
                                  itemExtent: 40,
                                  onSelectedItemChanged: (index) {
                                    setState(() {
                                      category = categoryMap.keys.elementAt(index);
                                    });
                                  },
                                  children: categoryMap.entries.map((entry) {
                                    return Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: <Widget>[
                                        Container(
                                          padding: const EdgeInsets.all(AppDesign.spacingXS),
                                          decoration: BoxDecoration(
                                            color: type == TransactionTyp.EXPENSE
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
                                        const SizedBox(width: AppDesign.spacingS),
                                        Text(
                                          entry.key,
                                          style: AppTypography.bodyMedium.copyWith(
                                            color: AppDesign.getTextPrimary(context),
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                            const SizedBox(height: AppDesign.spacingXL),

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
                                    label: transactionToEdit != null ? 'Update' : 'Add',
                                    gradient: type == TransactionTyp.EXPENSE
                                        ? AppColors.getExpenseGradient(Theme.of(context).brightness == Brightness.dark)
                                        : AppColors.getIncomeGradient(Theme.of(context).brightness == Brightness.dark),
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
                                            description.isEmpty ? 'Transaction' : description,
                                            amount,
                                            category,
                                            selectedDate,
                                          );
                                        } else {
                                          // Add a new transaction
                                          transactionModel.addTransaction(
                                            type,
                                            description.isEmpty ? 'Transaction' : description,
                                            amount,
                                            category,
                                            selectedDate,
                                          );
                                        }
                                        Navigator.of(context).pop();
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
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

/// Modern text field with floating label, focus animations, and error display
class _ModernTextField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String label;
  final String hint;
  final TextInputType? keyboardType;
  final IconData? prefixIcon;
  final String? errorText;
  final ValueChanged<String>? onChanged;

  const _ModernTextField({
    required this.controller,
    required this.focusNode,
    required this.label,
    required this.hint,
    this.keyboardType,
    this.prefixIcon,
    this.errorText,
    this.onChanged,
  });

  @override
  State<_ModernTextField> createState() => _ModernTextFieldState();
}

class _ModernTextFieldState extends State<_ModernTextField>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _labelAnimation;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: AppAnimations.fast,
      vsync: this,
    );

    _labelAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: AppAnimations.easeOut,
      ),
    );

    widget.focusNode.addListener(_onFocusChange);

    // Start animation if field already has text
    if (widget.controller.text.isNotEmpty) {
      _animationController.value = 1.0;
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    _animationController.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {
      _isFocused = widget.focusNode.hasFocus;
      if (_isFocused || widget.controller.text.isNotEmpty) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasError = widget.errorText != null;
    final borderColor = hasError
        ? AppColors.error
        : _isFocused
            ? AppColors.primary
            : AppDesign.getBorderColor(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedBuilder(
          animation: _labelAnimation,
          builder: (context, child) {
            return Container(
              decoration: BoxDecoration(
                color: AppDesign.getCardColor(context),
                borderRadius: BorderRadius.circular(AppDesign.radiusM),
                border: Border.all(
                  color: borderColor,
                  width: _isFocused ? AppDesign.borderThick : AppDesign.borderMedium,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDesign.spacingM,
                  vertical: AppDesign.spacingS,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Floating label
                    if (_labelAnimation.value > 0)
                      Opacity(
                        opacity: _labelAnimation.value,
                        child: Text(
                          widget.label,
                          style: AppTypography.caption.copyWith(
                            color: hasError
                                ? AppColors.error
                                : _isFocused
                                    ? AppColors.primary
                                    : AppDesign.getTextSecondary(context),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    // Input field
                    Row(
                      children: [
                        if (widget.prefixIcon != null) ...[
                          Icon(
                            widget.prefixIcon,
                            size: AppDesign.iconM,
                            color: hasError
                                ? AppColors.error
                                : _isFocused
                                    ? AppColors.primary
                                    : AppDesign.getTextSecondary(context),
                          ),
                          const SizedBox(width: AppDesign.spacingS),
                        ],
                        Expanded(
                          child: TextField(
                            controller: widget.controller,
                            focusNode: widget.focusNode,
                            keyboardType: widget.keyboardType,
                            style: AppTypography.bodyLarge.copyWith(
                              color: AppDesign.getTextPrimary(context),
                            ),
                            decoration: InputDecoration(
                              hintText: widget.hint,
                              hintStyle: AppTypography.bodyLarge.copyWith(
                                color: AppDesign.getTextTertiary(context),
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            onChanged: widget.onChanged,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        // Error message with icon
        if (hasError) ...[
          const SizedBox(height: AppDesign.spacingXS),
          Row(
            children: [
              Icon(
                Icons.error_outline,
                size: AppDesign.iconS,
                color: AppColors.error,
              ),
              const SizedBox(width: AppDesign.spacingXS),
              Expanded(
                child: Text(
                  widget.errorText!,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.error,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
