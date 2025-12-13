import 'package:flutter/material.dart';
import '../utils/platform_utils.dart';
import '../design_system.dart';

/// Responsive layout wrapper that adapts content for different screen sizes
class ResponsiveLayout extends StatelessWidget {
  final Widget child;
  final double? maxWidth;
  final bool centerContent;
  final EdgeInsets? padding;

  const ResponsiveLayout({
    super.key,
    required this.child,
    this.maxWidth,
    this.centerContent = true,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveMaxWidth = maxWidth ?? PlatformUtils.getMaxContentWidth(context);
    final effectivePadding = padding ?? PlatformUtils.getPlatformPadding(context);

    return Center(
      child: Container(
        constraints: BoxConstraints(maxWidth: effectiveMaxWidth),
        padding: effectivePadding,
        child: child,
      ),
    );
  }
}

/// Breakpoint-based responsive builder
class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, ScreenSize screenSize) builder;

  const ResponsiveBuilder({
    super.key,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenSize = _getScreenSize(constraints.maxWidth);
        return builder(context, screenSize);
      },
    );
  }

  ScreenSize _getScreenSize(double width) {
    if (width < 600) return ScreenSize.mobile;
    if (width < 900) return ScreenSize.tablet;
    if (width < 1200) return ScreenSize.desktop;
    return ScreenSize.large;
  }
}

enum ScreenSize {
  mobile,
  tablet,
  desktop,
  large,
}

/// Adaptive grid that adjusts columns based on screen size
class AdaptiveGrid extends StatelessWidget {
  final List<Widget> children;
  final double spacing;
  final int? mobileColumns;
  final int? tabletColumns;
  final int? desktopColumns;
  final double childAspectRatio;

  const AdaptiveGrid({
    super.key,
    required this.children,
    this.spacing = AppDesign.spacingM,
    this.mobileColumns = 1,
    this.tabletColumns = 2,
    this.desktopColumns = 3,
    this.childAspectRatio = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, screenSize) {
        int columns;
        switch (screenSize) {
          case ScreenSize.mobile:
            columns = mobileColumns ?? 1;
            break;
          case ScreenSize.tablet:
            columns = tabletColumns ?? 2;
            break;
          case ScreenSize.desktop:
          case ScreenSize.large:
            columns = desktopColumns ?? 3;
            break;
        }

        return GridView.count(
          crossAxisCount: columns,
          crossAxisSpacing: spacing,
          mainAxisSpacing: spacing,
          childAspectRatio: childAspectRatio,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: children,
        );
      },
    );
  }
}

/// Adaptive columns that stack on mobile and sit side-by-side on larger screens
class AdaptiveColumns extends StatelessWidget {
  final List<Widget> children;
  final double spacing;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisAlignment mainAxisAlignment;

  const AdaptiveColumns({
    super.key,
    required this.children,
    this.spacing = AppDesign.spacingM,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.mainAxisAlignment = MainAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, screenSize) {
        if (screenSize == ScreenSize.mobile) {
          // Stack vertically on mobile
          return Column(
            crossAxisAlignment: crossAxisAlignment,
            mainAxisAlignment: mainAxisAlignment,
            children: _addSpacing(children, spacing, isVertical: true),
          );
        } else {
          // Arrange horizontally on larger screens
          return Row(
            crossAxisAlignment: crossAxisAlignment,
            mainAxisAlignment: mainAxisAlignment,
            children: _addSpacing(
              children.map((child) => Expanded(child: child)).toList(),
              spacing,
              isVertical: false,
            ),
          );
        }
      },
    );
  }

  List<Widget> _addSpacing(List<Widget> widgets, double spacing, {required bool isVertical}) {
    if (widgets.isEmpty) return widgets;
    
    final result = <Widget>[];
    for (int i = 0; i < widgets.length; i++) {
      result.add(widgets[i]);
      if (i < widgets.length - 1) {
        result.add(SizedBox(
          width: isVertical ? 0 : spacing,
          height: isVertical ? spacing : 0,
        ));
      }
    }
    return result;
  }
}

/// Platform-aware app bar that adapts to different platforms
class PlatformAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool centerTitle;
  final Color? backgroundColor;

  const PlatformAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.centerTitle = true,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return AppBar(
      title: Text(
        title,
        style: AppTypography.headingMedium.copyWith(
          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
        ),
      ),
      centerTitle: PlatformUtils.isIOS || PlatformUtils.isMacOS ? true : centerTitle,
      leading: leading,
      actions: actions,
      backgroundColor: backgroundColor ?? Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

/// Keyboard shortcut handler for desktop platforms
class KeyboardShortcutHandler extends StatelessWidget {
  final Widget child;
  final Map<ShortcutActivator, VoidCallback>? shortcuts;

  const KeyboardShortcutHandler({
    super.key,
    required this.child,
    this.shortcuts,
  });

  @override
  Widget build(BuildContext context) {
    if (!PlatformUtils.supportsKeyboardShortcuts || shortcuts == null) {
      return child;
    }

    return Shortcuts(
      shortcuts: shortcuts!.map(
        (key, value) => MapEntry(key, CallbackIntent(value)),
      ),
      child: Actions(
        actions: {
          CallbackIntent: CallbackAction<CallbackIntent>(
            onInvoke: (intent) => intent.callback(),
          ),
        },
        child: Focus(
          autofocus: true,
          child: child,
        ),
      ),
    );
  }
}

class CallbackIntent extends Intent {
  final VoidCallback callback;
  const CallbackIntent(this.callback);
}
