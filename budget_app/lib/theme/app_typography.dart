import 'package:flutter/material.dart';

/// AppTypography defines the complete typography system for the application
/// with consistent font sizes, weights, and line heights
class AppTypography {
  // Primary family: Gabarito (bundled). Secondary: Spline Sans Mono for
  // eyebrows, mono labels, and chart axes.
  static const String fontFamily = 'Gabarito';
  static const String monoFontFamily = 'SplineSansMono';

  // ===== Budgie dark redesign styles =====

  /// Hero number, e.g. `$2,321` on Home (58/800, ls -2).
  static const TextStyle hero = TextStyle(
    fontFamily: fontFamily,
    fontSize: 58,
    fontWeight: FontWeight.w800,
    letterSpacing: -2,
    height: 1.0,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Hero decimals, e.g. `.58` (32/700, secondary color).
  static const TextStyle heroDecimals = TextStyle(
    fontFamily: fontFamily,
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 1.0,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Net worth hero (48/800, ls -1.8).
  static const TextStyle heroMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 48,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.8,
    height: 1.0,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Donut center / summary amounts (34/800, ls -1).
  static const TextStyle heroSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 34,
    fontWeight: FontWeight.w800,
    letterSpacing: -1,
    height: 1.1,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Page title, e.g. `Net worth` (26/800, ls -0.6).
  static const TextStyle pageTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 26,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.6,
    height: 1.2,
  );

  /// Section header, e.g. `Budgets` (20/700, ls -0.3).
  static const TextStyle sectionHeader = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    height: 1.2,
  );

  /// Card title, e.g. `Growth` (17/700).
  static const TextStyle cardTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 17,
    fontWeight: FontWeight.w700,
    height: 1.25,
  );

  /// Goal card title (18/700, ls -0.3).
  static const TextStyle goalTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    height: 1.25,
  );

  /// List row title (15/600).
  static const TextStyle rowTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.25,
  );

  /// List row subtitle (12/400, secondary color at call site).
  static const TextStyle rowSubtitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.25,
  );

  /// Row amount (16/700 tabular).
  static const TextStyle amount = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    height: 1.2,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Transaction row amount (15/700 tabular).
  static const TextStyle amountSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w700,
    height: 1.2,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Stat chip amount, e.g. `$8,240` (24/700, ls -0.5).
  static const TextStyle chipAmount = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    height: 1.15,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Metric chip amount, e.g. `$1,376` on Cash Flow (24/800, ls -0.5).
  static const TextStyle metricAmount = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
    height: 1.15,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Pill badge text, e.g. `$61 over` (12/700).
  static const TextStyle badge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );

  /// Small pill badge, e.g. `On track` (11/700).
  static const TextStyle badgeSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );

  /// Mono eyebrow, e.g. `SAFE TO SPEND` (11/600, ls 2.4, uppercase).
  static const TextStyle eyebrow = TextStyle(
    fontFamily: monoFontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 2.4,
    height: 1.2,
  );

  /// Mono section eyebrow with tighter tracking, e.g. `SAVED SO FAR` (ls 2).
  static const TextStyle eyebrowTight = TextStyle(
    fontFamily: monoFontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 2,
    height: 1.2,
  );

  /// Mono label, e.g. `SPENT $5,918` under the gauge (11/500, ls 1).
  static const TextStyle monoLabel = TextStyle(
    fontFamily: monoFontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 1,
    height: 1.2,
  );

  /// Mono accent link, e.g. `EDIT` / `SEE ALL` (11/600, ls 1.5).
  static const TextStyle monoLink = TextStyle(
    fontFamily: monoFontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.5,
    height: 1.2,
  );

  /// Mono metric label, e.g. `AVG SAVED / MO` (10/600, ls 1.6).
  static const TextStyle monoMetricLabel = TextStyle(
    fontFamily: monoFontFamily,
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.6,
    height: 1.2,
  );

  /// Mono chart axis label, e.g. `AUG '25` (10/500).
  static const TextStyle monoAxis = TextStyle(
    fontFamily: monoFontFamily,
    fontSize: 10,
    fontWeight: FontWeight.w500,
    height: 1.2,
  );

  /// Mono chart month label, e.g. `FEB` on Cash Flow (11/500).
  static const TextStyle monoMonth = TextStyle(
    fontFamily: monoFontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.2,
  );

  // Display Styles (Large headings)
  static const TextStyle displayLarge = TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.bold,
    letterSpacing: -0.5,
    height: 1.2,
  );

  static const TextStyle displayMedium = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    letterSpacing: -0.3,
    height: 1.2,
  );

  static const TextStyle displaySmall = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    letterSpacing: -0.2,
    height: 1.3,
  );

  // Heading Styles
  static const TextStyle headingLarge = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    letterSpacing: -0.3,
    height: 1.2,
  );

  static const TextStyle headingMedium = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    height: 1.3,
  );

  static const TextStyle headingSmall = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
    height: 1.3,
  );

  // Body Styles
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.4,
    height: 1.5,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.2,
    height: 1.5,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.1,
    height: 1.4,
  );

  // Label Styles (for buttons, tabs, etc.)
  static const TextStyle labelLarge = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.4,
    height: 1.3,
  );

  static const TextStyle labelMedium = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    height: 1.3,
  );

  static const TextStyle labelSmall = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
    height: 1.3,
  );

  // Caption Styles (small secondary text)
  static const TextStyle caption = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.1,
    height: 1.4,
  );

  static const TextStyle captionSmall = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.3,
  );

  // Numeric Styles (for financial data)
  static const TextStyle numericLarge = TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.bold,
    letterSpacing: -0.5,
    height: 1.2,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const TextStyle numericMedium = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    height: 1.3,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const TextStyle numericSmall = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.4,
    height: 1.3,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  // Button Text Styles
  static const TextStyle buttonLarge = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.4,
    height: 1.2,
  );

  static const TextStyle buttonMedium = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    height: 1.2,
  );

  static const TextStyle buttonSmall = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
    height: 1.2,
  );

  // Font Weights
  static const FontWeight light = FontWeight.w300;
  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semiBold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;
  static const FontWeight extraBold = FontWeight.w800;
}
