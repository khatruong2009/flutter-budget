import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import 'category_definition.dart';
import 'category_provider.dart';
import 'common.dart';
import 'design_system.dart';
import 'transaction.dart';
import 'transaction_model.dart';
import 'recurring_transaction_model.dart';
import 'categorization_provider.dart';

class CategorySettingsPage extends StatefulWidget {
  const CategorySettingsPage({super.key});

  @override
  State<CategorySettingsPage> createState() => _CategorySettingsPageState();
}

class _CategorySettingsPageState extends State<CategorySettingsPage> {
  BudgetCategoryType _selectedType = BudgetCategoryType.expense;
  bool _showArchived = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CategoryProvider>();
    final categories = provider.categoriesFor(
      _selectedType,
      includeArchived: _showArchived,
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
        actions: [
          IconButton(
            tooltip: 'Add category',
            onPressed: () => _showCategoryEditor(context),
            icon: const Icon(Symbols.add_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDesign.spacingM,
                AppDesign.spacingS,
                AppDesign.spacingM,
                0,
              ),
              child: SegmentedPillControl(
                segments: const ['Expenses', 'Income'],
                selectedIndex:
                    _selectedType == BudgetCategoryType.expense ? 0 : 1,
                onChanged: (index) {
                  setState(() {
                    _selectedType = index == 0
                        ? BudgetCategoryType.expense
                        : BudgetCategoryType.income;
                  });
                },
              ),
            ),
            SwitchListTile.adaptive(
              value: _showArchived,
              onChanged: (value) => setState(() => _showArchived = value),
              title: const Text('Show archived'),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppDesign.spacingL,
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                  AppDesign.spacingM,
                  0,
                  AppDesign.spacingM,
                  AppDesign.spacingXL,
                ),
                itemCount: categories.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppDesign.spacingS),
                itemBuilder: (context, index) {
                  final category = categories[index];
                  return GlowCard(
                    padding: const EdgeInsets.all(AppDesign.spacingS),
                    child: ListTile(
                      leading: IconTile(
                        icon: categoryIconRegistry[category.iconIdentifier] ??
                            CupertinoIcons.square_grid_2x2,
                        color: _categoryColor(category.colorToken, isDark),
                      ),
                      title: Text(
                        category.name,
                        style: AppTypography.rowTitle.copyWith(
                          color: AppColors.getTextColor(isDark),
                        ),
                      ),
                      subtitle: Text(
                        [
                          if (category.isBuiltIn) 'Built in',
                          if (category.isArchived) 'Archived',
                        ].join(' · '),
                        style: AppTypography.rowSubtitle.copyWith(
                          color: AppColors.getTextSecondaryColor(isDark),
                        ),
                      ),
                      trailing: PopupMenuButton<String>(
                        tooltip: 'Category actions',
                        onSelected: (action) =>
                            _handleAction(context, category, action),
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Text('Edit'),
                          ),
                          if (!category.isArchived && index > 0)
                            const PopupMenuItem(
                              value: 'up',
                              child: Text('Move up'),
                            ),
                          if (!category.isArchived &&
                              index < categories.length - 1)
                            const PopupMenuItem(
                              value: 'down',
                              child: Text('Move down'),
                            ),
                          PopupMenuItem(
                            value: category.isArchived ? 'restore' : 'archive',
                            child: Text(
                                category.isArchived ? 'Restore' : 'Archive'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add category',
        onPressed: () => _showCategoryEditor(context),
        child: const Icon(Symbols.add_rounded),
      ),
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    BudgetCategory category,
    String action,
  ) async {
    final provider = context.read<CategoryProvider>();
    try {
      switch (action) {
        case 'edit':
          await _showCategoryEditor(context, category: category);
        case 'up':
          await provider.moveCategory(category.id, -1);
        case 'down':
          await provider.moveCategory(category.id, 1);
        case 'archive':
          await provider.setArchived(category.id, true);
        case 'restore':
          await provider.setArchived(category.id, false);
      }
    } on Object catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyError(error))),
      );
    }
  }

