import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:budget_app/widgets/empty_state.dart';
import 'package:budget_app/design_system.dart';

void main() {
  group('EmptyState Widget Tests', () {
    testWidgets('renders with default noData state', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyState.noData(),
          ),
        ),
      );

      // Verify default title and message are displayed
      expect(find.text('No Data Yet'), findsOneWidget);
      expect(find.text('Get started by adding your first item'), findsOneWidget);
      
      // Verify icon is displayed
      expect(find.byIcon(CupertinoIcons.tray), findsOneWidget);
    });

    testWidgets('renders with default noResults state', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyState.noResults(),
          ),
        ),
      );

      // Verify default title and message are displayed
      expect(find.text('No Results Found'), findsOneWidget);
      expect(find.text('Try adjusting your search or filters'), findsOneWidget);
      
      // Verify icon is displayed
      expect(find.byIcon(CupertinoIcons.search), findsOneWidget);
    });

    testWidgets('renders with default error state', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyState.error(),
          ),
        ),
      );

      // Verify default title and message are displayed
      expect(find.text('Something Went Wrong'), findsOneWidget);
      expect(find.text('We encountered an error. Please try again'), findsOneWidget);
      
      // Verify icon is displayed
      expect(find.byIcon(CupertinoIcons.exclamationmark_triangle), findsOneWidget);
    });

    testWidgets('renders with custom title and message', (WidgetTester tester) async {
      const customTitle = 'Custom Title';
      const customMessage = 'Custom message text';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyState.noData(
              title: customTitle,
              message: customMessage,
            ),
          ),
        ),
      );

      // Verify custom title and message are displayed
      expect(find.text(customTitle), findsOneWidget);
      expect(find.text(customMessage), findsOneWidget);
    });

    testWidgets('renders with custom icon', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyState.noData(
              icon: CupertinoIcons.money_dollar_circle,
            ),
          ),
        ),
      );

      // Verify custom icon is displayed
      expect(find.byIcon(CupertinoIcons.money_dollar_circle), findsOneWidget);
      
      // Verify default icon is not displayed
      expect(find.byIcon(CupertinoIcons.tray), findsNothing);
    });

    testWidgets('renders action button when provided', (WidgetTester tester) async {
      bool actionCalled = false;
      const actionLabel = 'Add Item';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyState.noData(
              actionLabel: actionLabel,
              onAction: () {
                actionCalled = true;
              },
            ),
          ),
        ),
      );

      // Verify action button is displayed
      expect(find.text(actionLabel), findsOneWidget);
      
      // Tap the button
      await tester.tap(find.text(actionLabel));
      await tester.pump();

      // Verify callback was called
      expect(actionCalled, true);
    });

    testWidgets('does not render action button when not provided', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyState.noData(),
          ),
        ),
      );

      // Verify no AppButton is rendered
      expect(find.byType(AppButton), findsNothing);
    });

    testWidgets('renders with gradient icon container', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyState(
              type: EmptyStateType.noData,
              iconGradient: AppColors.primaryGradient,
            ),
          ),
        ),
      );

      // Verify Container with gradient decoration exists
      final containerFinder = find.descendant(
        of: find.byType(EmptyState),
        matching: find.byWidgetPredicate(
          (widget) => widget is Container && 
                      widget.decoration is BoxDecoration &&
                      (widget.decoration as BoxDecoration).gradient != null,
        ),
      );
      
      expect(containerFinder, findsOneWidget);
    });

    testWidgets('uses design system spacing', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyState.noData(
              actionLabel: 'Action',
              onAction: null,
            ),
          ),
        ),
      );

      // Verify SizedBox widgets use design system spacing
      final sizedBoxes = find.byType(SizedBox);
      expect(sizedBoxes, findsWidgets);
      
      // Check that spacing values are from design system
      final sizedBoxWidgets = tester.widgetList<SizedBox>(sizedBoxes);
      for (final sizedBox in sizedBoxWidgets) {
        if (sizedBox.height != null) {
          // Verify height is a design system spacing value
          final validSpacings = [
            AppDesign.spacingXXS,
            AppDesign.spacingXS,
            AppDesign.spacingS,
            AppDesign.spacingM,
            AppDesign.spacingL,
            AppDesign.spacingXL,
            AppDesign.spacingXXL,
            AppDesign.spacingXXXL,
          ];
          expect(validSpacings.contains(sizedBox.height), true,
              reason: 'SizedBox height ${sizedBox.height} should use design system spacing');
        }
      }
    });

    testWidgets('uses design system typography', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyState.noData(
              title: 'Test Title',
              message: 'Test Message',
            ),
          ),
        ),
      );

      // Find Text widgets
      final titleText = tester.widget<Text>(find.text('Test Title'));
      final messageText = tester.widget<Text>(find.text('Test Message'));

      // Verify typography uses design system
      expect(titleText.style?.fontSize, AppTypography.headingMedium.fontSize);
      expect(messageText.style?.fontSize, AppTypography.bodyMedium.fontSize);
    });

    testWidgets('centers content vertically and horizontally', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyState.noData(),
          ),
        ),
      );

      // Verify Center widget is used (at least one)
      expect(find.byType(Center), findsWidgets);
      
      // Verify Column has center alignment
      final column = tester.widget<Column>(find.byType(Column).first);
      expect(column.mainAxisAlignment, MainAxisAlignment.center);
    });

    testWidgets('all empty state types have correct default icons', (WidgetTester tester) async {
      // Test noData type
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyState.noData(),
          ),
        ),
      );
      expect(find.byIcon(CupertinoIcons.tray), findsOneWidget);

      // Test noResults type
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyState.noResults(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(CupertinoIcons.search), findsOneWidget);

      // Test error type
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyState.error(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(CupertinoIcons.exclamationmark_triangle), findsOneWidget);
    });

    testWidgets('action button only appears when both label and callback provided', (WidgetTester tester) async {
      // Test with both label and callback
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyState.noData(
              actionLabel: 'Action',
              onAction: () {},
            ),
          ),
        ),
      );
      expect(find.byType(AppButton), findsOneWidget);

      // Test with only label (no callback)
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyState.noData(
              actionLabel: 'Action',
              onAction: null,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AppButton), findsNothing);

      // Test with only callback (no label)
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyState.noData(
              onAction: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AppButton), findsNothing);
    });
  });
}
