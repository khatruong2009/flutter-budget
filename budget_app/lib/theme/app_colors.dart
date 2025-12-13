import 'package:flutter/material.dart';

/// AppColors defines the complete color system for the application
/// using solid colors for backgrounds and surfaces, with gradients available for accents
class AppColors {
  // Primary Colors - Solid
  static const Color primary = Color(0xFF6366F1); // Indigo
  static const Color primaryDark = Color(0xFF4F46E5);
  static const Color primaryLight = Color(0xFF818CF8);

  // Semantic Colors - Light Theme (Solid)
  static const Color income = Color(0xFF10B981); // Green
  static const Color incomeDark = Color(0xFF059669);
  static const Color incomeLight = Color(0xFF34D399);

  static const Color expense = Color(0xFFEF4444); // Red
  static const Color expenseDark = Color(0xFFDC2626);
  static const Color expenseLight = Color(0xFFF87171);

  static const Color neutral = Color(0xFF3B82F6); // Blue
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Semantic Colors - Dark Theme (Solid)
  static const Color incomeDarkTheme = Color(0xFF34D399);
  static const Color expenseDarkTheme = Color(0xFFF87171);
  static const Color neutralDarkTheme = Color(0xFF60A5FA);
  static const Color successDarkTheme = Color(0xFF34D399);
  static const Color warningDarkTheme = Color(0xFFFBBF24);
  static const Color errorDarkTheme = Color(0xFFF87171);
  static const Color infoDarkTheme = Color(0xFF60A5FA);

  // Surface Colors (Light Theme) - Solid
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color backgroundLight = Color(0xFFF9FAFB);
  static const Color cardLight = Color(0xFFFFFFFF);

  // Surface Colors (Dark Theme) - Solid
  static const Color surfaceDark = Color(0xFF1F2937);
  static const Color backgroundDark = Color(0xFF111827);
  static const Color cardDark = Color(0xFF374151);

