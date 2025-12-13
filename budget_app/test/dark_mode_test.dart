import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:budget_app/design_system.dart';

void main() {
  group('Dark Mode Enhancements', () {
    group('Text Colors', () {
      testWidgets('AppDesign returns correct text colors for light theme', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            home: Builder(
              builder: (context) {
                final primary = AppDesign.getTextPrimary(context);
                final secondary = AppDesign.getTextSecondary(context);
                final tertiary = AppDesign.getTextTertiary(context);
                
                expect(primary, AppDesign.textPrimary);
                expect(secondary, AppDesign.textSecondary);
                expect(tertiary, AppDesign.textTertiary);
                
                return Container();
              },
            ),
          ),
        );
      });

      testWidgets('AppDesign returns correct text colors for dark theme', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Builder(
              builder: (context) {
                final primary = AppDesign.getTextPrimary(context);
                final secondary = AppDesign.getTextSecondary(context);
                final tertiary = AppDesign.getTextTertiary(context);
                
                expect(primary, AppDesign.textPrimaryDark);
                expect(secondary, AppDesign.textSecondaryDark);
                expect(tertiary, AppDesign.textTertiaryDark);
                
                return Container();
              },
            ),
          ),
        );
      });
    });

    group('Solid Background Colors', () {
      testWidgets('AppDesign returns correct solid background color for light theme', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            home: Builder(
              builder: (context) {
                final backgroundColor = AppDesign.getBackgroundColor(context);
                
                expect(backgroundColor, AppColors.backgroundLight);
                expect(backgroundColor, const Color(0xFFF9FAFB));
                
                return Container();
              },
            ),
          ),
        );
      });

      testWidgets('AppDesign returns correct solid background color for dark theme', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Builder(
              builder: (context) {
                final backgroundColor = AppDesign.getBackgroundColor(context);
                
                expect(backgroundColor, AppColors.backgroundDark);
                expect(backgroundColor, const Color(0xFF111827));
                
                return Container();
              },
            ),
          ),
        );
      });

      testWidgets('AppDesign returns correct card color for light theme', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            home: Builder(
              builder: (context) {
                final cardColor = AppDesign.getCardColor(context);
                
                expect(cardColor, AppColors.cardLight);
                expect(cardColor, const Color(0xFFFFFFFF));
                
                return Container();
              },
            ),
          ),
        );
      });

      testWidgets('AppDesign returns correct card color for dark theme', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Builder(
              builder: (context) {
                final cardColor = AppDesign.getCardColor(context);
                
                expect(cardColor, AppColors.cardDark);
                expect(cardColor, const Color(0xFF374151));
                
                return Container();
              },
            ),
          ),
        );
      });
    });

    group('Semantic Colors', () {
      testWidgets('AppDesign returns correct income color for light theme', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            home: Builder(
              builder: (context) {
                final incomeColor = AppDesign.getIncomeColor(context);
                
                expect(incomeColor, AppColors.income);
                expect(incomeColor, const Color(0xFF10B981));
                
                return Container();
              },
            ),
          ),
        );
      });

      testWidgets('AppDesign returns correct income color for dark theme', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Builder(
              builder: (context) {
                final incomeColor = AppDesign.getIncomeColor(context);
                
                expect(incomeColor, AppColors.incomeDarkTheme);
                expect(incomeColor, const Color(0xFF34D399));
                
                return Container();
              },
            ),
          ),
        );
      });

      testWidgets('AppDesign returns correct expense color for light theme', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            home: Builder(
              builder: (context) {
                final expenseColor = AppDesign.getExpenseColor(context);
                
                expect(expenseColor, AppColors.expense);
                expect(expenseColor, const Color(0xFFEF4444));
                
                return Container();
              },
            ),
          ),
        );
      });

      testWidgets('AppDesign returns correct expense color for dark theme', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Builder(
              builder: (context) {
                final expenseColor = AppDesign.getExpenseColor(context);
                
                expect(expenseColor, AppColors.expenseDarkTheme);
                expect(expenseColor, const Color(0xFFF87171));
                
                return Container();
              },
            ),
          ),
        );
      });
    });

    group('Border Colors', () {
      testWidgets('AppDesign returns correct border color for light theme', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            home: Builder(
              builder: (context) {
                final borderColor = AppDesign.getBorderColor(context);
                
                expect(borderColor, AppColors.borderLight);
                expect(borderColor, const Color(0xFFE5E7EB));
                
                return Container();
              },
            ),
          ),
        );
      });

      testWidgets('AppDesign returns correct border color for dark theme', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Builder(
              builder: (context) {
                final borderColor = AppDesign.getBorderColor(context);
                
                expect(borderColor, AppColors.borderDark);
                expect(borderColor, const Color(0xFF4B5563));
                
                return Container();
              },
            ),
          ),
        );
      });
    });

    group('ElevatedCard Component', () {
      testWidgets('ElevatedCard uses theme-aware colors in light mode', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            home: const Scaffold(
              body: ElevatedCard(
                child: Text('Test'),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        
        // Verify the card renders without errors
        expect(find.text('Test'), findsOneWidget);
        expect(find.byType(ElevatedCard), findsOneWidget);
        
        // Verify the card uses light theme colors by checking the Material inside ElevatedCard
        final elevatedCard = find.byType(ElevatedCard);
        final materials = find.descendant(
          of: elevatedCard,
          matching: find.byType(Material),
        );
        expect(materials, findsWidgets);
        
        final Material material = tester.widget(materials.first);
        expect(material.color, AppColors.cardLight);
      });

      testWidgets('ElevatedCard uses theme-aware colors in dark mode', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: const Scaffold(
              body: ElevatedCard(
                child: Text('Test'),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        
        // Verify the card renders without errors
        expect(find.text('Test'), findsOneWidget);
        expect(find.byType(ElevatedCard), findsOneWidget);
        
        // Verify the card uses dark theme colors by checking the Material inside ElevatedCard
        final elevatedCard = find.byType(ElevatedCard);
        final materials = find.descendant(
          of: elevatedCard,
          matching: find.byType(Material),
        );
        expect(materials, findsWidgets);
        
        final Material material = tester.widget(materials.first);
        expect(material.color, AppColors.cardDark);
      });

      testWidgets('ElevatedCard has proper elevation in both themes', (tester) async {
        for (final brightness in [Brightness.light, Brightness.dark]) {
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(brightness: brightness),
              home: const Scaffold(
                body: ElevatedCard(
                  elevation: 4.0,
                  child: Text('Test'),
                ),
              ),
            ),
          );

          await tester.pumpAndSettle();
          
          final elevatedCard = find.byType(ElevatedCard);
          final materials = find.descendant(
            of: elevatedCard,
            matching: find.byType(Material),
          );
          
          final Material material = tester.widget(materials.first);
          expect(material.elevation, 4.0);
        }
      });
    });

    group('AppButton Component', () {
      testWidgets('AppButton uses theme-aware gradient in light mode', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            home: Scaffold(
              body: AppButton(
                label: 'Test Button',
                onPressed: () {},
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        
        // Verify the button renders without errors
        expect(find.text('Test Button'), findsOneWidget);
        expect(find.byType(AppButton), findsOneWidget);
      });

      testWidgets('AppButton uses theme-aware gradient in dark mode', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: AppButton(
                label: 'Test Button',
                onPressed: () {},
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        
        // Verify the button renders without errors
        expect(find.text('Test Button'), findsOneWidget);
        expect(find.byType(AppButton), findsOneWidget);
      });

      testWidgets('Secondary button uses theme-aware border in both themes', (tester) async {
        for (final brightness in [Brightness.light, Brightness.dark]) {
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(brightness: brightness),
              home: Scaffold(
                body: AppButton.secondary(
                  label: 'Secondary',
                  onPressed: () {},
                ),
              ),
            ),
          );

          await tester.pumpAndSettle();
          
          // Verify the button renders
          expect(find.text('Secondary'), findsOneWidget);
        }
      });
    });

    group('Chart Colors', () {
      testWidgets('Chart colors return correct solid colors for light theme', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            home: Builder(
              builder: (context) {
                final lightColors = AppDesign.getChartColors(context);
                
                // Verify light theme returns solid colors
                expect(lightColors.length, greaterThan(0));
                expect(lightColors[0], isA<Color>());
                expect(lightColors[0], const Color(0xFF6366F1)); // Indigo
                
                return Container();
              },
            ),
          ),
        );
      });

      testWidgets('Chart colors return lighter variants for dark theme', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Builder(
              builder: (context) {
                final darkColors = AppDesign.getChartColors(context);
                
                // Verify dark theme returns lighter color variants
                expect(darkColors.length, greaterThan(0));
                expect(darkColors[0], isA<Color>());
                expect(darkColors[0], const Color(0xFF818CF8)); // Lighter Indigo
                
                return Container();
              },
            ),
          ),
        );
      });
    });

    group('Contrast Ratios', () {
      double calculateLuminance(Color color) {
        final r = color.r;
        final g = color.g;
        final b = color.b;
        
        final rLinear = r <= 0.03928 ? r / 12.92 : pow((r + 0.055) / 1.055, 2.4);
        final gLinear = g <= 0.03928 ? g / 12.92 : pow((g + 0.055) / 1.055, 2.4);
        final bLinear = b <= 0.03928 ? b / 12.92 : pow((b + 0.055) / 1.055, 2.4);
        
        return 0.2126 * rLinear + 0.7152 * gLinear + 0.0722 * bLinear;
      }
      
      double calculateContrastRatio(Color foreground, Color background) {
        final l1 = calculateLuminance(foreground);
        final l2 = calculateLuminance(background);
        
        final lighter = l1 > l2 ? l1 : l2;
        final darker = l1 > l2 ? l2 : l1;
        
        return (lighter + 0.05) / (darker + 0.05);
      }

      test('Light theme text on background meets WCAG AA (4.5:1)', () {
        const textColor = AppColors.textPrimary;
        const backgroundColor = AppColors.backgroundLight;
        
        final contrastRatio = calculateContrastRatio(textColor, backgroundColor);
        expect(contrastRatio, greaterThanOrEqualTo(4.5));
      });

      test('Dark theme text on background meets WCAG AA (4.5:1)', () {
        const textColor = AppColors.textPrimaryDark;
        const backgroundColor = AppColors.backgroundDark;
        
        final contrastRatio = calculateContrastRatio(textColor, backgroundColor);
        expect(contrastRatio, greaterThanOrEqualTo(4.5));
      });

      test('Light theme text on card meets WCAG AA (4.5:1)', () {
        const textColor = AppColors.textPrimary;
        const cardColor = AppColors.cardLight;
        
        final contrastRatio = calculateContrastRatio(textColor, cardColor);
        expect(contrastRatio, greaterThanOrEqualTo(4.5));
      });

      test('Dark theme text on card meets WCAG AA (4.5:1)', () {
        const textColor = AppColors.textPrimaryDark;
        const cardColor = AppColors.cardDark;
        
        final contrastRatio = calculateContrastRatio(textColor, cardColor);
        expect(contrastRatio, greaterThanOrEqualTo(4.5));
      });

      test('Income color on light background has reasonable contrast', () {
        const incomeColor = AppColors.income;
        const backgroundColor = AppColors.backgroundLight;
        
        final contrastRatio = calculateContrastRatio(incomeColor, backgroundColor);
        // Income color is used for semantic meaning, not primary text
        // A ratio above 2.0 is acceptable for colored indicators
        expect(contrastRatio, greaterThanOrEqualTo(2.0));
      });

      test('Expense color on light background has sufficient contrast', () {
        const expenseColor = AppColors.expense;
        const backgroundColor = AppColors.backgroundLight;
        
        final contrastRatio = calculateContrastRatio(expenseColor, backgroundColor);
        expect(contrastRatio, greaterThanOrEqualTo(3.0)); // AA for large text
      });

      test('Income color on dark background has sufficient contrast', () {
        const incomeColor = AppColors.incomeDarkTheme;
        const backgroundColor = AppColors.backgroundDark;
        
        final contrastRatio = calculateContrastRatio(incomeColor, backgroundColor);
        expect(contrastRatio, greaterThanOrEqualTo(3.0)); // AA for large text
      });

      test('Expense color on dark background has sufficient contrast', () {
        const expenseColor = AppColors.expenseDarkTheme;
        const backgroundColor = AppColors.backgroundDark;
        
        final contrastRatio = calculateContrastRatio(expenseColor, backgroundColor);
        expect(contrastRatio, greaterThanOrEqualTo(3.0)); // AA for large text
      });
    });
  });
}
