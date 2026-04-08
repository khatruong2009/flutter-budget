import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'theme_provider.dart';
import 'transaction_model.dart';
import 'package:provider/provider.dart';
import 'design_system.dart';
import 'utils/platform_utils.dart';
import 'recurring_transactions_page.dart';

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
    final themeProvider = Provider.of<ThemeProvider>(context);
    final currentThemeMode = themeProvider.themeMode;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Settings',
          style: AppTypography.headingLarge.copyWith(
            color: AppDesign.getTextPrimary(context),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        color: AppDesign.getBackgroundColor(context),
        child: SafeArea(
          child: ListView(
            physics: PlatformUtils.platformScrollPhysics,
            padding: const EdgeInsets.all(AppDesign.spacingM),
            children: [
              // Appearance Section
              _buildSectionHeader(context, 'Appearance'),
              const SizedBox(height: AppDesign.spacingS),
              _buildSettingCard(
                context,
                icon: _themeModeIcon(currentThemeMode),
                iconGradient: AppDesign.getPrimaryGradient(context),
                title: 'Theme',
                description: 'Light, dark, or follow your device settings',
                trailing: _buildThemeModeTrailing(
                  context,
                  currentThemeMode,
                ),
                onTap: () => _showThemeModePicker(context, themeProvider),
              ),
              const SizedBox(height: AppDesign.spacingXL),

              // Data Section
              _buildSectionHeader(context, 'Data'),
              const SizedBox(height: AppDesign.spacingS),
              _buildSettingCard(
                context,
                icon: Icons.repeat,
                iconGradient: AppDesign.getPrimaryGradient(context),
                title: 'Recurring Transactions',
                description: 'Manage your recurring expenses and income',
                trailing: Icon(
                  Icons.chevron_right,
                  color: AppDesign.getTextTertiary(context),
                  size: AppDesign.iconM,
                ),
                onTap: () {
                  Navigator.of(context).push(
                    CupertinoPageRoute(
                      builder: (context) => const RecurringTransactionsPage(),
                    ),
                  );
                },
              ),
              const SizedBox(height: AppDesign.spacingS),
              _buildSettingCard(
                context,
                icon: Icons.file_download,
                iconGradient: AppDesign.getIncomeGradient(context),
                title: 'Export Transactions',
                description: 'Export all transactions as CSV file',
                trailing: _isExporting
                    ? SizedBox(
                        width: AppDesign.iconM,
                        height: AppDesign.iconM,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppDesign.getTextPrimary(context),
                          ),
                        ),
                      )
                    : Icon(
                        Icons.chevron_right,
                        color: AppDesign.getTextTertiary(context),
                        size: AppDesign.iconM,
                      ),
                onTap: _isExporting ? null : () => _exportTransactions(context),
              ),
              const SizedBox(height: AppDesign.spacingXL),

              // About Section
              _buildSectionHeader(context, 'About'),
              const SizedBox(height: AppDesign.spacingS),
              FutureBuilder<String>(
                future: _versionFuture,
                builder: (context, snapshot) {
                  final version = snapshot.data ?? '2.0.0';
                  return _buildSettingCard(
                    context,
                    icon: Icons.info_outline,
                    iconGradient: AppDesign.getNeutralGradient(context),
                    title: 'Version',
                    description: 'Budget App v$version',
                    trailing: null,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds a section header with consistent styling
  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDesign.spacingS),
      child: Text(
        title.toUpperCase(),
        style: AppTypography.caption.copyWith(
          color: AppDesign.getTextSecondary(context),
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  /// Builds a modern setting card with glassmorphism effect
  Widget _buildSettingCard(
    BuildContext context, {
    required IconData icon,
    required Gradient iconGradient,
    required String title,
    required String description,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ElevatedCard(
      elevation: AppDesign.elevationS,
      onTap: onTap,
      padding: const EdgeInsets.all(AppDesign.spacingM),
      child: Row(
        children: [
          // Icon container with gradient
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: iconGradient,
              borderRadius: BorderRadius.circular(AppDesign.radiusM),
            ),
            child: Icon(
              icon,
              color: AppColors.textOnPrimary,
              size: AppDesign.iconM,
            ),
          ),
          const SizedBox(width: AppDesign.spacingM),
          // Title and description
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppDesign.getTextPrimary(context),
                  ),
                ),
                const SizedBox(height: AppDesign.spacingXXS),
                Text(
                  description,
                  style: AppTypography.caption.copyWith(
                    color: AppDesign.getTextSecondary(context),
                  ),
                ),
              ],
            ),
          ),
          // Trailing widget (switch, chevron, etc.)
          if (trailing != null) ...[
            const SizedBox(width: AppDesign.spacingM),
            trailing,
          ],
        ],
      ),
    );
  }

  Future<void> _showThemeModePicker(
    BuildContext context,
    ThemeProvider themeProvider,
  ) async {
    final selectedMode = await showModalBottomSheet<ThemeMode>(
      context: context,
      backgroundColor: AppDesign.getCardColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDesign.radiusL),
        ),
      ),
      builder: (sheetContext) {
        final currentMode = themeProvider.themeMode;

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDesign.spacingM,
                  AppDesign.spacingM,
                  AppDesign.spacingM,
                  AppDesign.spacingS,
                ),
                child: Text(
                  'Choose Theme',
                  style: AppTypography.headingSmall.copyWith(
                    color: AppDesign.getTextPrimary(sheetContext),
                  ),
                ),
              ),
              ...ThemeMode.values.map(
                (mode) => ListTile(
                  leading: Icon(
                    _themeModeIcon(mode),
                    color: AppDesign.getTextPrimary(sheetContext),
                  ),
                  title: Text(
                    _themeModeLabel(mode),
                    style: AppTypography.bodyLarge.copyWith(
                      color: AppDesign.getTextPrimary(sheetContext),
                    ),
                  ),
                  subtitle: Text(
                    _themeModeDescription(mode),
                    style: AppTypography.caption.copyWith(
                      color: AppDesign.getTextSecondary(sheetContext),
                    ),
                  ),
                  trailing: mode == currentMode
                      ? Icon(
                          Icons.check,
                          color: AppDesign.getPrimaryGradient(sheetContext)
                              .colors
                              .first,
                        )
                      : null,
                  onTap: () {
                    Navigator.of(sheetContext).pop(mode);
                  },
                ),
              ),
              const SizedBox(height: AppDesign.spacingS),
            ],
          ),
        );
      },
    );

    if (selectedMode != null) {
      await themeProvider.setThemeMode(selectedMode);
    }
  }

  Widget _buildThemeModeTrailing(BuildContext context, ThemeMode themeMode) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _themeModeLabel(themeMode),
          style: AppTypography.bodyMedium.copyWith(
            color: AppDesign.getTextSecondary(context),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: AppDesign.spacingXS),
        Icon(
          Icons.chevron_right,
          color: AppDesign.getTextTertiary(context),
          size: AppDesign.iconM,
        ),
      ],
    );
  }

  String _themeModeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'System';
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
    }
  }

  String _themeModeDescription(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'Match your device appearance';
      case ThemeMode.light:
        return 'Always use the light theme';
      case ThemeMode.dark:
        return 'Always use the dark theme';
    }
  }

  IconData _themeModeIcon(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return Icons.brightness_auto;
      case ThemeMode.light:
        return Icons.wb_sunny;
      case ThemeMode.dark:
        return Icons.nights_stay;
    }
  }
}
