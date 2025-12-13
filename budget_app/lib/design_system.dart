import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:animated_digit/animated_digit.dart';
import 'theme/app_colors.dart';
import 'theme/app_typography.dart';
import 'theme/app_animations.dart';
import 'utils/micro_interactions.dart';

// Export all design system components
export 'theme/app_colors.dart';
export 'theme/app_typography.dart';
export 'theme/app_animations.dart';
export 'widgets/modern_app_bar.dart';
export 'widgets/page_transitions.dart';
export 'widgets/interactive_wrapper.dart';
export 'utils/micro_interactions.dart';

/// AppDesign is the central design system that consolidates all design tokens
/// including spacing, sizing, border radius, shadows, and references to
/// colors, typography, and animations
class AppDesign {
  // Spacing Scale (8pt grid system)
  static const double spacingXXS = 2.0;
  static const double spacingXS = 4.0;
  static const double spacingS = 8.0;
  static const double spacingM = 16.0;
  static const double spacingL = 24.0;
  static const double spacingXL = 32.0;
  static const double spacingXXL = 48.0;
  static const double spacingXXXL = 64.0;

  // Border Radius Scale
  static const double radiusXS = 4.0;
  static const double radiusS = 8.0;
  static const double radiusM = 12.0;
  static const double radiusL = 16.0;
  static const double radiusXL = 20.0;
  static const double radiusXXL = 24.0;
  static const double radiusRound = 999.0; // Fully rounded

  // Icon Sizes
  static const double iconXS = 16.0;
  static const double iconS = 20.0;
  static const double iconM = 24.0;
  static const double iconL = 32.0;
  static const double iconXL = 48.0;
  static const double iconXXL = 64.0;

  // Touch Target Sizes (minimum 44pt for accessibility)
  static const double touchTargetMin = 44.0;
  static const double touchTargetS = 44.0;
  static const double touchTargetM = 48.0;
  static const double touchTargetL = 56.0;

