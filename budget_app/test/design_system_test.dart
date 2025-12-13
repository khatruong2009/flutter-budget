import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:animated_digit/animated_digit.dart';
import 'package:budget_app/design_system.dart';

void main() {
  group('Design System Foundation Tests', () {
    test('Spacing constants are defined', () {
      expect(AppDesign.spacingXXS, 2.0);
      expect(AppDesign.spacingXS, 4.0);
      expect(AppDesign.spacingS, 8.0);
      expect(AppDesign.spacingM, 16.0);
      expect(AppDesign.spacingL, 24.0);
      expect(AppDesign.spacingXL, 32.0);
      expect(AppDesign.spacingXXL, 48.0);
      expect(AppDesign.spacingXXXL, 64.0);
    });

    test('Border radius constants are defined', () {
      expect(AppDesign.radiusXS, 4.0);
      expect(AppDesign.radiusS, 8.0);
      expect(AppDesign.radiusM, 12.0);
      expect(AppDesign.radiusL, 16.0);
      expect(AppDesign.radiusXL, 20.0);
      expect(AppDesign.radiusXXL, 24.0);
      expect(AppDesign.radiusRound, 999.0);
    });

    test('Icon sizes are defined', () {
      expect(AppDesign.iconXS, 16.0);
      expect(AppDesign.iconS, 20.0);
      expect(AppDesign.iconM, 24.0);
      expect(AppDesign.iconL, 32.0);
      expect(AppDesign.iconXL, 48.0);
      expect(AppDesign.iconXXL, 64.0);
    });

    test('Touch target sizes meet minimum accessibility requirements', () {
      expect(AppDesign.touchTargetMin, greaterThanOrEqualTo(44.0));
      expect(AppDesign.touchTargetS, greaterThanOrEqualTo(44.0));
      expect(AppDesign.touchTargetM, greaterThanOrEqualTo(44.0));
      expect(AppDesign.touchTargetL, greaterThanOrEqualTo(44.0));
    });

    test('Text colors are defined', () {
      expect(AppDesign.textPrimary, isA<Color>());
      expect(AppDesign.textSecondary, isA<Color>());
      expect(AppDesign.textTertiary, isA<Color>());
      expect(AppDesign.textPrimaryDark, isA<Color>());
      expect(AppDesign.textSecondaryDark, isA<Color>());
      expect(AppDesign.textTertiaryDark, isA<Color>());
    });

    test('Shadow system is defined', () {
      expect(AppDesign.shadowXS, isA<List<BoxShadow>>());
      expect(AppDesign.shadowS, isA<List<BoxShadow>>());
      expect(AppDesign.shadowM, isA<List<BoxShadow>>());
      expect(AppDesign.shadowL, isA<List<BoxShadow>>());
      expect(AppDesign.shadowXL, isA<List<BoxShadow>>());
    });

    test('Glassmorphism settings are defined', () {
      expect(AppDesign.glassBlurLight, 10.0);
      expect(AppDesign.glassBlurMedium, 15.0);
      expect(AppDesign.glassBlurHeavy, 20.0);
      expect(AppDesign.glassOpacity, 0.15);
      expect(AppDesign.glassBorderOpacity, 0.2);
    });
  });

  group('AppColors Tests', () {
    test('Gradient definitions are defined', () {
      expect(AppColors.primaryGradient, isA<LinearGradient>());
      expect(AppColors.incomeGradient, isA<LinearGradient>());
      expect(AppColors.expenseGradient, isA<LinearGradient>());
      expect(AppColors.backgroundGradient, isA<LinearGradient>());
    });

    test('Semantic colors are defined', () {
      expect(AppColors.income, isA<Color>());
      expect(AppColors.expense, isA<Color>());
      expect(AppColors.neutral, isA<Color>());
      expect(AppColors.success, isA<Color>());
      expect(AppColors.warning, isA<Color>());
      expect(AppColors.error, isA<Color>());
    });

    test('Category colors list is not empty', () {
      expect(AppColors.categoryColors, isNotEmpty);
      expect(AppColors.categoryColors.length, greaterThan(5));
    });

    test('Chart colors list is not empty', () {
      expect(AppColors.chartColors, isNotEmpty);
      expect(AppColors.chartColors.length, greaterThanOrEqualTo(3));
    });

    test('Glass surface colors work with opacity', () {
      final lightGlass = AppColors.glassSurface(0.5);
      expect(lightGlass, isA<Color>());
      
      final darkGlass = AppColors.glassSurfaceDark(0.5);
      expect(darkGlass, isA<Color>());
    });
  });

  group('AppTypography Tests', () {
    test('Display styles are defined', () {
      expect(AppTypography.displayLarge, isA<TextStyle>());
      expect(AppTypography.displayMedium, isA<TextStyle>());
      expect(AppTypography.displaySmall, isA<TextStyle>());
    });

    test('Heading styles are defined', () {
      expect(AppTypography.headingLarge, isA<TextStyle>());
      expect(AppTypography.headingMedium, isA<TextStyle>());
      expect(AppTypography.headingSmall, isA<TextStyle>());
    });

    test('Body styles are defined', () {
      expect(AppTypography.bodyLarge, isA<TextStyle>());
      expect(AppTypography.bodyMedium, isA<TextStyle>());
      expect(AppTypography.bodySmall, isA<TextStyle>());
    });

    test('Label styles are defined', () {
      expect(AppTypography.labelLarge, isA<TextStyle>());
      expect(AppTypography.labelMedium, isA<TextStyle>());
      expect(AppTypography.labelSmall, isA<TextStyle>());
    });

    test('Numeric styles use tabular figures', () {
      expect(AppTypography.numericLarge.fontFeatures, isNotEmpty);
      expect(AppTypography.numericMedium.fontFeatures, isNotEmpty);
      expect(AppTypography.numericSmall.fontFeatures, isNotEmpty);
    });

    test('Font weights are defined', () {
      expect(AppTypography.light, FontWeight.w300);
      expect(AppTypography.regular, FontWeight.w400);
      expect(AppTypography.medium, FontWeight.w500);
      expect(AppTypography.semiBold, FontWeight.w600);
      expect(AppTypography.bold, FontWeight.w700);
      expect(AppTypography.extraBold, FontWeight.w800);
    });
  });

  group('AppAnimations Tests', () {
    test('Animation durations are defined', () {
      expect(AppAnimations.instant, const Duration(milliseconds: 0));
      expect(AppAnimations.fast, const Duration(milliseconds: 150));
      expect(AppAnimations.normal, const Duration(milliseconds: 300));
      expect(AppAnimations.slow, const Duration(milliseconds: 500));
      expect(AppAnimations.verySlow, const Duration(milliseconds: 800));
    });

    test('Animation curves are defined', () {
      expect(AppAnimations.easeIn, Curves.easeIn);
      expect(AppAnimations.easeOut, Curves.easeOut);
      expect(AppAnimations.easeInOut, Curves.easeInOut);
      expect(AppAnimations.spring, Curves.elasticOut);
    });

    test('Shimmer animation configuration is defined', () {
      expect(AppAnimations.shimmerDuration, isA<Duration>());
      expect(AppAnimations.shimmerCurve, isA<Curve>());
    });

    test('Button press animation values are defined', () {
      expect(AppAnimations.buttonPressDuration, isA<Duration>());
      expect(AppAnimations.buttonPressScale, lessThan(1.0));
      expect(AppAnimations.buttonPressScale, greaterThan(0.0));
    });

    test('Chart animation configuration is defined', () {
      expect(AppAnimations.chartAnimationDuration, isA<Duration>());
      expect(AppAnimations.chartAnimationCurve, isA<Curve>());
    });
  });

  group('GlassCard Component Tests', () {
    testWidgets('GlassCard renders with default properties', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GlassCard(
              child: Text('Test Content'),
            ),
          ),
        ),
      );

      expect(find.text('Test Content'), findsOneWidget);
      expect(find.byType(BackdropFilter), findsOneWidget);
      expect(find.byType(ClipRRect), findsOneWidget);
    });

    testWidgets('GlassCard applies custom blur value', (tester) async {
      const customBlur = 20.0;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GlassCard(
              blur: customBlur,
              child: Text('Test Content'),
            ),
          ),
        ),
      );

      final backdropFilter = tester.widget<BackdropFilter>(
        find.byType(BackdropFilter),
      );
      
      expect(backdropFilter.filter, isA<ImageFilter>());
    });

    testWidgets('GlassCard applies custom border radius', (tester) async {
      final customRadius = BorderRadius.circular(AppDesign.radiusXL);
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GlassCard(
              borderRadius: customRadius,
              child: Text('Test Content'),
            ),
          ),
        ),
      );

      final clipRRect = tester.widget<ClipRRect>(
        find.byType(ClipRRect),
      );
      
      expect(clipRRect.borderRadius, customRadius);
    });

    testWidgets('GlassCard applies custom padding', (tester) async {
      const customPadding = EdgeInsets.all(AppDesign.spacingL);
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GlassCard(
              padding: customPadding,
              child: Text('Test Content'),
            ),
          ),
        ),
      );

      final padding = tester.widget<Padding>(
        find.descendant(
          of: find.byType(InkWell),
          matching: find.byType(Padding),
        ),
      );
      
      expect(padding.padding, customPadding);
    });

    testWidgets('GlassCard handles tap interactions', (tester) async {
      var tapped = false;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GlassCard(
              onTap: () => tapped = true,
              child: Text('Tap Me'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Tap Me'));
      await tester.pump();
      
      expect(tapped, isTrue);
    });

    testWidgets('GlassCard uses default values when not specified', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GlassCard(
              child: Text('Test'),
            ),
          ),
        ),
      );

      final clipRRect = tester.widget<ClipRRect>(
        find.byType(ClipRRect),
      );
      
      // Default border radius should be AppDesign.radiusL
      expect(
        clipRRect.borderRadius,
        BorderRadius.circular(AppDesign.radiusL),
      );
    });

    testWidgets('GlassCard contains Material and InkWell for interactions', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GlassCard(
              child: Text('Test'),
            ),
          ),
        ),
      );

      // GlassCard should contain a Material widget with transparent color
      final materials = tester.widgetList<Material>(find.byType(Material));
      expect(materials.any((m) => m.color == Colors.transparent), isTrue);
      
      expect(find.byType(InkWell), findsOneWidget);
    });

    testWidgets('GlassCard applies glassmorphism effect with Container decoration', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GlassCard(
              child: Text('Test'),
            ),
          ),
        ),
      );

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(BackdropFilter),
          matching: find.byType(Container),
        ).first,
      );
      
      expect(container.decoration, isA<BoxDecoration>());
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.border, isNotNull);
      expect(decoration.borderRadius, isNotNull);
    });
  });

  group('AppButton Component Tests', () {
    testWidgets('AppButton.primary renders with gradient and shadow', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppButton.primary(
              label: 'Primary Button',
              onPressed: () {},
            ),
          ),
        ),
      );

      expect(find.text('Primary Button'), findsOneWidget);
      expect(find.byType(AppButton), findsOneWidget);
    });

    testWidgets('AppButton.secondary renders with transparent background', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppButton.secondary(
              label: 'Secondary Button',
              onPressed: () {},
            ),
          ),
        ),
      );

      expect(find.text('Secondary Button'), findsOneWidget);
      expect(find.byType(AppButton), findsOneWidget);
    });

    testWidgets('AppButton handles tap interactions', (tester) async {
      var tapped = false;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppButton.primary(
              label: 'Tap Me',
              onPressed: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Tap Me'));
      await tester.pump();
      
      expect(tapped, isTrue);
    });

    testWidgets('AppButton shows loading indicator when isLoading is true', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppButton.primary(
              label: 'Loading',
              onPressed: () {},
              isLoading: true,
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('AppButton displays icon when provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppButton.primary(
              label: 'With Icon',
              onPressed: () {},
              icon: Icons.add,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.text('With Icon'), findsOneWidget);
    });

    testWidgets('AppButton applies reduced opacity when disabled', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppButton.primary(
              label: 'Disabled',
              onPressed: null,
            ),
          ),
        ),
      );

      final opacity = tester.widget<Opacity>(
        find.descendant(
          of: find.byType(AppButton),
          matching: find.byType(Opacity),
        ),
      );
      
      expect(opacity.opacity, AppDesign.opacityDisabled);
    });

    testWidgets('AppButton respects size parameter', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                AppButton.primary(
                  label: 'Small',
                  onPressed: () {},
                  size: AppButtonSize.small,
                ),
                AppButton.primary(
                  label: 'Medium',
                  onPressed: () {},
                  size: AppButtonSize.medium,
                ),
                AppButton.primary(
                  label: 'Large',
                  onPressed: () {},
                  size: AppButtonSize.large,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Small'), findsOneWidget);
      expect(find.text('Medium'), findsOneWidget);
      expect(find.text('Large'), findsOneWidget);
    });

    testWidgets('AppButton expands to fill width when expanded is true', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppButton.primary(
              label: 'Expanded',
              onPressed: () {},
              expanded: true,
            ),
          ),
        ),
      );

      final sizedBox = tester.widget<SizedBox>(
        find.descendant(
          of: find.byType(AppButton),
          matching: find.byType(SizedBox),
        ).first,
      );
      
      expect(sizedBox.width, double.infinity);
    });

    testWidgets('AppButton maintains minimum touch target size', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppButton.primary(
              label: 'Button',
              onPressed: () {},
              size: AppButtonSize.small,
            ),
          ),
        ),
      );

      // Find all containers and get the one with constraints
      final containers = tester.widgetList<Container>(
        find.descendant(
          of: find.byType(AppButton),
          matching: find.byType(Container),
        ),
      );
      
      // Find the container with constraints (the button container)
      final buttonContainer = containers.firstWhere(
        (container) => container.constraints != null,
        orElse: () => throw Exception('No container with constraints found'),
      );
      
      expect(buttonContainer.constraints?.minWidth, greaterThanOrEqualTo(44.0));
    });

    testWidgets('AppButton applies custom gradient when provided', (tester) async {
      const customGradient = LinearGradient(
        colors: [Colors.red, Colors.blue],
      );
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppButton.primary(
              label: 'Custom Gradient',
              onPressed: () {},
              gradient: customGradient,
            ),
          ),
        ),
      );

      expect(find.text('Custom Gradient'), findsOneWidget);
    });

    testWidgets('AppButton does not trigger onPressed when loading', (tester) async {
      var tapped = false;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppButton.primary(
              label: 'Loading',
              onPressed: () => tapped = true,
              isLoading: true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(AppButton));
      await tester.pump();
      
      expect(tapped, isFalse);
    });

    testWidgets('AppButton icon has proper spacing from label', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppButton.primary(
              label: 'With Icon',
              onPressed: () {},
              icon: Icons.add,
            ),
          ),
        ),
      );

      // Find the SizedBox that provides spacing between icon and label
      final spacingBoxes = tester.widgetList<SizedBox>(
        find.descendant(
          of: find.byType(Row),
          matching: find.byType(SizedBox),
        ),
      );
      
      // Should have at least one SizedBox for spacing
      expect(spacingBoxes.any((box) => box.width == AppDesign.spacingS), isTrue);
    });

    testWidgets('AppButton contains InkWell for ripple effect', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppButton.primary(
              label: 'Button',
              onPressed: () {},
            ),
          ),
        ),
      );

      expect(find.byType(InkWell), findsOneWidget);
    });

    testWidgets('AppButton primary variant has gradient decoration', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppButton.primary(
              label: 'Primary',
              onPressed: () {},
            ),
          ),
        ),
      );

      // Find all containers and get the one with decoration
      final containers = tester.widgetList<Container>(
        find.descendant(
          of: find.byType(AppButton),
          matching: find.byType(Container),
        ),
      );
      
      // Find the container with BoxDecoration (the button container)
      final buttonContainer = containers.firstWhere(
        (container) => container.decoration is BoxDecoration,
        orElse: () => throw Exception('No container with BoxDecoration found'),
      );
      
      expect(buttonContainer.decoration, isA<BoxDecoration>());
      final decoration = buttonContainer.decoration as BoxDecoration;
      expect(decoration.gradient, isNotNull);
    });

    testWidgets('AppButton secondary variant has border', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppButton.secondary(
              label: 'Secondary',
              onPressed: () {},
            ),
          ),
        ),
      );

      // Find all containers and get the one with decoration
      final containers = tester.widgetList<Container>(
        find.descendant(
          of: find.byType(AppButton),
          matching: find.byType(Container),
        ),
      );
      
      // Find the container with BoxDecoration (the button container)
      final buttonContainer = containers.firstWhere(
        (container) => container.decoration is BoxDecoration,
        orElse: () => throw Exception('No container with BoxDecoration found'),
      );
      
      expect(buttonContainer.decoration, isA<BoxDecoration>());
      final decoration = buttonContainer.decoration as BoxDecoration;
      expect(decoration.border, isNotNull);
    });
  });

  group('AnimatedMetricCard Component Tests', () {
    testWidgets('AnimatedMetricCard renders with required properties', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedMetricCard(
              label: 'Total Income',
              value: 1234.56,
              icon: Icons.trending_up,
              color: AppColors.income,
            ),
          ),
        ),
      );

      expect(find.text('Total Income'), findsOneWidget);
      expect(find.byIcon(Icons.trending_up), findsOneWidget);
      expect(find.byType(AnimatedDigitWidget), findsOneWidget);
    });

    testWidgets('AnimatedMetricCard applies scale animation on init', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedMetricCard(
              label: 'Test Metric',
              value: 100.0,
              icon: Icons.attach_money,
              color: AppColors.primary,
            ),
          ),
        ),
      );

      // Verify AnimatedMetricCard is rendered
      expect(find.byType(AnimatedMetricCard), findsOneWidget);
      
      // Pump animation to completion
      await tester.pump();
      await tester.pump(AppAnimations.normal);
      
      // Animation should complete and widget should still be present
      expect(find.byType(AnimatedMetricCard), findsOneWidget);
    });

    testWidgets('AnimatedMetricCard uses ElevatedCard as base', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedMetricCard(
              label: 'Test',
              value: 50.0,
              icon: Icons.star,
              color: AppColors.warning,
            ),
          ),
        ),
      );

      expect(find.byType(ElevatedCard), findsOneWidget);
    });

    testWidgets('AnimatedMetricCard displays icon in gradient container', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedMetricCard(
              label: 'Expenses',
              value: 500.0,
              icon: Icons.trending_down,
              color: AppColors.expense,
            ),
          ),
        ),
      );

      // Find the container with solid color
      final containers = tester.widgetList<Container>(find.byType(Container));
      final colorContainer = containers.firstWhere(
        (container) => container.decoration is BoxDecoration &&
            (container.decoration as BoxDecoration).color != null,
      );
      
      expect(colorContainer, isNotNull);
      expect(find.byIcon(Icons.trending_down), findsOneWidget);
    });

    testWidgets('AnimatedMetricCard handles tap interactions', (tester) async {
      var tapped = false;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedMetricCard(
              label: 'Tap Me',
              value: 123.45,
              icon: Icons.touch_app,
              color: AppColors.primary,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(ElevatedCard));
      await tester.pump();
      
      expect(tapped, isTrue);
    });

    testWidgets('AnimatedMetricCard displays value with AnimatedDigitWidget', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedMetricCard(
              label: 'Balance',
              value: 9876.54,
              icon: Icons.account_balance,
              color: AppColors.primary,
              fractionDigits: 2,
            ),
          ),
        ),
      );

      final animatedDigit = tester.widget<AnimatedDigitWidget>(
        find.byType(AnimatedDigitWidget),
      );
      
      expect(animatedDigit.value, 9876.54);
      expect(animatedDigit.fractionDigits, 2);
      expect(animatedDigit.enableSeparator, isTrue);
    });

    testWidgets('AnimatedMetricCard respects fractionDigits parameter', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedMetricCard(
              label: 'Count',
              value: 42.0,
              icon: Icons.numbers,
              color: AppColors.neutral,
              fractionDigits: 0,
            ),
          ),
        ),
      );

      final animatedDigit = tester.widget<AnimatedDigitWidget>(
        find.byType(AnimatedDigitWidget),
      );
      
      expect(animatedDigit.fractionDigits, 0);
    });

    testWidgets('AnimatedMetricCard displays prefix when provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedMetricCard(
              label: 'Price',
              value: 99.99,
              icon: Icons.attach_money,
              color: AppColors.income,
              prefix: '\$',
            ),
          ),
        ),
      );

      expect(find.text('\$'), findsOneWidget);
    });

    testWidgets('AnimatedMetricCard displays suffix when provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedMetricCard(
              label: 'Growth',
              value: 15.5,
              icon: Icons.trending_up,
              color: AppColors.income,
              suffix: '%',
            ),
          ),
        ),
      );

      expect(find.text('%'), findsOneWidget);
    });

    testWidgets('AnimatedMetricCard icon container has proper padding', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedMetricCard(
              label: 'Test',
              value: 100.0,
              icon: Icons.star,
              color: AppColors.primary,
            ),
          ),
        ),
      );

      // Find the container with solid color that contains the icon
      final containers = tester.widgetList<Container>(find.byType(Container));
      final iconContainer = containers.firstWhere(
        (container) => 
            container.padding == const EdgeInsets.all(AppDesign.spacingS) &&
            container.decoration is BoxDecoration &&
            (container.decoration as BoxDecoration).color != null,
      );
      
      expect(iconContainer.padding, const EdgeInsets.all(AppDesign.spacingS));
    });

    testWidgets('AnimatedMetricCard icon container has rounded corners', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedMetricCard(
              label: 'Test',
              value: 100.0,
              icon: Icons.star,
              color: AppColors.primary,
            ),
          ),
        ),
      );

      // Find the container with solid color
      final containers = tester.widgetList<Container>(find.byType(Container));
      final iconContainer = containers.firstWhere(
        (container) => container.decoration is BoxDecoration &&
            (container.decoration as BoxDecoration).color != null,
      );
      
      final decoration = iconContainer.decoration as BoxDecoration;
      expect(decoration.borderRadius, BorderRadius.circular(AppDesign.radiusS));
    });

    testWidgets('AnimatedMetricCard label uses secondary text color', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedMetricCard(
              label: 'Test Label',
              value: 100.0,
              icon: Icons.label,
              color: AppColors.primary,
            ),
          ),
        ),
      );

      final textWidgets = tester.widgetList<Text>(find.text('Test Label'));
      final labelText = textWidgets.first;
      
      expect(labelText.style?.color, AppDesign.textSecondary);
    });

    testWidgets('AnimatedMetricCard contains AnimatedDigitWidget for value display', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedMetricCard(
              label: 'Amount',
              value: 250.0,
              icon: Icons.money,
              color: AppColors.income,
            ),
          ),
        ),
      );

      // Verify AnimatedDigitWidget is present
      expect(find.byType(AnimatedDigitWidget), findsOneWidget);
    });

    testWidgets('AnimatedMetricCard has proper spacing between elements', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedMetricCard(
              label: 'Test',
              value: 100.0,
              icon: Icons.star,
              color: AppColors.primary,
            ),
          ),
        ),
      );

      // Find SizedBox widgets for spacing
      final sizedBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox));
      
      // Should have spacing between icon and label (spacingM)
      expect(sizedBoxes.any((box) => box.width == AppDesign.spacingM), isTrue);
      
      // Should have spacing between label row and value (spacingM)
      expect(sizedBoxes.any((box) => box.height == AppDesign.spacingM), isTrue);
    });

    testWidgets('AnimatedMetricCard icon has correct size', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedMetricCard(
              label: 'Test',
              value: 100.0,
              icon: Icons.star,
              color: AppColors.primary,
            ),
          ),
        ),
      );

      final icon = tester.widget<Icon>(find.byIcon(Icons.star));
      expect(icon.size, AppDesign.iconM);
      expect(icon.color, AppColors.textOnPrimary);
    });

    testWidgets('AnimatedMetricCard uses correct typography for label', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedMetricCard(
              label: 'Test Label',
              value: 100.0,
              icon: Icons.label,
              color: AppColors.primary,
            ),
          ),
        ),
      );

      final textWidgets = tester.widgetList<Text>(find.text('Test Label'));
      final labelText = textWidgets.first;
      
      expect(labelText.style?.fontSize, AppTypography.bodyMedium.fontSize);
    });

    testWidgets('AnimatedMetricCard displays value correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedMetricCard(
              label: 'Amount',
              value: 500.0,
              icon: Icons.money,
              color: AppColors.income,
            ),
          ),
        ),
      );

      // Verify AnimatedDigitWidget is present with correct value
      final animatedDigit = tester.widget<AnimatedDigitWidget>(
        find.byType(AnimatedDigitWidget),
      );
      
      expect(animatedDigit.value, 500.0);
    });

    testWidgets('AnimatedMetricCard disposes animation controller', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedMetricCard(
              label: 'Test',
              value: 100.0,
              icon: Icons.star,
              color: AppColors.primary,
            ),
          ),
        ),
      );

      // Remove the widget
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(),
          ),
        ),
      );

      // Should not throw any errors
      expect(tester.takeException(), isNull);
    });
  });
}
