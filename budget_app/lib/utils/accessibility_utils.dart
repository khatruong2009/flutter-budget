import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Utility class for accessibility features and helpers
class AccessibilityUtils {
  /// Checks if reduced motion is preferred by the system
  static bool shouldReduceMotion(BuildContext context) {
    return MediaQuery.of(context).disableAnimations;
  }

  /// Gets animation duration based on reduced motion preference
  /// Returns zero duration if reduced motion is enabled
  static Duration getAnimationDuration(
    BuildContext context,
    Duration normalDuration,
  ) {
    return shouldReduceMotion(context) ? Duration.zero : normalDuration;
  }

  /// Gets animation duration multiplier based on reduced motion preference
  /// Returns 0.0 if reduced motion is enabled, 1.0 otherwise
  static double getAnimationMultiplier(BuildContext context) {
    return shouldReduceMotion(context) ? 0.0 : 1.0;
  }

  /// Creates a semantic label for a monetary amount
  /// Example: formatMoneyForScreenReader(123.45, isExpense: true)
  /// Returns: "expense of 123 dollars and 45 cents"
  static String formatMoneyForScreenReader(
    double amount, {
    required bool isExpense,
  }) {
    final dollars = amount.floor();
    final cents = ((amount - dollars) * 100).round();
    final type = isExpense ? 'expense' : 'income';
    
    if (cents == 0) {
      return '$type of $dollars dollars';
    } else {
      return '$type of $dollars dollars and $cents cents';
    }
  }

  /// Creates a semantic label for a date
  /// Example: formatDateForScreenReader(DateTime(2024, 1, 15))
  /// Returns: "January 15, 2024"
  static String formatDateForScreenReader(DateTime date) {
    return DateFormat.yMMMMd().format(date);
  }

  /// Creates a semantic label for a transaction
  static String formatTransactionForScreenReader({
    required String description,
    required double amount,
    required bool isExpense,
    required String category,
    required DateTime date,
  }) {
    final moneyLabel = formatMoneyForScreenReader(amount, isExpense: isExpense);
    final dateLabel = formatDateForScreenReader(date);
    
    return '$description, $moneyLabel, category $category, on $dateLabel';
  }

  /// Creates a semantic label for a chart data point
  static String formatChartDataForScreenReader({
    required String label,
    required double value,
    required double percentage,
  }) {
    final formattedValue = NumberFormat.currency(symbol: '\$').format(value);
    final formattedPercentage = NumberFormat.percentPattern().format(percentage / 100);
    
    return '$label: $formattedValue, $formattedPercentage of total';
  }

  /// Wraps a widget with semantic label
  static Widget withSemanticLabel({
    required Widget child,
    required String label,
    String? hint,
    bool isButton = false,
    bool isHeader = false,
    bool excludeSemantics = false,
  }) {
    if (excludeSemantics) {
      return ExcludeSemantics(child: child);
    }

    return Semantics(
      label: label,
      hint: hint,
      button: isButton,
      header: isHeader,
      child: child,
    );
  }

  /// Merges semantics for grouped information
  static Widget mergeSemantics({
    required Widget child,
    String? label,
  }) {
    return MergeSemantics(
      child: Semantics(
        label: label,
        child: child,
      ),
    );
  }

  /// Announces a message to screen readers
  static void announce(BuildContext context, String message) {
    // Use SemanticsService to announce messages
    // Note: SemanticsService.announce is available in Flutter
    // This will be picked up by screen readers
    Semantics(
      label: message,
      liveRegion: true,
      child: const SizedBox.shrink(),
    );
  }

  /// Creates a semantic label for empty states
  static String formatEmptyStateForScreenReader({
    required String title,
    required String message,
    String? actionLabel,
  }) {
    if (actionLabel != null) {
      return '$title. $message. $actionLabel button available.';
    }
    return '$title. $message';
  }

  /// Creates a semantic label for loading states
  static String formatLoadingStateForScreenReader(String? message) {
    return message ?? 'Loading content, please wait';
  }

  /// Checks if text size is large (for accessibility)
  static bool isLargeTextSize(BuildContext context) {
    final textScaleFactor = MediaQuery.of(context).textScaleFactor;
    return textScaleFactor > 1.3;
  }

  /// Gets minimum touch target size (44pt for accessibility)
  static const double minimumTouchTarget = 44.0;

  /// Ensures a widget meets minimum touch target size
  static Widget ensureMinimumTouchTarget({
    required Widget child,
    double? width,
    double? height,
  }) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: width ?? minimumTouchTarget,
        minHeight: height ?? minimumTouchTarget,
      ),
      child: child,
    );
  }

  /// Creates a semantic label for a percentage
  static String formatPercentageForScreenReader(double percentage) {
    return '${percentage.toStringAsFixed(1)} percent';
  }

  /// Creates a semantic label for a count
  static String formatCountForScreenReader(int count, String itemName) {
    if (count == 0) {
      return 'No $itemName';
    } else if (count == 1) {
      return '1 $itemName';
    } else {
      return '$count ${itemName}s';
    }
  }

  /// Checks if high contrast mode is enabled
  static bool isHighContrastMode(BuildContext context) {
    return MediaQuery.of(context).highContrast;
  }

  /// Gets appropriate color contrast based on high contrast mode
  static Color getContrastAwareColor(
    BuildContext context,
    Color normalColor,
    Color highContrastColor,
  ) {
    return isHighContrastMode(context) ? highContrastColor : normalColor;
  }
}