  // Elevation/Shadow System (Material Design inspired)
  static List<BoxShadow> get shadowXS => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 2,
          offset: const Offset(0, 1),
        ),
      ];

  static List<BoxShadow> get shadowS => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get shadowM => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.1),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get shadowL => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.12),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ];

  static List<BoxShadow> get shadowXL => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.15),
          blurRadius: 24,
          offset: const Offset(0, 12),
        ),
      ];

  // Elevation Levels (Material Design)
  static const double elevationNone = 0.0;
  static const double elevationXS = 1.0;
  static const double elevationS = 2.0;
  static const double elevationM = 4.0;
  static const double elevationL = 8.0;
  static const double elevationXL = 16.0;

  // Helper method to get elevation shadow based on level
  static List<BoxShadow> getElevationShadow(double elevation) {
    if (elevation <= 0) return [];
    if (elevation <= 1) return shadowXS;
    if (elevation <= 2) return shadowS;
    if (elevation <= 4) return shadowM;
    if (elevation <= 8) return shadowL;
    return shadowXL;
  }

  // Border Widths
  static const double borderThin = 1.0;
  static const double borderMedium = 1.5;
  static const double borderThick = 2.0;

  // Opacity Values
  static const double opacityDisabled = 0.38;
  static const double opacityMuted = 0.60;
  static const double opacitySubtle = 0.87;
  static const double opacityFull = 1.0;

  // Text Colors (Light Theme)
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textTertiary = Color(0xFF9E9E9E);
  static const Color textOnPrimary = Colors.white;

  // Text Colors (Dark Theme)
  static const Color textPrimaryDark = Color(0xFFFFFFFF);
  static const Color textSecondaryDark = Color(0xFFB0B0B0);
  static const Color textTertiaryDark = Color(0xFF808080);
  static const Color textOnPrimaryDark = Color(0xFF212121);

  // Layout Constraints
  static const double maxContentWidth = 600.0;
  static const double minCardHeight = 100.0;
  static const double maxCardHeight = 200.0;

  // Grid System
  static const int gridColumnsPhone = 4;
  static const int gridColumnsTablet = 8;
  static const int gridColumnsDesktop = 12;

  // Breakpoints
  static const double breakpointPhone = 600.0;
  static const double breakpointTablet = 900.0;
  static const double breakpointDesktop = 1200.0;

  // Helper method to get text color based on theme
  static Color getTextPrimary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? textPrimaryDark
        : textPrimary;
  }

  static Color getTextSecondary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? textSecondaryDark
        : textSecondary;
  }

  static Color getTextTertiary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? textTertiaryDark
        : textTertiary;
  }

  // Helper methods to get solid colors based on theme
  static Color getBackgroundColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppColors.getBackground(isDark);
  }

  static Color getSurfaceColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppColors.getSurface(isDark);
  }

  static Color getCardColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppColors.getCard(isDark);
  }

  static Color getBorderColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppColors.getBorder(isDark);
  }

  // Helper methods to get gradients (for accents only)
  static LinearGradient getPrimaryGradient(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppColors.getPrimaryGradient(isDark);
  }

  static LinearGradient getIncomeGradient(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppColors.getIncomeGradient(isDark);
  }

  static LinearGradient getExpenseGradient(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppColors.getExpenseGradient(isDark);
  }

  static LinearGradient getAccentGradient(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppColors.getAccentGradient(isDark);
  }

  static LinearGradient getNeutralGradient(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppColors.getNeutralGradient(isDark);
  }

  // Helper method to get semantic colors based on theme
  static Color getIncomeColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppColors.getIncome(isDark);
  }

  static Color getExpenseColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppColors.getExpense(isDark);
  }

  static Color getNeutralColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppColors.getNeutral(isDark);
  }

  static Color getSuccessColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppColors.getSuccess(isDark);
  }

  static Color getWarningColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppColors.getWarning(isDark);
  }

  static Color getErrorColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppColors.getError(isDark);
  }

  static Color getInfoColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppColors.getInfo(isDark);
  }

  // Helper method to get chart colors based on theme
  static List<Color> getChartColors(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppColors.getChartColors(isDark);
  }

  // Helper method to determine device type
  static bool isPhone(BuildContext context) {
    return MediaQuery.of(context).size.width < breakpointPhone;
  }

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= breakpointPhone && width < breakpointTablet;
  }

  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= breakpointTablet;
  }

  // Helper method to get responsive spacing
  static double getResponsiveSpacing(
    BuildContext context, {
    double phone = spacingM,
    double tablet = spacingL,
    double desktop = spacingXL,
  }) {
    if (isDesktop(context)) return desktop;
    if (isTablet(context)) return tablet;
    return phone;
  }

  // Helper method to get responsive padding
  static EdgeInsets getResponsivePadding(BuildContext context) {
    if (isDesktop(context)) {
      return const EdgeInsets.all(spacingXL);
    } else if (isTablet(context)) {
      return const EdgeInsets.all(spacingL);
    } else {
      return const EdgeInsets.all(spacingM);
    }
  }
}

/// ElevatedCard is a reusable card component with Material Design elevation
/// featuring solid backgrounds, shadows, and clean borders
/// 
/// Performance optimizations:
/// - Uses const constructor when possible for better performance
/// - Caches computed values to avoid repeated calculations
/// - Optimized for minimal rebuilds
class ElevatedCard extends StatelessWidget {
  /// The widget to display inside the card
  final Widget child;

  /// The elevation level for the card shadow (default: 2.0)
  final double elevation;

  /// Optional background color (defaults to theme card color)
  final Color? color;

  /// The border radius of the card (default: AppDesign.radiusL)
  final BorderRadius? borderRadius;

  /// The padding inside the card (default: AppDesign.spacingM)
  final EdgeInsets? padding;

