import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:budget_app/widgets/glow_fab.dart';

void main() {
  Finder sizedContainerFinder() => find.descendant(
        of: find.byType(GlowFab),
        matching: find.byWidgetPredicate(
          (widget) => widget is Container && widget.decoration is BoxDecoration,
        ),
      );

  group('GlowFab size parameter', () {
    testWidgets('default size renders at 54x54 with icon size 26',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GlowFab(onPressed: () {}),
          ),
        ),
      );

      final renderBox =
          tester.renderObject<RenderBox>(sizedContainerFinder().first);
      expect(renderBox.size.width, 54);
      expect(renderBox.size.height, 54);

      final icon = tester.widget<Icon>(find.byIcon(Symbols.add_rounded));
      expect(icon.size, 26);
    });

    testWidgets('size: 44 renders 44x44 with proportionally derived icon',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GlowFab(size: 44, onPressed: () {}),
          ),
        ),
      );

      final renderBox =
          tester.renderObject<RenderBox>(sizedContainerFinder().first);
      expect(renderBox.size.width, 44);
      expect(renderBox.size.height, 44);

      final icon = tester.widget<Icon>(find.byIcon(Symbols.add_rounded));
      expect(icon.size, closeTo(21, 1));
    });

    testWidgets('semanticLabel is exposed for accessibility', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GlowFab(
              onPressed: () {},
              semanticLabel: 'Add by voice',
            ),
          ),
        ),
      );

      expect(find.bySemanticsLabel('Add by voice'), findsOneWidget);
    });

    testWidgets('onPressed fires on tap at default size', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GlowFab(onPressed: () => tapped = true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(GlowFab));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('onPressed fires on tap at size 44', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GlowFab(size: 44, onPressed: () => tapped = true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(GlowFab));
      await tester.pump();

      expect(tapped, isTrue);
    });
  });
}
