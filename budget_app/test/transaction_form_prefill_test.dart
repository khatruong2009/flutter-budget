import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:budget_app/common.dart';
import 'package:budget_app/categorization_provider.dart';
import 'package:budget_app/categorization_rule.dart';
import 'package:budget_app/transaction.dart';
import 'package:budget_app/transaction_form.dart';
import 'package:budget_app/transaction_model.dart';
import 'package:budget_app/transaction_tag.dart';
import 'package:budget_app/widgets/modern_text_field.dart';

class _TestCategorizationProvider extends CategorizationProvider {
  final TransactionTag tag;
  final CategorizationRule rule;

  _TestCategorizationProvider({
    required this.tag,
    required this.rule,
  });

  @override
  List<TransactionTag> get tags => [tag];

  @override
  CategorizationSuggestion? suggest({
    required TransactionTyp type,
    required String description,
    required double amount,
  }) {
    return rule.matches(
      type: type,
      description: description,
      amount: amount,
    )
        ? CategorizationSuggestion(rule)
        : null;
  }
}

/// Pumps a minimal host that provides a [TransactionModel] and exposes a button
/// which opens [showTransactionForm] with the supplied [type]/[prefill].
///
/// The form calls [Provider.of<TransactionModel>].addTransaction directly, so
/// submitted values are read back from [model.transactions]. A spy closure is
/// still passed for the addTransaction parameter to capture whether the form
/// ever invokes it.
Future<void> _pumpForm(
  WidgetTester tester, {
  required TransactionModel model,
  required TransactionTyp type,
  Transaction? prefill,
  Transaction? transactionToEdit,
  String? initialCategory,
  CategorizationProvider? categorizationProvider,
  Function? addSpy,
}) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<TransactionModel>.value(value: model),
        if (categorizationProvider != null)
          ChangeNotifierProvider<CategorizationProvider>.value(
            value: categorizationProvider,
          ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => showTransactionForm(
                  context,
                  type,
                  addSpy ?? (a, b, c, d, e) {},
                  prefill: prefill,
                  transactionToEdit: transactionToEdit,
                  initialCategory: initialCategory,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

/// Reads the current text in the [ModernTextField] whose label matches.
String _fieldText(WidgetTester tester, String label) {
  final field = tester
      .widgetList<ModernTextField>(find.byType(ModernTextField))
      .firstWhere((w) => w.label == label);
  return field.controller.text;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('prefill populates every field (description, category, amount)',
      (tester) async {
    final model = TransactionModel();
    final prefill = Transaction(
      type: TransactionTyp.expense,
      description: 'Lunch at Chipotle',
      amount: 12.50,
      category: 'Eating Out',
      date: DateTime(2026, 7, 4),
    );

    await _pumpForm(
      tester,
      model: model,
      type: TransactionTyp.expense,
      prefill: prefill,
    );

    // Dialog opened as an Add (not Update) expense form.
    expect(find.text('Add Expense'), findsOneWidget);
    expect(find.text('Add'), findsOneWidget);
    expect(find.text('Update'), findsNothing);

    // Description + amount controllers carry the prefilled values.
    expect(_fieldText(tester, 'Description'), 'Lunch at Chipotle');
    expect(_fieldText(tester, 'Amount'), '12.50');

    // Category picker shows the prefilled category as its selected label.
    expect(find.text('Eating Out'), findsOneWidget);
  });

  testWidgets('amount field is empty when prefill.amount is 0.0',
      (tester) async {
    final model = TransactionModel();
    final prefill = Transaction(
      type: TransactionTyp.expense,
      description: 'Coffee',
      amount: 0.0,
      category: 'Eating Out',
      date: DateTime(2026, 7, 4),
    );

    await _pumpForm(
      tester,
      model: model,
      type: TransactionTyp.expense,
      prefill: prefill,
    );

    expect(_fieldText(tester, 'Amount'), isEmpty,
        reason: 'amount 0.0 is the unknown sentinel; field stays empty');
    // Description still prefilled so only the amount is missing.
    expect(_fieldText(tester, 'Description'), 'Coffee');
  });

  testWidgets('date row shows the prefilled date formatted MMM dd, yyyy',
      (tester) async {
    final model = TransactionModel();
    final prefillDate = DateTime(2026, 7, 4);
    final prefill = Transaction(
      type: TransactionTyp.expense,
      description: 'Lunch',
      amount: 12.50,
      category: 'Eating Out',
      date: prefillDate,
    );

    await _pumpForm(
      tester,
      model: model,
      type: TransactionTyp.expense,
      prefill: prefill,
    );

    expect(find.text('Date'), findsOneWidget);
    expect(find.text(DateFormat('MMM dd, yyyy').format(prefillDate)),
        findsOneWidget);
  });

  testWidgets('tapping Add submits the prefilled values to the model',
      (tester) async {
    final model = TransactionModel();
    final prefillDate = DateTime(2026, 7, 4);
    final prefill = Transaction(
      type: TransactionTyp.expense,
      description: 'Lunch at Chipotle',
      amount: 12.50,
      category: 'Eating Out',
      date: prefillDate,
    );

    await _pumpForm(
      tester,
      model: model,
      type: TransactionTyp.expense,
      prefill: prefill,
    );

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(model.transactions, hasLength(1));
    final added = model.transactions.single;
    expect(added.type, TransactionTyp.expense);
    expect(added.description, 'Lunch at Chipotle');
    expect(added.amount, 12.50);
    expect(added.category, 'Eating Out');
    expect(added.date, prefillDate);
  });

  testWidgets('prefill applies merchant rule category and tags',
      (tester) async {
    final model = TransactionModel();
    final tag = TransactionTag(id: 'tag-work', name: 'Work');
    final rule = CategorizationRule(
      merchantPattern: 'Acme',
      transactionType: TransactionTyp.expense,
      category: 'Groceries',
      tagIds: [tag.id],
    );
    final categorization = _TestCategorizationProvider(tag: tag, rule: rule);
    final prefill = Transaction(
      type: TransactionTyp.expense,
      description: 'Acme Market',
      amount: 18.25,
      category: 'General',
      date: DateTime(2026, 7, 4),
    );

    await _pumpForm(
      tester,
      model: model,
      type: TransactionTyp.expense,
      prefill: prefill,
      categorizationProvider: categorization,
    );

    final workChip = tester.widget<FilterChip>(
      find.widgetWithText(FilterChip, 'Work'),
    );
    expect(workChip.selected, isTrue);
    expect(find.text('Groceries'), findsOneWidget);

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(model.transactions.single.category, 'Groceries');
    expect(model.transactions.single.tagIds, [tag.id]);
  });

  testWidgets('income prefill submits with income type and category',
      (tester) async {
    final model = TransactionModel();
    final prefill = Transaction(
      type: TransactionTyp.income,
      description: 'Paycheck',
      amount: 3000.0,
      category: 'Salary',
      date: DateTime(2026, 7, 4),
    );

    await _pumpForm(
      tester,
      model: model,
      type: TransactionTyp.income,
      prefill: prefill,
    );

    expect(find.text('Add Income'), findsOneWidget);
    expect(_fieldText(tester, 'Amount'), '3000.00');
    expect(find.text('Salary'), findsWidgets);

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    final added = model.transactions.single;
    expect(added.type, TransactionTyp.income);
    expect(added.category, 'Salary');
    expect(added.amount, 3000.0);
  });

  testWidgets('editing updates in place and preserves recurring identity',
      (tester) async {
    final model = TransactionModel();
    model.addTransaction(
      TransactionTyp.expense,
      'Rent',
      1000,
      'Housing',
      DateTime(2026, 7, 1),
      recurringTemplateId: 'rent-template',
    );
    final original = model.transactions.single;

    await _pumpForm(
      tester,
      model: model,
      type: TransactionTyp.expense,
      transactionToEdit: original,
    );

    expect(find.text('Update'), findsOneWidget);
    final amountField = find.descendant(
      of: find.byWidgetPredicate(
        (widget) => widget is ModernTextField && widget.label == 'Amount',
      ),
      matching: find.byType(TextField),
    );
    final descriptionField = find.descendant(
      of: find.byWidgetPredicate(
        (widget) => widget is ModernTextField && widget.label == 'Description',
      ),
      matching: find.byType(TextField),
    );
    await tester.enterText(amountField, '1100');
    await tester.enterText(descriptionField, 'Updated rent');
    await tester.tap(find.text('Update'));
    await tester.pumpAndSettle();

    expect(model.transactions, hasLength(1));
    final updated = model.transactions.single;
    expect(updated.id, original.id);
    expect(updated.createdAt, original.createdAt);
    expect(updated.updatedAt.isAfter(original.updatedAt), isTrue);
    expect(updated.recurringTemplateId, 'rent-template');
    expect(updated.description, 'Updated rent');
    expect(updated.amount, 1100);
  });

  testWidgets('barrier tap does NOT dismiss the form when prefill != null',
      (tester) async {
    final model = TransactionModel();
    final prefill = Transaction(
      type: TransactionTyp.expense,
      description: 'Lunch',
      amount: 12.50,
      category: 'Eating Out',
      date: DateTime(2026, 7, 4),
    );

    await _pumpForm(
      tester,
      model: model,
      type: TransactionTyp.expense,
      prefill: prefill,
    );

    expect(find.text('Add Expense'), findsOneWidget);

    // Tap the top-left corner, well outside the centered dialog card.
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    expect(find.text('Add Expense'), findsOneWidget,
        reason: 'barrierDismissible is false when prefilled');
  });

  testWidgets('barrier tap DOES dismiss the form for a manual add (no prefill)',
      (tester) async {
    final model = TransactionModel();

    await _pumpForm(
      tester,
      model: model,
      type: TransactionTyp.expense,
    );

    expect(find.text('Add Expense'), findsOneWidget);

    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    expect(find.text('Add Expense'), findsNothing,
        reason: 'barrierDismissible is true without a prefill');
  });

  testWidgets('"Make this recurring" link is absent with a prefill',
      (tester) async {
    final model = TransactionModel();
    final prefill = Transaction(
      type: TransactionTyp.expense,
      description: 'Lunch',
      amount: 12.50,
      category: 'Eating Out',
      date: DateTime(2026, 7, 4),
    );

    await _pumpForm(
      tester,
      model: model,
      type: TransactionTyp.expense,
      prefill: prefill,
    );

    expect(find.text('Make this recurring'), findsNothing);
  });

  testWidgets('"Make this recurring" link is present without a prefill',
      (tester) async {
    final model = TransactionModel();

    await _pumpForm(
      tester,
      model: model,
      type: TransactionTyp.expense,
    );

    expect(find.text('Make this recurring'), findsOneWidget);
  });

  testWidgets('manual add (no prefill) shows the date row defaulting to today',
      (tester) async {
    final model = TransactionModel();

    await _pumpForm(
      tester,
      model: model,
      type: TransactionTyp.expense,
    );

    // Date row is always present, even for a manual add.
    expect(find.text('Date'), findsOneWidget);
    // Defaults to today's date.
    expect(find.text(DateFormat('MMM dd, yyyy').format(DateTime.now())),
        findsOneWidget);

    // Amount starts empty for a manual add; category defaults to first expense.
    expect(_fieldText(tester, 'Amount'), isEmpty);
    expect(expenseCategories.keys.first, 'General');
    expect(find.text('General'), findsOneWidget);
  });

  testWidgets('initialCategory preselects a manual transaction category',
      (tester) async {
    final model = TransactionModel();

    await _pumpForm(
      tester,
      model: model,
      type: TransactionTyp.expense,
      initialCategory: 'Groceries',
    );

    expect(_fieldText(tester, 'Amount'), isEmpty);
    expect(_fieldText(tester, 'Description'), isEmpty);
    expect(find.text('Groceries'), findsOneWidget);
  });
}
