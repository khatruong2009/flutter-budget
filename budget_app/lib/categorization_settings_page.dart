import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import 'categorization_provider.dart';
import 'categorization_rule.dart';
import 'common.dart';
import 'design_system.dart';
import 'transaction.dart';

class CategorizationSettingsPage extends StatelessWidget {
  const CategorizationSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CategorizationProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Tags & rules')),
      body: ListView(
        padding: const EdgeInsets.all(AppDesign.spacingM),
        children: [
          _SectionTitle(
            title: 'Tags',
            action: 'ADD',
            onTap: () => _addTag(context, provider),
          ),
          const SizedBox(height: AppDesign.spacingS),
          if (provider.tags.isEmpty)
            const _EmptyCard(
              message: 'Add tags to group transactions across categories.',
            )
          else
            GlowListCard(
              children: [
                for (final tag in provider.tags)
                  ListTile(
                    title: Text(tag.name),
                    leading: const Icon(Symbols.label_rounded),
                    trailing: IconButton(
                      tooltip: 'Delete ${tag.name}',
                      icon: const Icon(Symbols.delete_rounded),
                      onPressed: () => provider.deleteTag(tag.id),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: AppDesign.spacingXL),
          _SectionTitle(
            title: 'Merchant rules',
            action: 'ADD',
            onTap: () => _addRule(context, provider),
          ),
          const SizedBox(height: AppDesign.spacingS),
          if (provider.rules.isEmpty)
            const _EmptyCard(
              message:
                  'Rules can automatically choose a category and tags from a merchant name.',
            )
          else
            GlowListCard(
              children: [
                for (final rule in provider.rules)
                  ListTile(
                    title: Text(rule.merchantPattern),
                    subtitle: Text(
                      '${rule.matchType.name} · ${rule.category}'
                      '${rule.tagIds.isEmpty ? '' : ' · ${rule.tagIds.length} tags'}',
                    ),
                    leading: const Icon(Symbols.auto_awesome_rounded),
                    trailing: IconButton(
                      tooltip: 'Delete rule',
                      icon: const Icon(Symbols.delete_rounded),
                      onPressed: () => provider.deleteRule(rule.id),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _addTag(
    BuildContext context,
    CategorizationProvider provider,
  ) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('New tag'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Travel planning'),
          textCapitalization: TextCapitalization.words,
          onSubmitted: (value) => Navigator.pop(dialogContext, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    // Navigator.pop completes the dialog Future before its reverse transition
    // has removed the TextField. Keep the controller alive until that widget is
    // gone, otherwise a provider rebuild can make the exiting field reuse a
    // disposed controller.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    controller.dispose();
    if (name == null || name.trim().isEmpty) return;
    try {
      await provider.addTag(name);
    } on ArgumentError catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message?.toString() ?? 'Invalid tag')),
      );
    }
  }

  Future<void> _addRule(
    BuildContext context,
    CategorizationProvider provider,
  ) async {
    final merchantController = TextEditingController();
    var type = TransactionTyp.expense;
    var matchType = MerchantMatchType.contains;
    var category = expenseCategories.keys.first;
    final tagIds = <String>{};

    final rule = await showDialog<CategorizationRule>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          final categories = type == TransactionTyp.expense
              ? expenseCategories
              : incomeCategories;
          if (!categories.containsKey(category)) {
            category = categories.keys.first;
          }
          return AlertDialog(
            title: const Text('New merchant rule'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: merchantController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Merchant text',
                      hintText: 'Whole Foods',
                    ),
                  ),
                  const SizedBox(height: AppDesign.spacingM),
                  DropdownButtonFormField<TransactionTyp>(
                    initialValue: type,
                    decoration: const InputDecoration(labelText: 'Type'),
                    items: TransactionTyp.values
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() {
                      type = value ?? TransactionTyp.expense;
                    }),
                  ),
                  const SizedBox(height: AppDesign.spacingM),
                  DropdownButtonFormField<MerchantMatchType>(
                    initialValue: matchType,
                    decoration: const InputDecoration(labelText: 'Match'),
                    items: MerchantMatchType.values
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() {
                      matchType = value ?? MerchantMatchType.contains;
                    }),
                  ),
                  const SizedBox(height: AppDesign.spacingM),
                  DropdownButtonFormField<String>(
                    initialValue: category,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: categories.keys
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() {
                      category = value ?? categories.keys.first;
                    }),
                  ),
                  if (provider.tags.isNotEmpty) ...[
                    const SizedBox(height: AppDesign.spacingM),
                    Wrap(
                      spacing: AppDesign.spacingXS,
                      children: [
                        for (final tag in provider.tags)
                          FilterChip(
                            label: Text(tag.name),
                            selected: tagIds.contains(tag.id),
                            onSelected: (selected) => setState(() {
                              selected
                                  ? tagIds.add(tag.id)
                                  : tagIds.remove(tag.id);
                            }),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  if (merchantController.text.trim().isEmpty) return;
                  Navigator.pop(
                    dialogContext,
                    CategorizationRule(
                      merchantPattern: merchantController.text,
                      matchType: matchType,
                      transactionType: type,
                      category: category,
                      tagIds: tagIds.toList(),
                    ),
                  );
                },
                child: const Text('Add'),
              ),
            ],
          );
        },
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 250));
    merchantController.dispose();
    if (rule != null) await provider.addRule(rule);
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String action;
  final VoidCallback onTap;

  const _SectionTitle({
    required this.title,
    required this.action,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: AppTypography.headingMedium),
        ),
        TextButton(onPressed: onTap, child: Text(action)),
      ],
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final String message;

  const _EmptyCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return GlowCard(
      child: Text(
        message,
        style: AppTypography.bodyMedium.copyWith(
          color: AppDesign.getTextSecondary(context),
        ),
      ),
    );
  }
}
