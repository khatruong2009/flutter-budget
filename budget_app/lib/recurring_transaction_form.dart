import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'transaction.dart';
import 'recurring_transaction.dart';
import 'recurring_transaction_model.dart';
import 'common.dart';
import 'design_system.dart';

/// Show the recurring transaction form dialog
Future<void> showRecurringTransactionForm(
  BuildContext context,
  TransactionTyp type, [
  RecurringTransaction? templateToEdit,
]) async {
  final recurringModel =
      Provider.of<RecurringTransactionModel>(context, listen: false);

  // Form state
  String description = '';
  final descriptionController = TextEditingController();
  String category = type == TransactionTyp.expense
      ? expenseCategories.keys.first
      : incomeCategories.keys.first;
  double amount = 0.0;
  final amountController = TextEditingController();
  RecurrencePattern pattern = RecurrencePattern.monthly;
  DateTime startDate = DateTime.now();
  int dayOfMonth = DateTime.now().day;
  int dayOfWeek = DateTime.now().weekday; // 1-7 (Monday-Sunday)

  // Focus nodes
  final amountFocusNode = FocusNode();
  final descriptionFocusNode = FocusNode();

  // Validation state
  String? amountError;
  String? descriptionError;
  String? startDateError;

  // Check if we are editing an existing recurring transaction
  if (templateToEdit != null) {
    description = templateToEdit.description;
    category = templateToEdit.category;
    amount = templateToEdit.amount;
    pattern = templateToEdit.pattern;
    startDate = templateToEdit.startDate;
    dayOfMonth = templateToEdit.dayOfMonth ?? DateTime.now().day;
    dayOfWeek = templateToEdit.dayOfWeek ?? DateTime.now().weekday;
    amountController.text = amount.toStringAsFixed(2);
    descriptionController.text = description;
  }

  await showDialog(
    context: context,
    barrierDismissible: true,
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

          // Calculate preview dates
          List<DateTime> previewDates = _calculatePreviewDates(
            pattern,
            startDate,
            dayOfMonth,
            dayOfWeek,
          );

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

              // Validate description
              if (descriptionController.text.trim().isEmpty) {
                descriptionError = 'Description is required';
              } else {
                descriptionError = null;
                description = descriptionController.text.trim();
              }

              // Validate start date (not more than 1 year in past)
              final oneYearAgo = DateTime.now().subtract(const Duration(days: 365));
              if (startDate.isBefore(oneYearAgo)) {
                startDateError = 'Start date cannot be more than 1 year in the past';
              } else {
                startDateError = null;
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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Title
                      Text(
                        templateToEdit != null
                            ? 'Edit Recurring ${type == TransactionTyp.expense ? 'Expense' : 'Income'}'
                            : 'Add Recurring ${type == TransactionTyp.expense ? 'Expense' : 'Income'}',
                        style: AppTypography.headingMedium.copyWith(
                          color: AppDesign.getTextPrimary(context),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppDesign.spacingM),

                      // Amount Input Field
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
                          if (amountError != null) {
                            setState(() {
                              amountError = null;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: AppDesign.spacingS),

                      // Description Input Field
                      _ModernTextField(
                        controller: descriptionController,
                        focusNode: descriptionFocusNode,
                        label: 'Description',
                        hint: 'What is this for?',
                        prefixIcon: Icons.description_outlined,
                        errorText: descriptionError,
                        onChanged: (value) {
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

                      // Category Picker
                      Container(
                        height: 90,
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
                            itemExtent: 32,
                            onSelectedItemChanged: (index) {
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
                                      padding: const EdgeInsets.all(AppDesign.spacingXS),
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
                                        color: AppDesign.getTextPrimary(context),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppDesign.spacingS),

                      // Recurrence Pattern Picker Label
                      Padding(
                        padding: const EdgeInsets.only(
                          left: AppDesign.spacingS,
                          bottom: AppDesign.spacingXS,
                        ),
                        child: Text(
                          'Recurrence Pattern',
                          style: AppTypography.caption.copyWith(
                            color: AppDesign.getTextSecondary(context),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                      // Recurrence Pattern Picker
                      Container(
                        height: 90,
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
                            scrollController: FixedExtentScrollController(
                              initialItem: RecurrencePattern.values.indexOf(pattern),
                            ),
                            itemExtent: 32,
                            onSelectedItemChanged: (index) {
                              setState(() {
                                pattern = RecurrencePattern.values[index];
                                // Update preview dates when pattern changes
                                previewDates = _calculatePreviewDates(
                                  pattern,
                                  startDate,
                                  dayOfMonth,
                                  dayOfWeek,
                                );
                              });
                            },
                            children: RecurrencePattern.values.map((p) {
                              return Center(
                                child: Text(
                                  _getPatternDisplayName(p),
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: AppDesign.getTextPrimary(context),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppDesign.spacingS),

                      // Conditional Day Selection
                      if (pattern == RecurrencePattern.monthly) ...[
                        // Day of Month Picker
                        Padding(
                          padding: const EdgeInsets.only(
                            left: AppDesign.spacingS,
                            bottom: AppDesign.spacingXS,
                          ),
                          child: Text(
                            'Day of Month',
                            style: AppTypography.caption.copyWith(
                              color: AppDesign.getTextSecondary(context),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Container(
                          height: 90,
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
                              scrollController: FixedExtentScrollController(
                                initialItem: dayOfMonth - 1,
                              ),
                              itemExtent: 32,
                              onSelectedItemChanged: (index) {
                                setState(() {
                                  dayOfMonth = index + 1;
                                  // Update preview dates when day changes
                                  previewDates = _calculatePreviewDates(
                                    pattern,
                                    startDate,
                                    dayOfMonth,
                                    dayOfWeek,
                                  );
                                });
                              },
                              children: List.generate(31, (index) {
                                return Center(
                                  child: Text(
                                    '${index + 1}',
                                    style: AppTypography.bodyMedium.copyWith(
                                      color: AppDesign.getTextPrimary(context),
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppDesign.spacingS),
                      ] else ...[
                        // Day of Week Picker (for weekly/biweekly)
                        Padding(
                          padding: const EdgeInsets.only(
                            left: AppDesign.spacingS,
                            bottom: AppDesign.spacingXS,
                          ),
                          child: Text(
                            'Day of Week',
                            style: AppTypography.caption.copyWith(
                              color: AppDesign.getTextSecondary(context),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Container(
                          height: 90,
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
                              scrollController: FixedExtentScrollController(
                                initialItem: dayOfWeek - 1,
                              ),
                              itemExtent: 32,
                              onSelectedItemChanged: (index) {
                                setState(() {
                                  dayOfWeek = index + 1;
                                  // Update preview dates when day changes
                                  previewDates = _calculatePreviewDates(
                                    pattern,
                                    startDate,
                                    dayOfMonth,
                                    dayOfWeek,
                                  );
                                });
                              },
                              children: _getDaysOfWeek().map((day) {
                                return Center(
                                  child: Text(
                                    day,
                                    style: AppTypography.bodyMedium.copyWith(
                                      color: AppDesign.getTextPrimary(context),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppDesign.spacingS),
                      ],

                      // Start Date Picker
                      Padding(
                        padding: const EdgeInsets.only(
                          left: AppDesign.spacingS,
                          bottom: AppDesign.spacingXS,
                        ),
                        child: Text(
                          'Start Date',
                          style: AppTypography.caption.copyWith(
                            color: startDateError != null
                                ? AppColors.error
                                : AppDesign.getTextSecondary(context),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: startDate,
                            firstDate: DateTime.now().subtract(const Duration(days: 365)),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: ColorScheme.light(
                                    primary: type == TransactionTyp.expense
                                        ? AppColors.expense
                                        : AppColors.income,
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (picked != null) {
                            setState(() {
                              startDate = picked;
                              // Clear error if date is valid
                              final oneYearAgo = DateTime.now()
                                  .subtract(const Duration(days: 365));
                              if (!startDate.isBefore(oneYearAgo)) {
                                startDateError = null;
                              }
                              // Update preview dates when start date changes
                              previewDates = _calculatePreviewDates(
                                pattern,
                                startDate,
                                dayOfMonth,
                                dayOfWeek,
                              );
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(AppDesign.spacingM),
                          decoration: BoxDecoration(
                            color: AppDesign.getCardColor(context),
                            borderRadius: BorderRadius.circular(AppDesign.radiusM),
                            border: Border.all(
                              color: startDateError != null
                                  ? AppColors.error
                                  : AppDesign.getBorderColor(context),
                              width: AppDesign.borderMedium,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: AppDesign.iconM,
                                color: startDateError != null
                                    ? AppColors.error
                                    : AppDesign.getTextSecondary(context),
                              ),
                              const SizedBox(width: AppDesign.spacingM),
                              Text(
                                DateFormat('MMM dd, yyyy').format(startDate),
                                style: AppTypography.bodyLarge.copyWith(
                                  color: AppDesign.getTextPrimary(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (startDateError != null) ...[
                        const SizedBox(height: AppDesign.spacingXS),
                        Row(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              size: AppDesign.iconS,
                              color: AppColors.error,
                            ),
                            const SizedBox(width: AppDesign.spacingXS),
                            Expanded(
                              child: Text(
                                startDateError!,
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.error,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: AppDesign.spacingM),

                      // Preview Section
                      Container(
                        padding: const EdgeInsets.all(AppDesign.spacingM),
                        decoration: BoxDecoration(
                          color: AppDesign.getCardColor(context).withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(AppDesign.radiusM),
                          border: Border.all(
                            color: AppDesign.getBorderColor(context),
                            width: AppDesign.borderMedium,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.preview,
                                  size: AppDesign.iconS,
                                  color: AppDesign.getTextSecondary(context),
                                ),
                                const SizedBox(width: AppDesign.spacingS),
                                Text(
                                  'Next 3 Occurrences',
                                  style: AppTypography.caption.copyWith(
                                    color: AppDesign.getTextSecondary(context),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppDesign.spacingS),
                            ...previewDates.map((date) {
                              return Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppDesign.spacingXS,
                                ),
                                child: Text(
                                  DateFormat('EEEE, MMM dd, yyyy').format(date),
                                  style: AppTypography.bodySmall.copyWith(
                                    color: AppDesign.getTextPrimary(context),
                                  ),
                                ),
                              );
                            }).toList(),
                          ],
                        ),
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
                              label: templateToEdit != null ? 'Update' : 'Save',
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
                                if (amountError == null &&
                                    descriptionError == null &&
                                    startDateError == null) {
                                  final recurring = RecurringTransaction(
                                    id: templateToEdit?.id,
                                    type: type,
                                    description: description,
                                    amount: amount,
                                    category: category,
                                    pattern: pattern,
                                    startDate: startDate,
                                    dayOfMonth: pattern == RecurrencePattern.monthly
                                        ? dayOfMonth
                                        : null,
                                    dayOfWeek: pattern != RecurrencePattern.monthly
                                        ? dayOfWeek
                                        : null,
                                  );

                                  if (templateToEdit != null) {
                                    recurringModel.updateRecurringTransaction(
                                      templateToEdit.id,
                                      recurring,
                                    );
                                  } else {
                                    recurringModel.addRecurringTransaction(recurring);
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
          );
        },
      );
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

class _ModernTextFieldState extends State<_ModernTextField> {
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {
      _isFocused = widget.focusNode.hasFocus;
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
        // Fixed label - always visible
        Padding(
          padding: const EdgeInsets.only(
            left: AppDesign.spacingS,
            bottom: AppDesign.spacingXS,
          ),
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
        // Input field container
        Container(
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
            child: Row(
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
          ),
        ),
        // Error message with icon
        if (hasError) ...[
          const SizedBox(height: AppDesign.spacingXS),
          Row(
            children: [
              const Icon(
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

/// Calculate preview dates based on recurrence pattern
List<DateTime> _calculatePreviewDates(
  RecurrencePattern pattern,
  DateTime startDate,
  int dayOfMonth,
  int dayOfWeek,
) {
  List<DateTime> dates = [];
  DateTime current = startDate;

  for (int i = 0; i < 3; i++) {
    if (i == 0) {
      dates.add(current);
    } else {
      switch (pattern) {
        case RecurrencePattern.weekly:
          current = current.add(const Duration(days: 7));
          dates.add(current);
          break;
        case RecurrencePattern.biweekly:
          current = current.add(const Duration(days: 14));
          dates.add(current);
          break;
        case RecurrencePattern.monthly:
          current = _calculateNextMonthlyOccurrence(current, dayOfMonth);
          dates.add(current);
          break;
      }
    }
  }

  return dates;
}

/// Calculate next monthly occurrence with day-of-month logic
DateTime _calculateNextMonthlyOccurrence(DateTime from, int dayOfMonth) {
  int nextMonth = from.month + 1;
  int nextYear = from.year;

  if (nextMonth > 12) {
    nextMonth = 1;
    nextYear++;
  }

  // Handle months with fewer days
  int daysInMonth = DateTime(nextYear, nextMonth + 1, 0).day;
  int actualDay = dayOfMonth > daysInMonth ? daysInMonth : dayOfMonth;

  return DateTime(nextYear, nextMonth, actualDay);
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

/// Get list of days of the week
List<String> _getDaysOfWeek() {
  return [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
}