  // Text Colors - Light Theme
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9CA3AF);
  static const Color textOnPrimary = Colors.white;

  // Text Colors - Dark Theme
  static const Color textPrimaryDark = Color(0xFFF9FAFB);
  static const Color textSecondaryDark = Color(0xFFD1D5DB);
  static const Color textTertiaryDark = Color(0xFF9CA3AF);
  static const Color textOnPrimaryDark = Color(0xFF111827);

  // Border Colors
  static const Color borderLight = Color(0xFFE5E7EB);
  static const Color borderDark = Color(0xFF4B5563);

  // Gradient Definitions (kept for accents and special effects)
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
  );

  static const LinearGradient incomeGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF10B981), Color(0xFF34D399)],
  );

  static const LinearGradient expenseGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFEF4444), Color(0xFFF87171)],
  );

  // Dark mode gradient variants
  static const LinearGradient primaryGradientDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
  );

  static const LinearGradient incomeGradientDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF059669), Color(0xFF10B981)],
  );

  static const LinearGradient expenseGradientDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFDC2626), Color(0xFFEF4444)],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF59E0B), Color(0xFFF97316)],
  );

  static const LinearGradient accentGradientDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFBBF24), Color(0xFFFB923C)],
  );

  static const LinearGradient neutralGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF3B82F6), Color(0xFF60A5FA)],
  );

  static const LinearGradient neutralGradientDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
  );

  // Category Colors (solid colors for icons and charts)
  static const List<Color> categoryColors = [
    Color(0xFF6366F1), // Indigo
    Color(0xFF8B5CF6), // Purple
    Color(0xFF10B981), // Green
    Color(0xFF34D399), // Light Green
    Color(0xFFEF4444), // Red
    Color(0xFFF87171), // Light Red
    Color(0xFFF59E0B), // Amber
    Color(0xFFFBBF24), // Yellow
    Color(0xFF3B82F6), // Blue
    Color(0xFF60A5FA), // Light Blue
    Color(0xFFEC4899), // Pink
    Color(0xFFF472B6), // Light Pink
    Color(0xFF14B8A6), // Teal
    Color(0xFF2DD4BF), // Light Teal
  ];

  // Chart Colors (solid colors for charts)
  static List<Color> get chartColors => categoryColors;

  static List<Color> getChartColors(bool isDark) {
    // Use slightly lighter variants for dark mode
    if (isDark) {
      return [
        const Color(0xFF818CF8), // Lighter Indigo
        const Color(0xFFA78BFA), // Lighter Purple
        const Color(0xFF34D399), // Lighter Green
        const Color(0xFF6EE7B7), // Even Lighter Green
        const Color(0xFFF87171), // Lighter Red
        const Color(0xFFFCA5A5), // Even Lighter Red
        const Color(0xFFFBBF24), // Lighter Amber
        const Color(0xFFFCD34D), // Lighter Yellow
        const Color(0xFF60A5FA), // Lighter Blue
        const Color(0xFF93C5FD), // Even Lighter Blue
        const Color(0xFFF472B6), // Lighter Pink
        const Color(0xFFF9A8D4), // Even Lighter Pink
        const Color(0xFF2DD4BF), // Lighter Teal
        const Color(0xFF5EEAD4), // Even Lighter Teal
      ];
    }
    return chartColors;
  }

  // Helper methods to get theme-aware colors
  static Color getBackground(bool isDark) {
    return isDark ? backgroundDark : backgroundLight;
  }

  static Color getSurface(bool isDark) {
    return isDark ? surfaceDark : surfaceLight;
  }

  static Color getCard(bool isDark) {
    return isDark ? cardDark : cardLight;
  }

  static Color getBorder(bool isDark) {
    return isDark ? borderDark : borderLight;
  }

  // Helper methods to get theme-aware gradients (for accents)
  static LinearGradient getPrimaryGradient(bool isDark) {
    return isDark ? primaryGradientDark : primaryGradient;
  }

  static LinearGradient getIncomeGradient(bool isDark) {
    return isDark ? incomeGradientDark : incomeGradient;
  }

  static LinearGradient getExpenseGradient(bool isDark) {
    return isDark ? expenseGradientDark : expenseGradient;
  }

  static LinearGradient getAccentGradient(bool isDark) {
    return isDark ? accentGradientDark : accentGradient;
  }

  static LinearGradient getNeutralGradient(bool isDark) {
    return isDark ? neutralGradientDark : neutralGradient;
  }

  // Helper method to get semantic color based on theme
  static Color getIncome(bool isDark) {
    return isDark ? incomeDarkTheme : income;
  }

  static Color getExpense(bool isDark) {
    return isDark ? expenseDarkTheme : expense;
  }

  static Color getNeutral(bool isDark) {
    return isDark ? neutralDarkTheme : neutral;
  }

  static Color getSuccess(bool isDark) {
    return isDark ? successDarkTheme : success;
  }

  static Color getWarning(bool isDark) {
    return isDark ? warningDarkTheme : warning;
  }

  static Color getError(bool isDark) {
    return isDark ? errorDarkTheme : error;
  }

  static Color getInfo(bool isDark) {
    return isDark ? infoDarkTheme : info;
  }

  // Deprecated: Use solid colors instead
  // Kept for backward compatibility during migration
  @Deprecated('Use getBackground() instead')
  static LinearGradient getBackgroundGradient(bool isDark) {
    return isDark ? primaryGradientDark : primaryGradient;
  }

  @Deprecated('Use getCard() instead')
  static LinearGradient getCardGradient(bool isDark) {
    return isDark ? accentGradientDark : accentGradient;
  }

  @Deprecated('Use getChartColors() instead')
  static List<LinearGradient> getChartGradients(bool isDark) {
    return isDark ? [primaryGradientDark] : [primaryGradient];
  }

  // Deprecated glassmorphism helpers - kept for backward compatibility
  @Deprecated('Use solid colors instead')
  static Color glassSurface(double opacity) =>
      Colors.white.withValues(alpha: opacity);
  
  @Deprecated('Use solid colors instead')
  static Color glassSurfaceDark(double opacity) =>
      Colors.black.withValues(alpha: opacity);

  @Deprecated('Use solid colors instead')
  static Color glassBorder(double opacity) =>
      Colors.white.withValues(alpha: opacity);
  
  @Deprecated('Use solid colors instead')
  static Color glassBorderDark(double opacity) =>
      Colors.white.withValues(alpha: opacity * 0.5);

  // Deprecated gradient properties - kept for backward compatibility
  @Deprecated('Use solid colors instead')
  static const LinearGradient backgroundGradient = primaryGradient;
  
  @Deprecated('Use solid colors instead')
  static const LinearGradient backgroundGradientDark = primaryGradientDark;
  
  @Deprecated('Use solid colors instead')
  static const LinearGradient cardGradient = accentGradient;
  
  @Deprecated('Use solid colors instead')
  static const LinearGradient cardGradientDark = accentGradientDark;

  @Deprecated('Use categoryColors instead')
  static List<LinearGradient> get chartGradients => [primaryGradient, incomeGradient, expenseGradient];

  @Deprecated('Use categoryColors instead')
  static List<LinearGradient> get chartGradientsDark => [primaryGradientDark, incomeGradientDark, expenseGradientDark];

  // Opacity Scales
  static const double opacityHigh = 0.87;
  static const double opacityMedium = 0.60;
  static const double opacityLow = 0.38;
  static const double opacityDisabled = 0.38;
  @Deprecated('Use opacityLow instead')
  static const double opacityGlass = 0.15;
  @Deprecated('Use opacityLow instead')
  static const double opacityGlassBorder = 0.2;
}
