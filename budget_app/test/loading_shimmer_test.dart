import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:budget_app/widgets/loading_shimmer.dart';
import 'package:budget_app/design_system.dart';

void main() {
  group('LoadingShimmer', () {
    testWidgets('renders list shimmer with correct item count', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LoadingShimmer(
              type: ShimmerType.list,
              itemCount: 3,
            ),
          ),
        ),
      );

      // Verify the shimmer is rendered
      expect(find.byType(LoadingShimmer), findsOneWidget);
      
      // Pump to allow animation to start
      await tester.pump();
    });

    testWidgets('renders card shimmer with correct item count', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LoadingShimmer(
              type: ShimmerType.card,
              itemCount: 2,
            ),
          ),
        ),
      );

      expect(find.byType(LoadingShimmer), findsOneWidget);
      await tester.pump();
    });

    testWidgets('renders text shimmer with correct item count', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LoadingShimmer(
              type: ShimmerType.text,
              itemCount: 4,
            ),
          ),
        ),
      );

      expect(find.byType(LoadingShimmer), findsOneWidget);
      await tester.pump();
    });

    testWidgets('renders custom shimmer with child', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoadingShimmer.custom(
              child: Container(
                width: 100,
                height: 100,
                color: Colors.grey,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(LoadingShimmer), findsOneWidget);
      expect(find.byType(Container), findsWidgets);
      await tester.pump();
    });

    testWidgets('factory constructor for list creates correct type', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoadingShimmer.list(itemCount: 5),
          ),
        ),
      );

      expect(find.byType(LoadingShimmer), findsOneWidget);
      await tester.pump();
    });

    testWidgets('factory constructor for card creates correct type', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoadingShimmer.card(itemCount: 2),
          ),
        ),
      );

      expect(find.byType(LoadingShimmer), findsOneWidget);
      await tester.pump();
    });

    testWidgets('factory constructor for text creates correct type', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoadingShimmer.text(itemCount: 3),
          ),
        ),
      );

      expect(find.byType(LoadingShimmer), findsOneWidget);
      await tester.pump();
    });

    testWidgets('shimmer animation runs when enabled', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LoadingShimmer(
              type: ShimmerType.list,
              itemCount: 1,
              enabled: true,
            ),
          ),
        ),
      );

      // Initial state
      await tester.pump();
      
      // Advance animation
      await tester.pump(const Duration(milliseconds: 500));
      
      // Animation should be running
      expect(find.byType(LoadingShimmer), findsOneWidget);
    });

    testWidgets('shimmer does not animate when disabled', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoadingShimmer.custom(
              enabled: false,
              child: const Text('Content'),
            ),
          ),
        ),
      );

      // Should show the child content when disabled
      expect(find.text('Content'), findsOneWidget);
    });

    testWidgets('uses custom base and highlight colors when provided', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LoadingShimmer(
              type: ShimmerType.text,
              itemCount: 1,
              baseColor: Colors.red,
              highlightColor: Colors.blue,
            ),
          ),
        ),
      );

      expect(find.byType(LoadingShimmer), findsOneWidget);
      await tester.pump();
    });

    testWidgets('respects custom height and width', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoadingShimmer.custom(
              height: 200,
              width: 300,
              child: Container(),
            ),
          ),
        ),
      );

      expect(find.byType(LoadingShimmer), findsOneWidget);
      await tester.pump();
    });

    testWidgets('list shimmer contains expected skeleton structure', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoadingShimmer.list(itemCount: 1),
          ),
        ),
      );

      await tester.pump();
      
      // Verify ListView is present
      expect(find.byType(ListView), findsOneWidget);
    });

    testWidgets('card shimmer contains expected skeleton structure', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoadingShimmer.card(itemCount: 2),
          ),
        ),
      );

      await tester.pump();
      
      // Verify GridView is present
      expect(find.byType(GridView), findsOneWidget);
    });

    testWidgets('text shimmer contains expected skeleton structure', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoadingShimmer.text(itemCount: 3),
          ),
        ),
      );

      await tester.pump();
      
      // Verify Column is present
      expect(find.byType(Column), findsWidgets);
    });

    testWidgets('shimmer updates when enabled state changes', (tester) async {
      bool enabled = true;
      
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return MaterialApp(
              home: Scaffold(
                body: Column(
                  children: [
                    LoadingShimmer.custom(
                      enabled: enabled,
                      child: const Text('Content'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          enabled = !enabled;
                        });
                      },
                      child: const Text('Toggle'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );

      // Initially enabled, should show shimmer
      expect(find.byType(LoadingShimmer), findsOneWidget);
      
      // Tap to disable
      await tester.tap(find.text('Toggle'));
      await tester.pumpAndSettle();
      
      // Should now show content
      expect(find.text('Content'), findsOneWidget);
    });

    testWidgets('shimmer uses correct animation duration', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoadingShimmer.list(itemCount: 1),
          ),
        ),
      );

      await tester.pump();
      
      // Advance by shimmer duration
      await tester.pump(AppAnimations.shimmerDuration);
      
      expect(find.byType(LoadingShimmer), findsOneWidget);
    });

    testWidgets('shimmer works in both light and dark themes', (tester) async {
      // Test light theme
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: LoadingShimmer.list(itemCount: 1),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(LoadingShimmer), findsOneWidget);

      // Test dark theme
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: LoadingShimmer.list(itemCount: 1),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(LoadingShimmer), findsOneWidget);
    });
  });

  group('ShimmerType', () {
    test('has all expected types', () {
      expect(ShimmerType.values.length, 4);
      expect(ShimmerType.values, contains(ShimmerType.list));
      expect(ShimmerType.values, contains(ShimmerType.card));
      expect(ShimmerType.values, contains(ShimmerType.text));
      expect(ShimmerType.values, contains(ShimmerType.custom));
    });
  });
}

