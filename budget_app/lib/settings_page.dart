import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'theme_provider.dart';
import 'transaction_model.dart';
import 'package:provider/provider.dart';
import 'design_system.dart';
import 'utils/platform_utils.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    Key? key,
  }) : super(key: key);

  @override
  SettingsPageState createState() => SettingsPageState();
}

class SettingsPageState extends State<SettingsPage> {
  bool _isExporting = false;

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
    final isDarkMode = themeProvider.themeMode == ThemeMode.dark;

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
                icon: isDarkMode ? Icons.nights_stay : Icons.wb_sunny,
                iconGradient: AppDesign.getPrimaryGradient(context),
                title: 'Dark Mode',
                description: 'Switch between light and dark themes',
                trailing: _buildModernSwitch(
                  context,
                  value: isDarkMode,
                  onChanged: (value) {
                    themeProvider.toggleTheme();
                  },
                ),
              ),
              const SizedBox(height: AppDesign.spacingXL),

              // Data Section
              _buildSectionHeader(context, 'Data'),
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
              _buildSettingCard(
                context,
                icon: Icons.info_outline,
                iconGradient: AppDesign.getNeutralGradient(context),
                title: 'Version',
                description: 'Budget App v1.2.0',
                trailing: null,
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

  /// Builds a modern switch with custom styling
  Widget _buildModernSwitch(
    BuildContext context, {
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return CupertinoSwitch(
      value: value,
      onChanged: onChanged,
      activeTrackColor: AppDesign.getPrimaryGradient(context).colors.first,
      inactiveTrackColor: AppDesign.getTextTertiary(context).withValues(alpha: 0.3),
    );
  }
}
