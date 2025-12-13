import 'package:flutter/cupertino.dart';
import '../design_system.dart';
import '../utils/accessibility_utils.dart';

/// EmptyState is a reusable component for displaying empty states
/// with an icon, message, and optional call-to-action button.
/// 
/// Supports different types of empty states:
/// - noData: When there's no data to display
/// - noResults: When a search/filter returns no results
/// - error: When an error has occurred
class EmptyState extends StatelessWidget {
  /// The type of empty state to display
  final EmptyStateType type;
  
  /// Optional custom icon (overrides type default)
  final IconData? icon;
  
  /// Optional custom title (overrides type default)
  final String? title;
  
  /// Optional custom message (overrides type default)
  final String? message;
  
  /// Optional call-to-action button label
  final String? actionLabel;
  
  /// Optional callback when action button is pressed
  final VoidCallback? onAction;
  
  /// Optional icon size (default: AppDesign.iconXXL)
  final double? iconSize;
  
  /// Optional icon color (overrides type default)
  final Color? iconColor;
  
  /// Optional icon gradient (overrides solid color)
  final Gradient? iconGradient;

  const EmptyState({
    super.key,
    required this.type,
    this.icon,
    this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.iconSize,
    this.iconColor,
    this.iconGradient,
  });

  /// Factory constructor for no data state
  factory EmptyState.noData({
    String? title,
    String? message,
    String? actionLabel,
    VoidCallback? onAction,
    IconData? icon,
  }) {
    return EmptyState(
      type: EmptyStateType.noData,
      title: title,
      message: message,
      actionLabel: actionLabel,
      onAction: onAction,
      icon: icon,
    );
  }

  /// Factory constructor for no results state
  factory EmptyState.noResults({
    String? title,
    String? message,
    String? actionLabel,
    VoidCallback? onAction,
    IconData? icon,
  }) {
    return EmptyState(
      type: EmptyStateType.noResults,
      title: title,
      message: message,
      actionLabel: actionLabel,
      onAction: onAction,
      icon: icon,
    );
  }

  /// Factory constructor for error state
  factory EmptyState.error({
    String? title,
    String? message,
    String? actionLabel,
    VoidCallback? onAction,
    IconData? icon,
  }) {
    return EmptyState(
      type: EmptyStateType.error,
      title: title,
      message: message,
      actionLabel: actionLabel,
      onAction: onAction,
      icon: icon,
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveIcon = icon ?? _getDefaultIcon();
    final effectiveTitle = title ?? _getDefaultTitle();
    final effectiveMessage = message ?? _getDefaultMessage();
    final effectiveIconSize = iconSize ?? AppDesign.iconXXL;
    final effectiveIconColor = iconColor ?? _getDefaultIconColor(context);

    // Create semantic label for screen readers
    final semanticLabel = AccessibilityUtils.formatEmptyStateForScreenReader(
      title: effectiveTitle,
      message: effectiveMessage,
      actionLabel: actionLabel,
    );

    return Semantics(
      label: semanticLabel,
      child: Center(
        child: Padding(
          padding: AppDesign.getResponsivePadding(context),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon/Illustration
              ExcludeSemantics(
                // Icon is decorative, exclude from semantics
                child: _buildIcon(
                  context,
                  effectiveIcon,
                  effectiveIconSize,
                  effectiveIconColor,
                ),
              ),
              const SizedBox(height: AppDesign.spacingL),
              
              // Title
              Semantics(
                header: true,
                child: Text(
                  effectiveTitle,
                  style: AppTypography.headingMedium.copyWith(
                    color: AppDesign.getTextPrimary(context),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: AppDesign.spacingS),
              
              // Message
              Text(
                effectiveMessage,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppDesign.getTextSecondary(context),
                ),
                textAlign: TextAlign.center,
              ),
              
              // Action Button
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: AppDesign.spacingXL),
                AppButton.primary(
                  label: actionLabel!,
                  onPressed: onAction,
                  gradient: _getActionGradient(context),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIcon(
    BuildContext context,
    IconData iconData,
    double size,
    Color color,
  ) {
    if (iconGradient != null) {
      // Icon with gradient background container
      return Container(
        width: size * 1.5,
        height: size * 1.5,
        decoration: BoxDecoration(
          gradient: iconGradient,
          borderRadius: BorderRadius.circular(AppDesign.radiusXL),
        ),
        child: Icon(
          iconData,
          size: size,
          color: AppColors.textOnPrimary,
        ),
      );
    } else {
      // Simple icon with solid color
      return Icon(
        iconData,
        size: size,
        color: color,
      );
    }
  }

  IconData _getDefaultIcon() {
    switch (type) {
      case EmptyStateType.noData:
        return CupertinoIcons.tray;
      case EmptyStateType.noResults:
        return CupertinoIcons.search;
      case EmptyStateType.error:
        return CupertinoIcons.exclamationmark_triangle;
    }
  }

  String _getDefaultTitle() {
    switch (type) {
      case EmptyStateType.noData:
        return 'No Data Yet';
      case EmptyStateType.noResults:
        return 'No Results Found';
      case EmptyStateType.error:
        return 'Something Went Wrong';
    }
  }

  String _getDefaultMessage() {
    switch (type) {
      case EmptyStateType.noData:
        return 'Get started by adding your first item';
      case EmptyStateType.noResults:
        return 'Try adjusting your search or filters';
      case EmptyStateType.error:
        return 'We encountered an error. Please try again';
    }
  }

  Color _getDefaultIconColor(BuildContext context) {
    switch (type) {
      case EmptyStateType.noData:
        return AppDesign.getTextSecondary(context);
      case EmptyStateType.noResults:
        return AppDesign.getTextSecondary(context);
      case EmptyStateType.error:
        return AppColors.expense;
    }
  }

  Gradient? _getActionGradient(BuildContext context) {
    switch (type) {
      case EmptyStateType.noData:
        return AppDesign.getPrimaryGradient(context);
      case EmptyStateType.noResults:
        return AppDesign.getPrimaryGradient(context);
      case EmptyStateType.error:
        return null; // Use default primary gradient
    }
  }
}

/// Enum defining the different types of empty states
enum EmptyStateType {
  /// No data exists yet (e.g., empty transaction list)
  noData,
  
  /// Search or filter returned no results
  noResults,
  
  /// An error occurred
  error,
}