  /// Optional tap callback for interactive cards
  final VoidCallback? onTap;

  /// Optional long press callback for interactive cards
  final VoidCallback? onLongPress;

  /// Whether to enable haptic feedback on tap (default: true)
  final bool enableHapticFeedback;

  const ElevatedCard({
    super.key,
    required this.child,
    this.elevation = AppDesign.elevationS,
    this.color,
    this.borderRadius,
    this.padding,
    this.onTap,
    this.onLongPress,
    this.enableHapticFeedback = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = color ?? AppColors.getCard(isDark);
    final effectiveBorderRadius =
        borderRadius ?? BorderRadius.circular(AppDesign.radiusL);
    final effectivePadding =
        padding ?? const EdgeInsets.all(AppDesign.spacingM);

    return Material(
      color: cardColor,
      elevation: elevation,
      borderRadius: effectiveBorderRadius,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      child: InkWell(
        onTap: onTap != null
            ? () async {
                if (enableHapticFeedback) {
                  await MicroInteractions.lightImpact();
                }
                onTap!();
              }
            : null,
        onLongPress: onLongPress != null
            ? () async {
                if (enableHapticFeedback) {
                  await MicroInteractions.mediumImpact();
                }
                onLongPress!();
              }
            : null,
        borderRadius: effectiveBorderRadius,
        child: Padding(
          padding: effectivePadding,
          child: child,
        ),
      ),
    );
  }
}

/// AppButton is an enhanced button component with support for primary/secondary variants,
/// gradient backgrounds, loading states, icons, and proper accessibility
class AppButton extends StatefulWidget {
  /// The button label text
  final String label;

  /// Callback when button is pressed (null for disabled state)
  final VoidCallback? onPressed;

  /// Button variant (primary or secondary)
  final AppButtonVariant variant;

  /// Optional icon to display before the label
  final IconData? icon;

  /// Whether the button is in loading state
  final bool isLoading;

  /// Button size (small, medium, large)
  final AppButtonSize size;

  /// Optional custom gradient (overrides variant gradient)
  final Gradient? gradient;

