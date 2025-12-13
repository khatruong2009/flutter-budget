import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:budget_app/utils/platform_utils.dart';
import 'package:budget_app/utils/platform_enhancements.dart';
import 'package:budget_app/widgets/responsive_layout.dart';

void main() {
  group('Platform Utils Tests', () {
    test('Platform detection methods should not throw', () {
      expect(() => PlatformUtils.isWeb, returnsNormally);
      expect(() => PlatformUtils.isMobile, returnsNormally);
      expect(() => PlatformUtils.isDesktop, returnsNormally);
    });

    test('Platform hover support should be consistent', () {
      final supportsHover = PlatformUtils.supportsHover;
      expect(supportsHover, isA<bool>());
    });

    test('Platform keyboard shortcuts support should be consistent', () {
      final supportsKeyboard = PlatformUtils.supportsKeyboardShortcuts;
      expect(supportsKeyboard, isA<bool>());
    });
  });

  group('Platform UI Constants Tests', () {
    test('List tile height should be positive', () {
      final height = PlatformUIConstants.getListTileHeight();
      expect(height, greaterThan(0));
      expect(height, lessThanOrEqualTo(100));
    });

    test('Button height should be positive and reasonable', () {
      final height = PlatformUIConstants.getButtonHeight();
      expect(height, greaterThan(0));
      expect(height, lessThanOrEqualTo(60));
    });

    test('Spacing multiplier should be positive', () {
      final multiplier = PlatformUIConstants.getSpacingMultiplier();
      expect(multiplier, greaterThan(0));
      expect(multiplier, lessThanOrEqualTo(2.0));
    });

    test('Border radius should be positive', () {
      final radius = PlatformUIConstants.getBorderRadius();
      expect(radius, greaterThan(0));
      expect(radius, lessThanOrEqualTo(20));
    });
  });

  group('Platform Text Field Config Tests', () {
    test('Amount keyboard type should be appropriate', () {
      final keyboardType = PlatformTextFieldConfig.getAmountKeyboardType();
      expect(keyboardType, isA<TextInputType>());
    });

    test('Text input action should be appropriate', () {
      final actionNext = PlatformTextFieldConfig.getTextInputAction(isLastField: false);
      final actionDone = PlatformTextFieldConfig.getTextInputAction(isLastField: true);
      
      expect(actionNext, equals(TextInputAction.next));
      expect(actionDone, equals(TextInputAction.done));
    });

    test('Autocorrect should be disabled for financial data', () {
      final shouldAutocorrect = PlatformTextFieldConfig.shouldAutocorrect();
      expect(shouldAutocorrect, isFalse);
    });

    test('Capitalization should be appropriate', () {
      final descriptionCap = PlatformTextFieldConfig.getCapitalization(isDescription: true);
      final defaultCap = PlatformTextFieldConfig.getCapitalization(isDescription: false);
      
      expect(descriptionCap, equals(TextCapitalization.sentences));
      expect(defaultCap, equals(TextCapitalization.none));
    });
  });

  group('Platform Animation Config Tests', () {
    test('Animation duration should be positive', () {
      final shortDuration = PlatformAnimationConfig.getAnimationDuration(isShort: true);
      final normalDuration = PlatformAnimationConfig.getAnimationDuration(isShort: false);
      
      expect(shortDuration.inMilliseconds, greaterThan(0));
      expect(normalDuration.inMilliseconds, greaterThan(0));
      expect(shortDuration.inMilliseconds, lessThan(normalDuration.inMilliseconds));
    });

    test('Animation curve should be valid', () {
      final curve = PlatformAnimationConfig.getAnimationCurve();
      expect(curve, isA<Curve>());
    });

    testWidgets('Should reduce motion check should work', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final shouldReduce = PlatformAnimationConfig.shouldReduceMotion(context);
              expect(shouldReduce, isA<bool>());
              return Container();
            },
          ),
        ),
      );
    });
  });

  group('Responsive Layout Tests', () {
    testWidgets('ResponsiveLayout should render child', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ResponsiveLayout(
            child: Text('Test Content'),
          ),
        ),
      );

      expect(find.text('Test Content'), findsOneWidget);
    });

    testWidgets('ResponsiveBuilder should provide screen size', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ResponsiveBuilder(
            builder: (context, screenSize) {
              expect(screenSize, isA<ScreenSize>());
              return Text('Screen: ${screenSize.name}');
            },
          ),
        ),
      );

      expect(find.textContaining('Screen:'), findsOneWidget);
    });

    testWidgets('AdaptiveGrid should render children', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AdaptiveGrid(
              children: [
                Text('Item 1'),
                Text('Item 2'),
                Text('Item 3'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 2'), findsOneWidget);
      expect(find.text('Item 3'), findsOneWidget);
    });

    testWidgets('AdaptiveColumns should render children', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AdaptiveColumns(
              children: [
                Text('Column 1'),
                Text('Column 2'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Column 1'), findsOneWidget);
      expect(find.text('Column 2'), findsOneWidget);
    });

    testWidgets('PlatformAppBar should render title', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            appBar: PlatformAppBar(
              title: 'Test Title',
            ),
          ),
        ),
      );

      expect(find.text('Test Title'), findsOneWidget);
    });
  });

  group('Platform Utils Widget Tests', () {
    testWidgets('getPlatformPadding should return valid padding', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final padding = PlatformUtils.getPlatformPadding(context);
              expect(padding, isA<EdgeInsets>());
              expect(padding.left, greaterThanOrEqualTo(0));
              expect(padding.right, greaterThanOrEqualTo(0));
              expect(padding.top, greaterThanOrEqualTo(0));
              expect(padding.bottom, greaterThanOrEqualTo(0));
              return Container();
            },
          ),
        ),
      );
    });

    testWidgets('getMaxContentWidth should return positive value', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final maxWidth = PlatformUtils.getMaxContentWidth(context);
              expect(maxWidth, greaterThan(0));
              return Container();
            },
          ),
        ),
      );
    });

    testWidgets('getIconSize should return reasonable value', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final iconSize = PlatformUtils.getIconSize(context);
              expect(iconSize, greaterThan(0));
              expect(iconSize, lessThanOrEqualTo(48));
              return Container();
            },
          ),
        ),
      );
    });

    testWidgets('getFontScale should return positive value', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final fontScale = PlatformUtils.getFontScale(context);
              expect(fontScale, greaterThan(0));
              expect(fontScale, lessThanOrEqualTo(2.0));
              return Container();
            },
          ),
        ),
      );
    });
  });

  group('Platform Loading Indicator Tests', () {
    testWidgets('platformLoadingIndicator should render', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlatformUtils.platformLoadingIndicator(),
          ),
        ),
      );

      // Should find either CupertinoActivityIndicator or CircularProgressIndicator
      expect(
        find.byType(CircularProgressIndicator).evaluate().isNotEmpty ||
        find.byWidgetPredicate((widget) => widget.runtimeType.toString().contains('Cupertino')).evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('platformLoadingIndicator with custom size should render', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlatformUtils.platformLoadingIndicator(size: 30),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(SizedBox), findsWidgets);
    });
  });

  group('Platform Scroll Physics Tests', () {
    test('platformScrollPhysics should return valid physics', () {
      final physics = PlatformUtils.platformScrollPhysics;
      expect(physics, isA<ScrollPhysics>());
    });
  });

  group('Platform Integration with Design System', () {
    testWidgets('Platform button should use design system colors', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlatformUtils.platformButton(
              label: 'Test Button',
              onPressed: () {},
              isPrimary: true,
            ),
          ),
        ),
      );

      expect(find.text('Test Button'), findsOneWidget);
    });

    testWidgets('Platform switch should render correctly', (tester) async {
      bool value = false;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return PlatformUtils.platformSwitch(
                  value: value,
                  onChanged: (newValue) {
                    setState(() => value = newValue);
                  },
                );
              },
            ),
          ),
        ),
      );

      // Should find either Switch or CupertinoSwitch
      expect(
        find.byType(Switch).evaluate().isNotEmpty ||
        find.byWidgetPredicate((widget) => widget.runtimeType.toString().contains('CupertinoSwitch')).evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('Platform dialog should be callable', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    PlatformUtils.showPlatformDialog(
                      context: context,
                      title: 'Test Dialog',
                      content: 'Test Content',
                      confirmText: 'OK',
                      cancelText: 'Cancel',
                    );
                  },
                  child: const Text('Show Dialog'),
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Show Dialog'), findsOneWidget);
      
      // Tap the button to show dialog
      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      // Dialog should be shown
      expect(find.text('Test Dialog'), findsOneWidget);
      expect(find.text('Test Content'), findsOneWidget);
    });

    testWidgets('Responsive layout should adapt to screen size', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ResponsiveLayout(
              child: Container(
                color: Colors.blue,
                child: const Text('Responsive Content'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Responsive Content'), findsOneWidget);
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('Platform page route should be creatable', (tester) async {
      final route = PlatformUtils.platformPageRoute(
        builder: (context) => const Scaffold(
          body: Text('New Page'),
        ),
      );

      expect(route, isA<PageRoute>());
    });
  });

  group('Platform-Specific Styling Verification', () {
    testWidgets('iOS/macOS should use appropriate border radius', (tester) async {
      final radius = PlatformUIConstants.getBorderRadius();
      
      // Border radius should be reasonable
      expect(radius, greaterThan(0));
      expect(radius, lessThanOrEqualTo(20));
      
      // On iOS/macOS, should be more rounded (12), otherwise 8
      if (PlatformUtils.isIOS || PlatformUtils.isMacOS) {
        expect(radius, equals(12));
      } else {
        expect(radius, equals(8));
      }
    });

    testWidgets('Desktop should have appropriate button height', (tester) async {
      final height = PlatformUIConstants.getButtonHeight();
      
      if (PlatformUtils.isDesktop) {
        expect(height, equals(40));
      } else {
        expect(height, equals(48));
      }
    });

    testWidgets('Mobile should have appropriate list tile height', (tester) async {
      final height = PlatformUIConstants.getListTileHeight();
      
      if (PlatformUtils.isDesktop) {
        expect(height, equals(60));
      } else {
        expect(height, equals(72));
      }
    });

    test('Web should have faster animations', () {
      final duration = PlatformAnimationConfig.getAnimationDuration(isShort: false);
      
      if (PlatformUtils.isWeb) {
        expect(duration.inMilliseconds, equals(250));
      } else {
        expect(duration.inMilliseconds, equals(300));
      }
    });

    test('iOS/macOS should use easeInOut curve', () {
      final curve = PlatformAnimationConfig.getAnimationCurve();
      
      if (PlatformUtils.isIOS || PlatformUtils.isMacOS) {
        expect(curve, equals(Curves.easeInOut));
      } else {
        expect(curve, equals(Curves.fastOutSlowIn));
      }
    });
  });

  group('Web Responsiveness Tests', () {
    testWidgets('Web should have responsive padding', (tester) async {
      // Test with different screen widths
      await tester.binding.setSurfaceSize(const Size(1400, 800));
      
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final padding = PlatformUtils.getPlatformPadding(context);
              
              if (PlatformUtils.isWeb) {
                // Wide screen should have horizontal padding
                expect(padding.left + padding.right, greaterThan(0));
              }
              
              return Container();
            },
          ),
        ),
      );
      
      // Reset surface size
      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('Web should have max content width', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 900));
      
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final maxWidth = PlatformUtils.getMaxContentWidth(context);
              
              if (PlatformUtils.isWeb) {
                // Should have a reasonable max width
                expect(maxWidth, lessThanOrEqualTo(1200));
              }
              
              return Container();
            },
          ),
        ),
      );
      
      // Reset surface size
      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('Responsive builder should adapt to screen size', (tester) async {
      // Test mobile size
      await tester.binding.setSurfaceSize(const Size(400, 800));
      
      await tester.pumpWidget(
        MaterialApp(
          home: ResponsiveBuilder(
            builder: (context, screenSize) {
              expect(screenSize, equals(ScreenSize.mobile));
              return Text('Size: ${screenSize.name}');
            },
          ),
        ),
      );
      
      await tester.pump();
      expect(find.text('Size: mobile'), findsOneWidget);
      
      // Test tablet size
      await tester.binding.setSurfaceSize(const Size(700, 1000));
      await tester.pumpWidget(
        MaterialApp(
          home: ResponsiveBuilder(
            builder: (context, screenSize) {
              expect(screenSize, equals(ScreenSize.tablet));
              return Text('Size: ${screenSize.name}');
            },
          ),
        ),
      );
      
      await tester.pump();
      expect(find.text('Size: tablet'), findsOneWidget);
      
      // Test desktop size
      await tester.binding.setSurfaceSize(const Size(1000, 800));
      await tester.pumpWidget(
        MaterialApp(
          home: ResponsiveBuilder(
            builder: (context, screenSize) {
              expect(screenSize, equals(ScreenSize.desktop));
              return Text('Size: ${screenSize.name}');
            },
          ),
        ),
      );
      
      await tester.pump();
      expect(find.text('Size: desktop'), findsOneWidget);
      
      // Reset surface size
      await tester.binding.setSurfaceSize(null);
    });
  });
}
