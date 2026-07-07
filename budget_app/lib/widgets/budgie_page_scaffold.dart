import 'package:flutter/material.dart';

import 'floating_dock.dart';

/// Standard page shell for the redesigned tabs: transparent-to-scaffold dark
/// background, optional [GlowFab] pinned at right: 20 / bottom: 92 (above the
/// floating dock), and a body that should pad its scrollable content with
/// [DockMetrics.contentBottomPadding] so cards clear the dock.
class BudgiePageScaffold extends StatelessWidget {
  final Widget body;

  /// Typically a [GlowFab]; Home, Net Worth, and Goals have one.
  final Widget? fab;

  const BudgiePageScaffold({super.key, required this.body, this.fab});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: body),
          if (fab != null)
            Positioned(
              right: 20,
              bottom: DockMetrics.fabBottomOffset(context),
              child: fab!,
            ),
        ],
      ),
    );
  }
}