  /// Whether button should expand to fill available width
  final bool expanded;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.size = AppButtonSize.medium,
    this.gradient,
    this.expanded = false,
  });

  /// Factory constructor for primary button
  factory AppButton.primary({
    required String label,
    required VoidCallback? onPressed,
    IconData? icon,
    bool isLoading = false,
    AppButtonSize size = AppButtonSize.medium,
    Gradient? gradient,
    bool expanded = false,
  }) {
    return AppButton(
      label: label,
      onPressed: onPressed,
      variant: AppButtonVariant.primary,
      icon: icon,
      isLoading: isLoading,
      size: size,
      gradient: gradient,
      expanded: expanded,
    );
  }

  /// Factory constructor for secondary button
  factory AppButton.secondary({
    required String label,
    required VoidCallback? onPressed,
    IconData? icon,
    bool isLoading = false,
    AppButtonSize size = AppButtonSize.medium,
    bool expanded = false,
  }) {
    return AppButton(
      label: label,
      onPressed: onPressed,
      variant: AppButtonVariant.secondary,
      icon: icon,
      isLoading: isLoading,
      size: size,
      expanded: expanded,
    );
  }

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isHovering = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AppAnimations.buttonPressDuration,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: AppAnimations.buttonPressScale,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: AppAnimations.easeOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleHoverEnter(PointerEnterEvent event) {
    if (widget.onPressed != null &&
        !widget.isLoading &&
        MicroInteractions.shouldEnableHover()) {
      setState(() => _isHovering = true);
    }
  }

  void _handleHoverExit(PointerExitEvent event) {
    if (MicroInteractions.shouldEnableHover()) {
      setState(() => _isHovering = false);
    }
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.onPressed != null && !widget.isLoading) {
      _controller.forward();
      // Trigger haptic feedback on button press
      MicroInteractions.lightImpact();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (widget.onPressed != null && !widget.isLoading) {
      _controller.reverse();
    }
  }

  void _handleTapCancel() {
    if (widget.onPressed != null && !widget.isLoading) {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.onPressed == null || widget.isLoading;
    final effectiveOpacity =
        isDisabled ? AppDesign.opacityDisabled : AppDesign.opacityFull;

    // Get size-specific values
    final height = _getHeight();
    final horizontalPadding = _getHorizontalPadding();
    final textStyle = _getTextStyle();
    final iconSize = _getIconSize();

    Widget buttonContent = Row(
      mainAxisSize: widget.expanded ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.isLoading)
          SizedBox(
            width: iconSize,
            height: iconSize,
            child: CircularProgressIndicator(
              strokeWidth: 2.0,
              valueColor: AlwaysStoppedAnimation<Color>(
                widget.variant == AppButtonVariant.primary
                    ? AppColors.textOnPrimary
                    : AppDesign.getTextPrimary(context),
              ),
            ),
          )
        else if (widget.icon != null)
          Icon(
            widget.icon,
            size: iconSize,
            color: widget.variant == AppButtonVariant.primary
                ? AppColors.textOnPrimary
                : AppDesign.getTextPrimary(context),
          ),
        if ((widget.icon != null || widget.isLoading) &&
            widget.label.isNotEmpty)
          const SizedBox(width: AppDesign.spacingS),
        if (widget.label.isNotEmpty)
          Text(
            widget.label,
            style: textStyle.copyWith(
              color: widget.variant == AppButtonVariant.primary
                  ? AppColors.textOnPrimary
                  : AppDesign.getTextPrimary(context),
            ),
          ),
      ],
    );

    Widget button;

    if (widget.variant == AppButtonVariant.primary) {
      // Primary button with gradient and shadow
      final effectiveGradient =
          widget.gradient ?? AppDesign.getPrimaryGradient(context);

      button = Container(
        height: height,
        constraints: BoxConstraints(
          minWidth: height, // Ensure minimum touch target
        ),
        decoration: BoxDecoration(
          gradient: effectiveGradient,
          borderRadius: BorderRadius.circular(AppDesign.radiusM),
          boxShadow: isDisabled ? null : AppDesign.shadowM,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isDisabled ? null : widget.onPressed,
            borderRadius: BorderRadius.circular(AppDesign.radiusM),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: Center(child: buttonContent),
            ),
          ),
        ),
      );
    } else {
      // Secondary button with transparent background and border
      button = Container(
        height: height,
        constraints: BoxConstraints(
          minWidth: height, // Ensure minimum touch target
        ),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppDesign.radiusM),
          border: Border.all(
            color: AppDesign.getTextPrimary(context).withValues(alpha: 0.3),
            width: AppDesign.borderMedium,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isDisabled ? null : widget.onPressed,
            borderRadius: BorderRadius.circular(AppDesign.radiusM),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: Center(child: buttonContent),
            ),
          ),
        ),
      );
    }

    // Wrap with opacity for disabled state
    button = Opacity(
      opacity: effectiveOpacity,
      child: button,
    );

    // Wrap with scale animation
    button = ScaleTransition(
      scale: _scaleAnimation,
      child: button,
    );

    // Wrap with GestureDetector for press animation
    button = GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: button,
    );

    // Wrap with MouseRegion for hover effects on desktop
    if (MicroInteractions.shouldEnableHover()) {
      button = MouseRegion(
        onEnter: _handleHoverEnter,
        onExit: _handleHoverExit,
        cursor: (widget.onPressed != null && !widget.isLoading)
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        child: AnimatedContainer(
          duration: AppAnimations.fast,
          transform: _isHovering && !isDisabled
              ? Matrix4.translationValues(0, -2, 0)
              : Matrix4.identity(),
          child: button,
        ),
      );
    }

    // Expand if needed
    if (widget.expanded) {
      button = SizedBox(
        width: double.infinity,
        child: button,
      );
    }

    return button;
  }

  double _getHeight() {
    switch (widget.size) {
      case AppButtonSize.small:
        return AppDesign.touchTargetS;
      case AppButtonSize.medium:
        return AppDesign.touchTargetM;
      case AppButtonSize.large:
        return AppDesign.touchTargetL;
    }
  }

  double _getHorizontalPadding() {
    switch (widget.size) {
      case AppButtonSize.small:
        return AppDesign.spacingM;
      case AppButtonSize.medium:
        return AppDesign.spacingL;
      case AppButtonSize.large:
        return AppDesign.spacingXL;
    }
  }

  TextStyle _getTextStyle() {
    switch (widget.size) {
      case AppButtonSize.small:
        return AppTypography.buttonSmall;
      case AppButtonSize.medium:
        return AppTypography.buttonMedium;
      case AppButtonSize.large:
        return AppTypography.buttonLarge;
    }
  }

  double _getIconSize() {
    switch (widget.size) {
      case AppButtonSize.small:
        return AppDesign.iconS;
      case AppButtonSize.medium:
        return AppDesign.iconM;
      case AppButtonSize.large:
        return AppDesign.iconL;
    }
  }
}

