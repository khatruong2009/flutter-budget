import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import 'design_system.dart';
import 'recurring_transaction.dart';
import 'recurring_transaction_model.dart';
import 'recurring_transactions_page.dart';
import 'theme_provider.dart';
import 'transaction_model.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    Key? key,
  }) : super(key: key);

  @override
  SettingsPageState createState() => SettingsPageState();
}

class SettingsPageState extends State<SettingsPage> {
  bool _isExporting = false;
  late Future<String> _versionFuture;

  @override
  void initState() {
    super.initState();
    _versionFuture = _loadVersion();
  }

  Future<String> _loadVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return packageInfo.version;
    } catch (e) {
      // Fallback to hardcoded version if package info fails
      return '2.0.0';
    }
  }

  Future<void> _exportTransactions(BuildContext context) async {
    setState(() {
      _isExporting = true;
    });

    final messenger = ScaffoldMessenger.maybeOf(context);

    try {
      final transactionModel =
          Provider.of<TransactionModel>(context, listen: false);

      // Get the position of the button for iPad popover positioning
      final RenderBox? box = context.findRenderObject() as RenderBox?;
      final Rect? sharePositionOrigin =
          box != null ? box.localToGlobal(Offset.zero) & box.size : null;

      await transactionModel.exportTransactionsToCSV(sharePositionOrigin);

      if (!mounted) return;

      messenger?.showSnackBar(
        SnackBar(
          content: const Text('Transactions exported successfully!'),
          backgroundColor: AppColors.income,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDesign.radiusM),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      messenger?.showSnackBar(
        SnackBar(
          content: Text('Error exporting transactions: $e'),
          backgroundColor: AppColors.expense,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDesign.radiusM),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final currentThemeMode = themeProvider.themeMode;
    final transactionModel = context.watch<TransactionModel>();
    final recurringModel = context.watch<RecurringTransactionModel>();

    final transactionCount = transactionModel.transactions.length;
    final activeRecurring =
        recurringModel.recurringTransactions.where((r) => r.isActive).toList();

    return BudgiePageScaffold(
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          bottom: DockMetrics.contentBottomPadding(context),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const BudgieHeader(title: 'Settings'),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: _BrandCard(isDark: isDark),
              ),
              const _SectionEyebrow(label: 'APPEARANCE'),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: GlowListCard(
                  children: [
                    _ThemeRow(
                      isDark: isDark,
                      currentThemeMode: currentThemeMode,
                      onChanged: (mode) => themeProvider.setThemeMode(mode),
                    ),
                  ],
                ),
              ),
              const _SectionEyebrow(label: 'DATA'),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: GlowListCard(
                  children: [
                    _SettingsRow(
                      isDark: isDark,
                      icon: Symbols.repeat_rounded,
                      iconColor: AppColors.getAccent(isDark),
                      title: 'Recurring transactions',
                      subtitle: _recurringSubtitle(activeRecurring),
                      trailing: Icon(
                        Symbols.chevron_right_rounded,
                        size: 20,
                        weight: 500,
                        color: AppColors.getTextTertiaryColor(isDark),
                      ),
                      onTap: () {
                        Navigator.of(context).push(
                          CupertinoPageRoute(
                            builder: (context) =>
                                const RecurringTransactionsPage(),
                          ),
                        );
                      },
                    ),
                    _SettingsRow(
                      isDark: isDark,
                      icon: Symbols.file_download_rounded,
                      iconColor: AppColors.getIncome(isDark),
                      iconBackground:
                          AppColors.getIncome(isDark).withValues(alpha: 0.12),
                      title: 'Export as CSV',
                      subtitle: 'All $transactionCount transactions',
                      trailing: _isExporting
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.getTextColor(isDark),
                                ),
                              ),
                            )
                          : Icon(
                              Symbols.chevron_right_rounded,
                              size: 20,
                              weight: 500,
                              color: AppColors.getTextTertiaryColor(isDark),
                            ),
                      onTap: _isExporting
                          ? null
                          : () => _exportTransactions(context),
                    ),
                  ],
                ),
              ),
              const _SectionEyebrow(label: 'ABOUT'),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: GlowListCard(
                  children: [
                    FutureBuilder<String>(
                      future: _versionFuture,
                      builder: (context, snapshot) {
                        final version = snapshot.data ?? '2.0.0';
                        return _SettingsRow(
                          isDark: isDark,
                          icon: Symbols.info_rounded,
                          iconColor: AppColors.dockInactiveIcon,
                          iconBackground: isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : Colors.black.withValues(alpha: 0.06),
                          title: 'Version',
                          subtitle: 'Budgie $version',
                          trailing: null,
                          onTap: null,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _recurringSubtitle(List<RecurringTransaction> active) {
    if (active.isEmpty) return 'No active recurring transactions';
    final names = active.map((r) => r.description).take(3).join(', ');
    return '${active.length} active · $names';
  }
}

/// Accent-gradient tinted brand card: Budgie mark + name + local-only note.
class _BrandCard extends StatelessWidget {
  final bool isDark;

  const _BrandCard({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.getAccent(isDark);
    final base = AppColors.getCard(isDark);

    return GlowCard(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color.alphaBlend(accent.withValues(alpha: 0.22), base), base],
      ),
      border: Border.all(color: accent.withValues(alpha: 0.3)),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppColors.glow(accent,
                  blurRadius: 24, alpha: 0.4, isDark: isDark),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                'assets/budgie_mark.png',
                width: 52,
                height: 52,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Budgie',
                  style: AppTypography.cardTitle.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: AppColors.getTextColor(isDark),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'All data stays on this device',
                  style: AppTypography.rowSubtitle.copyWith(
                    fontSize: 13,
                    color: AppColors.getTextSecondaryColor(isDark),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Mono eyebrow section header, inset 24px like the design.
class _SectionEyebrow extends StatelessWidget {
  final String label;

  const _SectionEyebrow({required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
      child: Text(
        label,
        style: AppTypography.eyebrow.copyWith(
          color: AppColors.getTextTertiaryColor(isDark),
        ),
      ),
    );
  }
}

/// Theme row: icon tile + title/subtitle + inline SegmentedPillControl bound
/// to [ThemeProvider].
class _ThemeRow extends StatelessWidget {
  final bool isDark;
  final ThemeMode currentThemeMode;
  final ValueChanged<ThemeMode> onChanged;

  const _ThemeRow({
    required this.isDark,
    required this.currentThemeMode,
    required this.onChanged,
  });

  static const _modes = [ThemeMode.light, ThemeMode.dark, ThemeMode.system];

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _modes.indexOf(currentThemeMode);
    final accent = AppColors.getAccent(isDark);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Icon(Symbols.dark_mode_rounded,
                size: 20, weight: 500, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Theme',
                  style: AppTypography.rowTitle.copyWith(
                    color: AppColors.getTextColor(isDark),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Light, dark, or match device',
                  style: AppTypography.rowSubtitle.copyWith(
                    color: AppColors.getTextSecondaryColor(isDark),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Semantics(
            label: 'Theme mode',
            child: SegmentedPillControl(
              segments: const ['Light', 'Dark', 'Auto'],
              selectedIndex: selectedIndex < 0 ? 2 : selectedIndex,
              onChanged: (index) => onChanged(_modes[index]),
            ),
          ),
        ],
      ),
    );
  }
}

/// Generic settings row: icon tile, title/subtitle, trailing widget.
class _SettingsRow extends StatelessWidget {
  final bool isDark;
  final IconData icon;
  final Color iconColor;
  final Color? iconBackground;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsRow({
    required this.isDark,
    required this.icon,
    required this.iconColor,
    this.iconBackground,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBackground ?? iconColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 20, weight: 500, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: AppTypography.rowTitle.copyWith(
                    color: AppColors.getTextColor(isDark),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.rowSubtitle.copyWith(
                    color: AppColors.getTextSecondaryColor(isDark),
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 12),
            trailing!,
          ],
        ],
      ),
    );

    if (onTap == null) return row;
    return Semantics(
      button: true,
      label: '$title, $subtitle',
      child: InkWell(
        onTap: () {
          MicroInteractions.lightImpact();
          onTap!();
        },
        borderRadius: BorderRadius.circular(18),
        child: row,
      ),
    );
  }
}
