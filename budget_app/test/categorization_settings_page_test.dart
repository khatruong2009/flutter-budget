import 'package:budget_app/categorization_provider.dart';
import 'package:budget_app/categorization_settings_page.dart';
import 'package:budget_app/transaction_tag.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TestCategorizationProvider extends CategorizationProvider {
  final List<TransactionTag> _testTags = [];

  @override
  List<TransactionTag> get tags => List.unmodifiable(_testTags);

  @override
  Future<TransactionTag> addTag(
    String name, {
    String colorToken = 'accent',
  }) async {
    final tag = TransactionTag(name: name, colorToken: colorToken);
    _testTags.add(tag);
    notifyListeners();
    return tag;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('adding a tag keeps its dialog controller alive while closing',
      (tester) async {
    final provider = _TestCategorizationProvider();
    await tester.pumpWidget(
      ChangeNotifierProvider<CategorizationProvider>.value(
        value: provider,
        child: const MaterialApp(home: CategorizationSettingsPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('ADD').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Work');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Work'), findsOneWidget);
    expect(provider.tags.single.name, 'Work');
  });
}