/// Button variant enum
enum AppButtonVariant {
  primary,
  secondary,
}

/// Button size enum
enum AppButtonSize {
  small,
  medium,
  large,
}

/// AnimatedMetricCard is an enhanced metric card component with scale animation,
/// solid color icon container, and animated value display
class AnimatedMetricCard extends StatefulWidget {
  /// The label text displayed above the value
  final String label;

  /// The numeric value to display with animation
  final double value;

  /// The icon to display in the colored container
  final IconData icon;

  /// The solid color to apply to the icon container
  final Color color;

  /// Optional tap callback for interactive cards
  final VoidCallback? onTap;

  /// Number of decimal places to show (default: 2)
  final int fractionDigits;

  /// Optional prefix for the value (e.g., '$')
  final String? prefix;

  /// Optional suffix for the value (e.g., '%')
  final String? suffix;

  const AnimatedMetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
    this.fractionDigits = 2,
    this.prefix,
    this.suffix,
  });

  @override
  State<AnimatedMetricCard> createState() => _AnimatedMetricCardState();
}

class _AnimatedMetricCardState extends State<AnimatedMetricCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AppAnimations.normal,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: AppAnimations.easeOut),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Wrap animated widget in RepaintBoundary for better performance
    return RepaintBoundary(
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: ElevatedCard(
          elevation: AppDesign.elevationM,
          onTap: widget.onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppDesign.spacingS),
                    decoration: BoxDecoration(
                      color: widget.color,
                      borderRadius: BorderRadius.circular(AppDesign.radiusS),
                    ),
                    child: Icon(
                      widget.icon,
                      color: AppColors.textOnPrimary,
                      size: AppDesign.iconM,
                    ),
                  ),
                  const SizedBox(width: AppDesign.spacingM),
                  Expanded(
                    child: Text(
                      widget.label,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppDesign.getTextPrimary(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDesign.spacingM),
              Row(
                children: [
                  if (widget.prefix != null)
                    Text(
                      widget.prefix!,
                      style: AppTypography.headingLarge.copyWith(
                        color: AppDesign.getTextPrimary(context),
                      ),
                    ),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: AnimatedDigitWidget(
                        value: widget.value,
                        fractionDigits: widget.fractionDigits,
                        textStyle: AppTypography.headingLarge.copyWith(
                          color: AppDesign.getTextPrimary(context),
                        ),
                        enableSeparator: true,
                      ),
                    ),
                  ),
                  if (widget.suffix != null)
                    Text(
                      widget.suffix!,
                      style: AppTypography.headingLarge.copyWith(
                        color: AppDesign.getTextPrimary(context),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