  Future<void> _showCategoryEditor(
    BuildContext context, {
    BudgetCategory? category,
  }) async {
    final nameController = TextEditingController(text: category?.name);
    var iconIdentifier = category?.iconIdentifier ?? 'square_grid_2x2';
    var colorToken = category?.colorToken ?? 'accent';
    final formKey = GlobalKey<FormState>();

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(category == null ? 'New category' : 'Edit category'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: nameController,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Name'),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter a category name'
                        : null,
                  ),
                  const SizedBox(height: AppDesign.spacingM),
                  const Text('Icon', style: AppTypography.caption),
                  const SizedBox(height: AppDesign.spacingS),
                  Wrap(
                    spacing: AppDesign.spacingS,
                    runSpacing: AppDesign.spacingS,
                    children: [
                      for (final entry in categoryIconRegistry.entries)
                        _ChoiceButton(
                          selected: iconIdentifier == entry.key,
                          onPressed: () =>
                              setDialogState(() => iconIdentifier = entry.key),
                          child: Icon(entry.value, size: AppDesign.iconS),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppDesign.spacingM),
                  const Text('Color', style: AppTypography.caption),
                  const SizedBox(height: AppDesign.spacingS),
                  Wrap(
                    spacing: AppDesign.spacingS,
                    children: [
                      for (final token in _colorTokens)
                        _ChoiceButton(
                          selected: colorToken == token,
                          onPressed: () =>
                              setDialogState(() => colorToken = token),
                          child: Container(
                            width: AppDesign.iconS,
                            height: AppDesign.iconS,
                            decoration: BoxDecoration(
                              color: _categoryColor(
                                token,
                                Theme.of(context).brightness == Brightness.dark,
                              ),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() == true) {
                  Navigator.pop(dialogContext, true);
                }
              },
              child: Text(category == null ? 'Add' : 'Save'),
            ),
          ],
        ),
      ),
    );
    // Dialog Futures complete when pop starts, while the TextFormField remains
    // mounted for the reverse animation. Wait before disposing its controller
    // or notifying providers that rebuild the route below it.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (shouldSave != true || !context.mounted) {
      nameController.dispose();
      return;
    }

    final provider = context.read<CategoryProvider>();
    try {
      if (category == null) {
        await provider.addCategory(
          type: _selectedType,
          name: nameController.text,
          iconIdentifier: iconIdentifier,
          colorToken: colorToken,
        );
      } else {
        final newName = nameController.text.trim();
        await provider.updateCategory(
          category.id,
          name: newName,
          iconIdentifier: iconIdentifier,
          colorToken: colorToken,
        );
        if (newName != category.name) {
          if (!context.mounted) return;
          final transactionType = category.type == BudgetCategoryType.expense
              ? TransactionTyp.expense
              : TransactionTyp.income;
          await context.read<TransactionModel>().renameCategory(
                type: transactionType,
                oldName: category.name,
                newName: newName,
              );
          if (!context.mounted) return;
          await context.read<RecurringTransactionModel>().renameCategory(
                type: transactionType,
                oldName: category.name,
                newName: newName,
              );
          if (!context.mounted) return;
          await context.read<CategorizationProvider>().renameCategory(
                category.name,
                newName,
              );
        }
      }
    } on Object catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyError(error))),
      );
    } finally {
      nameController.dispose();
    }
  }

  String _friendlyError(Object error) {
    if (error is ArgumentError) return error.message.toString();
    if (error is StateError) return error.message;
    return 'Could not update this category';
  }
}

class _ChoiceButton extends StatelessWidget {
  final bool selected;
  final VoidCallback onPressed;
  final Widget child;

  const _ChoiceButton({
    required this.selected,
    required this.onPressed,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(AppDesign.radiusM),
      child: Container(
        width: AppDesign.touchTargetMin,
        height: AppDesign.touchTargetMin,
        decoration: BoxDecoration(
          color: selected
              ? AppColors.getAccent(
                      Theme.of(context).brightness == Brightness.dark)
                  .withValues(alpha: 0.18)
              : AppDesign.getSurfaceColor(context),
          borderRadius: BorderRadius.circular(AppDesign.radiusM),
          border: Border.all(
            color: selected
                ? AppColors.getAccent(
                    Theme.of(context).brightness == Brightness.dark)
                : AppDesign.getBorderColor(context),
          ),
        ),
        alignment: Alignment.center,
        child: child,
      ),
    );
  }
}

const _colorTokens = [
  'accent',
  'green',
  'blue',
  'orange',
  'red',
  'purple',
  'pink',
  'cyan',
];

Color _categoryColor(String token, bool isDark) {
  switch (token) {
    case 'green':
      return AppColors.getIncome(isDark);
    case 'blue':
      return AppColors.getInfo(isDark);
    case 'orange':
      return AppColors.getWarning(isDark);
    case 'red':
      return AppColors.getDanger(isDark);
    case 'purple':
      return AppColors.primaryLight;
    case 'pink':
      return AppColors.pink;
    case 'cyan':
      return const Color(0xFF22D3EE);
    default:
      return AppColors.getAccent(isDark);
  }
}
