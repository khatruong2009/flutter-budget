import 'package:flutter/material.dart';
import 'dart:ui';
import '../design_system.dart';

/// ModernAppBar is an enhanced AppBar component with gradient background,
/// glassmorphism effect, and consistent typography
class ModernAppBar extends StatelessWidget implements PreferredSizeWidget {
  /// The title text to display
  final String title;
  
  /// Optional leading widget (back button, menu, etc.)
  final Widget? leading;
  
  /// Optional actions to display on the right
  final List<Widget>? actions;
  
  /// Whether to show a gradient background (default: true)
  final bool showGradient;
  
  /// Whether to use glassmorphism effect (default: true)
  final bool useGlassEffect;
  
  /// Optional custom gradient (overrides default)
  final Gradient? gradient;
  
  /// Whether to center the title (default: true)
  final bool centerTitle;
  
  /// Optional subtitle text
  final String? subtitle;

  const ModernAppBar({
    super.key,
    required this.title,
    this.leading,
    this.actions,
    this.showGradient = true,
    this.useGlassEffect = true,
    this.gradient,
    this.centerTitle = true,
    this.subtitle,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    Widget appBarContent = AppBar(
      leading: leading,
      title: subtitle != null
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: centerTitle
                  ? CrossAxisAlignment.center
                  : CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.headingMedium.copyWith(
                    color: showGradient
                        ? Colors.white
                        : AppDesign.getTextPrimary(context),
                  ),
                ),
                const SizedBox(height: AppDesign.spacingXXS),
                Text(
                  subtitle!,
                  style: AppTypography.caption.copyWith(
                    color: showGradient
                        ? Colors.white.withValues(alpha: 0.8)
                        : AppDesign.getTextSecondary(context),
                  ),
                ),
              ],
            )
          : Text(
              title,
              style: AppTypography.headingMedium.copyWith(
                color: showGradient
                    ? Colors.white
                    : AppDesign.getTextPrimary(context),
              ),
            ),
      centerTitle: centerTitle,
      actions: actions,
      backgroundColor: Colors.transparent,
      elevation: 0,
      iconTheme: IconThemeData(
        color: showGradient
            ? Colors.white
            : AppDesign.getTextPrimary(context),
      ),
    );

    if (!showGradient && !useGlassEffect) {
      return appBarContent;
    }

    return Container(
      decoration: showGradient
          ? BoxDecoration(
              gradient: gradient ?? _getDefaultGradient(isDark),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            )
          : null,
      child: useGlassEffect
          ? ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: showGradient
                        ? Colors.transparent
                        : AppDesign.getSurfaceColor(context).withValues(alpha: 0.9),
                    border: Border(
                      bottom: BorderSide(
                        color: AppDesign.getBorderColor(context).withValues(alpha: 0.7),
                        width: AppDesign.borderThin,
                      ),
                    ),
                  ),
                  child: appBarContent,
                ),
              ),
            )
          : appBarContent,
    );
  }

  LinearGradient _getDefaultGradient(bool isDark) {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark
          ? [
              const Color(0xFF667eea).withValues(alpha: 0.8),
              const Color(0xFF764ba2).withValues(alpha: 0.8),
            ]
          : [
              const Color(0xFF667eea),
              const Color(0xFF764ba2),
            ],
    );
  }
}

/// ModernSliverAppBar is an enhanced SliverAppBar with gradient background
/// and collapsing header effects
class ModernSliverAppBar extends StatelessWidget {
  /// The title text to display
  final String title;
  
  /// Optional leading widget
  final Widget? leading;
  
  /// Optional actions
  final List<Widget>? actions;
  
  /// Whether the app bar should remain visible at the top
  final bool pinned;
  
  /// Whether the app bar should float above the content
  final bool floating;
  
  /// The expanded height of the app bar
  final double expandedHeight;
  
  /// Optional flexible space widget
  final Widget? flexibleSpace;
  
  /// Optional custom gradient
  final Gradient? gradient;

  const ModernSliverAppBar({
    super.key,
    required this.title,
    this.leading,
    this.actions,
    this.pinned = true,
    this.floating = false,
    this.expandedHeight = 120.0,
    this.flexibleSpace,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return SliverAppBar(
      leading: leading,
      title: Text(
        title,
        style: AppTypography.headingMedium.copyWith(
          color: Colors.white,
        ),
      ),
      centerTitle: true,
      actions: actions,
      pinned: pinned,
      floating: floating,
      expandedHeight: expandedHeight,
      backgroundColor: Colors.transparent,
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.white),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: gradient ?? _getDefaultGradient(isDark),
          ),
          child: flexibleSpace,
        ),
      ),
    );
  }

  LinearGradient _getDefaultGradient(bool isDark) {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark
          ? [
              const Color(0xFF667eea).withValues(alpha: 0.8),
              const Color(0xFF764ba2).withValues(alpha: 0.8),
            ]
          : [
              const Color(0xFF667eea),
              const Color(0xFF764ba2),
            ],
    );
  }
}
