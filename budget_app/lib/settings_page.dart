import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import 'backup.dart';
import 'design_system.dart';
import 'recurring_transaction.dart';
import 'recurring_transaction_model.dart';
import 'recurring_transactions_page.dart';
import 'theme_provider.dart';
import 'transaction_generator.dart';
import 'transaction_model.dart';
import 'app_settings_provider.dart';
import 'category_provider.dart';
import 'category_settings_page.dart';
import 'categorization_settings_page.dart';
import 'categorization_provider.dart';
import 'storage/atomic_financial_store.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    Key? key,
  }) : super(key: key);

  @override
  SettingsPageState createState() => SettingsPageState();
}

class SettingsPageState extends State<SettingsPage> {
  bool _isExporting = false;
  bool _isImporting = false;
  bool _isBackingUp = false;
  bool _isRestoring = false;
  late Future<String> _versionFuture;

  bool get _dataBusy =>
      _isExporting || _isImporting || _isBackingUp || _isRestoring;

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

  Future<void> _importTransactions(BuildContext context) async {
    setState(() {
      _isImporting = true;
    });

    final messenger = ScaffoldMessenger.maybeOf(context);
    final transactionModel =
        Provider.of<TransactionModel>(context, listen: false);

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );

      final bytes = result?.files.single.bytes;
      if (result == null || bytes == null) {
        // User cancelled the picker.
        return;
      }

      final content = utf8.decode(bytes, allowMalformed: true);
      final summary = transactionModel.parseTransactionsCsv(content);

      if (summary.transactions.isEmpty) {
        if (!mounted) return;
        final errorCount = summary.rowErrors.length;
        final String message;
        if (errorCount > 0) {
          message = summary.duplicateCount > 0
              ? 'No new transactions: ${summary.duplicateCount} duplicates '
                  'skipped, $errorCount rows could not be read'
              : 'No transactions imported: $errorCount rows could not be read';
        } else {
          message = summary.duplicateCount > 0
              ? 'All transactions in this file already exist'
              : 'No transactions found in this file';
        }
        messenger?.showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: errorCount > 0 ? AppColors.expense : null,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDesign.radiusM),
            ),
          ),
        );
        return;
      }

      if (!context.mounted) return;

      final confirmed = await _confirmImport(context, summary);
      if (confirmed != true) {
        return;
      }

      if (!mounted) return;

      await transactionModel.importTransactions(summary.transactions);

      if (!mounted) return;

      messenger?.showSnackBar(
        SnackBar(
          content: Text(summary.duplicateCount > 0
              ? 'Imported ${summary.transactions.length} transactions, '
                  '${summary.duplicateCount} duplicates skipped'
              : 'Imported ${summary.transactions.length} transactions'),
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
          content: Text('Could not import: $e'),
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
          _isImporting = false;
        });
      }
    }
  }

  /// Show confirmation dialog before importing parsed transactions.
  Future<bool?> _confirmImport(
    BuildContext context,
    CsvImportSummary summary,
  ) {
    final count = summary.transactions.length;
    final details = <String>[];
    if (summary.duplicateCount > 0) {
      details.add('${summary.duplicateCount} duplicates will be skipped');
    }
    if (summary.rowErrors.isNotEmpty) {
      details.add('${summary.rowErrors.length} rows could not be read');
    }

    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppDesign.getCardColor(dialogContext),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDesign.radiusL),
          ),
          title: Text(
            'Import $count transactions?',
            style: AppTypography.headingMedium.copyWith(
              color: AppDesign.getTextPrimary(dialogContext),
            ),
          ),
          content: details.isEmpty
              ? null
              : Text(
                  details.join('\n'),
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppDesign.getTextSecondary(dialogContext),
                  ),
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                'Cancel',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppDesign.getTextSecondary(dialogContext),
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                'Import',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.getAccent(
                      Theme.of(dialogContext).brightness == Brightness.dark),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _exportBackup(BuildContext context) async {
    setState(() {
      _isBackingUp = true;
    });

    final messenger = ScaffoldMessenger.maybeOf(context);

    try {
      final transactionModel =
          Provider.of<TransactionModel>(context, listen: false);
      final recurringModel =
          Provider.of<RecurringTransactionModel>(context, listen: false);
      final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
      final categoryProvider =
          Provider.of<CategoryProvider>(context, listen: false);
      final appSettings =
          Provider.of<AppSettingsProvider>(context, listen: false);
      final categorizationProvider =
          Provider.of<CategorizationProvider>(context, listen: false);

      // Get the position of the button for iPad popover positioning
      final RenderBox? box = context.findRenderObject() as RenderBox?;
      final Rect? sharePositionOrigin =
          box != null ? box.localToGlobal(Offset.zero) & box.size : null;

      final backupData = BackupData(
        transactions: transactionModel.transactions,
        netWorthEntries: transactionModel.netWorthEntries,
        categoryBudgetLimits: transactionModel.categoryBudgetLimits,
        savingsGoals: transactionModel.savingsGoals,
        recurringTransactions: recurringModel.recurringTransactions,
        themeMode: themeProvider.themeMode,
        categories: categoryProvider.categories,
        transactionTags: categorizationProvider.tags,
        categorizationRules: categorizationProvider.rules,
        baseCurrencyCode: appSettings.baseCurrencyCode,
        localeOverride: appSettings.localeOverride,
        appLockEnabled: appSettings.appLockEnabled,
        autoLockTimeoutSeconds: appSettings.autoLockTimeoutSeconds,
        hideBalances: appSettings.hideBalances,
      );

      final version = await _versionFuture;
      final json = encodeBackup(
        backupData,
        appVersion: version,
        exportedAt: DateTime.now(),
      );

      final tempDir = await getTemporaryDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filePath = '${tempDir.path}/budgie_backup_$timestamp.json';

      final file = File(filePath);
      await file.writeAsString(json);

      await Share.shareXFiles(
        [XFile(filePath)],
        subject: 'Budgie Backup',
        sharePositionOrigin: sharePositionOrigin,
      );

      if (!mounted) return;

      messenger?.showSnackBar(
        SnackBar(
          content: const Text('Backup exported'),
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
          content: Text('Could not export backup: $e'),
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
          _isBackingUp = false;
        });
      }
    }
  }

  Future<void> _importBackup(BuildContext context) async {
    setState(() {
      _isRestoring = true;
    });

    final messenger = ScaffoldMessenger.maybeOf(context);
    final transactionModel =
        Provider.of<TransactionModel>(context, listen: false);
    final recurringModel =
        Provider.of<RecurringTransactionModel>(context, listen: false);
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final categoryProvider =
        Provider.of<CategoryProvider>(context, listen: false);
    final appSettings =
        Provider.of<AppSettingsProvider>(context, listen: false);
    final categorizationProvider =
        Provider.of<CategorizationProvider>(context, listen: false);

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );

      final bytes = result?.files.single.bytes;
      if (result == null || bytes == null) {
        // User cancelled the picker.
        return;
      }

      final content = utf8.decode(bytes, allowMalformed: true);
      final BackupData data = decodeBackup(content);

      if (!context.mounted) return;

      final confirmed = await _confirmRestore(context, data);
      if (confirmed != true) {
        return;
      }

      if (!mounted) return;

      // The restore sequence operates on app-scoped providers and must run to
      // completion even if this page is disposed mid-way; only the UI
      // feedback afterwards needs the widget alive.
      await AtomicFinancialStore.instance.updateSections({
        FinancialSections.transactions:
            data.transactions.map((item) => item.toJson()).toList(),
        FinancialSections.netWorthEntries:
            data.netWorthEntries.map((item) => item.toJson()).toList(),
        FinancialSections.selectedNetWorthMonth:
            transactionModel.selectedNetWorthMonth.toIso8601String(),
        FinancialSections.categoryBudgetLimits: data.categoryBudgetLimits,
        FinancialSections.savingsGoals:
            data.savingsGoals.map((item) => item.toJson()).toList(),
        FinancialSections.recurringTransactions:
            data.recurringTransactions.map((item) => item.toJson()).toList(),
        FinancialSections.categories:
            data.categories.map((item) => item.toJson()).toList(),
        FinancialSections.transactionTags:
            data.transactionTags.map((item) => item.toJson()).toList(),
        FinancialSections.categorizationRules:
            data.categorizationRules.map((item) => item.toJson()).toList(),
        FinancialSections.appSettings: {
          'baseCurrencyCode': data.baseCurrencyCode,
          'localeOverride': data.localeOverride,
          'appLockEnabled': data.appLockEnabled,
          'autoLockTimeoutSeconds': data.autoLockTimeoutSeconds,
          'hideBalances': data.hideBalances,
        },
      });
      await transactionModel.restoreFromBackup(
        transactions: data.transactions,
        netWorthEntries: data.netWorthEntries,
        categoryBudgetLimits: data.categoryBudgetLimits,
        savingsGoals: data.savingsGoals,
      );
      await recurringModel.restoreFromBackup(data.recurringTransactions);
      await categoryProvider.restoreFromBackup(data.categories);
      await categorizationProvider.restoreFromBackup(
        tags: data.transactionTags,
        rules: data.categorizationRules,
      );
      await appSettings.restoreFromBackup(
        baseCurrencyCode: data.baseCurrencyCode,
        localeOverride: data.localeOverride,
        appLockEnabled: data.appLockEnabled,
        autoLockTimeoutSeconds: data.autoLockTimeoutSeconds,
        hideBalances: data.hideBalances,
      );
      if (data.themeMode != null) {
        await themeProvider.setThemeMode(data.themeMode!);
      }

      // Fill in recurring occurrences that came due after the backup was
      // exported; otherwise they stay missing until the next cold launch.
      await TransactionGenerator(
        transactionModel: transactionModel,
        recurringModel: recurringModel,
      ).generateDueTransactions();

      if (!mounted) return;

      messenger?.showSnackBar(
        SnackBar(
          content: const Text('Backup restored'),
          backgroundColor: AppColors.income,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDesign.radiusM),
          ),
        ),
      );
    } on FormatException catch (e) {
      if (!mounted) return;

      messenger?.showSnackBar(
        SnackBar(
          content: Text('Could not import backup: ${e.message}'),
          backgroundColor: AppColors.expense,
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
          content: Text('Could not import backup: $e'),
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
          _isRestoring = false;
        });
      }
    }
  }

  /// Show a destructive confirmation dialog before a full-replace restore.
  Future<bool?> _confirmRestore(BuildContext context, BackupData data) {
    final message = 'This will import ${data.transactions.length} '
        'transactions, ${data.netWorthEntries.length} net worth entries, '
        '${data.categoryBudgetLimits.length} budgets, '
        '${data.savingsGoals.length} goals and '
        '${data.recurringTransactions.length} recurring templates, '
        'replacing everything currently in Budgie. This cannot be undone.';

    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppDesign.getCardColor(dialogContext),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDesign.radiusL),
          ),
          title: Text(
            'Replace all data?',
            style: AppTypography.headingMedium.copyWith(
              color: AppDesign.getTextPrimary(dialogContext),
            ),
          ),
          content: Text(
            message,
            style: AppTypography.bodyMedium.copyWith(
              color: AppDesign.getTextSecondary(dialogContext),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                'Cancel',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppDesign.getTextSecondary(dialogContext),
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                'Replace',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.expense,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final currentThemeMode = themeProvider.themeMode;
    final transactionModel = context.watch<TransactionModel>();
    final recurringModel = context.watch<RecurringTransactionModel>();
    final appSettings = context.watch<AppSettingsProvider>();
    final categoryProvider = context.watch<CategoryProvider>();
    final categorizationProvider = context.watch<CategorizationProvider>();

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
              const _SectionEyebrow(label: 'PERSONALIZATION'),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: GlowListCard(
                  children: [
                    _SettingsRow(
                      isDark: isDark,
                      icon: Symbols.category_rounded,
                      iconColor: AppColors.getAccent(isDark),
                      title: 'Categories',
                      subtitle:
                          '${categoryProvider.categories.where((category) => !category.isArchived).length} active · custom names, icons, and order',
                      trailing: Icon(
                        Symbols.chevron_right_rounded,
                        size: 20,
                        color: AppColors.getTextTertiaryColor(isDark),
                      ),
                      onTap: () => Navigator.of(context).push(
                        CupertinoPageRoute(
                          builder: (_) => const CategorySettingsPage(),
                        ),
                      ),
                    ),
                    _SettingsRow(
                      isDark: isDark,
                      icon: Symbols.auto_awesome_rounded,
                      iconColor: AppColors.getInfo(isDark),
                      title: 'Tags & rules',
                      subtitle:
                          '${categorizationProvider.tags.length} tags · ${categorizationProvider.rules.length} rules',
                      trailing: Icon(
                        Symbols.chevron_right_rounded,
                        size: 20,
                        color: AppColors.getTextTertiaryColor(isDark),
                      ),
                      onTap: () => Navigator.of(context).push(
                        CupertinoPageRoute(
                          builder: (_) => const CategorizationSettingsPage(),
                        ),
                      ),
                    ),
                    _SettingsRow(
                      isDark: isDark,
                      icon: Symbols.payments_rounded,
                      iconColor: AppColors.getIncome(isDark),
                      title: 'Currency',
                      subtitle: _currencyLabel(appSettings.baseCurrencyCode),
                      trailing: Icon(
                        Symbols.chevron_right_rounded,
                        size: 20,
                        color: AppColors.getTextTertiaryColor(isDark),
                      ),
                      onTap: () => _chooseCurrency(context, appSettings),
                    ),
                    _SettingsRow(
                      isDark: isDark,
                      icon: Symbols.language_rounded,
                      iconColor: AppColors.getInfo(isDark),
                      title: 'Number format',
                      subtitle: _localeLabel(appSettings.localeOverride),
                      trailing: Icon(
                        Symbols.chevron_right_rounded,
                        size: 20,
                        color: AppColors.getTextTertiaryColor(isDark),
                      ),
                      onTap: () => _chooseLocale(context, appSettings),
                    ),
                  ],
                ),
              ),
              const _SectionEyebrow(label: 'PRIVACY'),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: GlowListCard(
                  children: [
                    _SettingsRow(
                      isDark: isDark,
                      icon: Symbols.lock_rounded,
                      iconColor: AppColors.getAccent(isDark),
                      title: 'App lock',
                      subtitle: appSettings.appLockEnabled
                          ? 'Lock after ${_lockTimeoutLabel(appSettings.autoLockTimeoutSeconds)}'
                          : 'Require device authentication',
                      trailing: Switch.adaptive(
                        value: appSettings.appLockEnabled,
                        onChanged: appSettings.setAppLockEnabled,
                      ),
                      onTap: null,
                    ),
                    if (appSettings.appLockEnabled)
                      _SettingsRow(
                        isDark: isDark,
                        icon: Symbols.timer_rounded,
                        iconColor: AppColors.getInfo(isDark),
                        title: 'Lock delay',
                        subtitle: _lockTimeoutLabel(
                            appSettings.autoLockTimeoutSeconds),
                        trailing: Icon(
                          Symbols.chevron_right_rounded,
                          size: 20,
                          color: AppColors.getTextTertiaryColor(isDark),
                        ),
                        onTap: () => _chooseLockTimeout(context, appSettings),
                      ),
                    _SettingsRow(
                      isDark: isDark,
                      icon: Symbols.visibility_off_rounded,
                      iconColor: AppColors.getWarning(isDark),
                      title: 'Hide balances',
                      subtitle: 'Mask amounts throughout the app',
                      trailing: Switch.adaptive(
                        value: appSettings.hideBalances,
                        onChanged: appSettings.setHideBalances,
                      ),
                      onTap: null,
                    ),
                    _SettingsRow(
                      isDark: isDark,
                      icon: Symbols.privacy_tip_rounded,
                      iconColor: AppColors.getInfo(isDark),
                      title: 'Privacy details',
                      subtitle: 'What stays local and when data is shared',
                      trailing: Icon(
                        Symbols.chevron_right_rounded,
                        size: 20,
                        color: AppColors.getTextTertiaryColor(isDark),
                      ),
                      onTap: () => _showPrivacyDetails(context),
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
                      onTap:
                          _dataBusy ? null : () => _exportTransactions(context),
                    ),
                    _SettingsRow(
                      isDark: isDark,
                      icon: Symbols.file_upload_rounded,
                      iconColor: AppColors.getAccent(isDark),
                      iconBackground:
                          AppColors.getAccent(isDark).withValues(alpha: 0.12),
                      title: 'Import from CSV',
                      subtitle: 'Add transactions from a file',
                      trailing: _isImporting
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
                      onTap:
                          _dataBusy ? null : () => _importTransactions(context),
                    ),
                    _SettingsRow(
                      isDark: isDark,
                      icon: Symbols.backup_rounded,
                      iconColor: AppColors.getIncome(isDark),
                      iconBackground:
                          AppColors.getIncome(isDark).withValues(alpha: 0.12),
                      title: 'Export backup',
                      subtitle: 'Everything, as a JSON file',
                      trailing: _isBackingUp
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
                      onTap: _dataBusy ? null : () => _exportBackup(context),
                    ),
                    _SettingsRow(
                      isDark: isDark,
                      icon: Symbols.settings_backup_restore_rounded,
                      iconColor: AppColors.getAccent(isDark),
                      iconBackground:
                          AppColors.getAccent(isDark).withValues(alpha: 0.12),
                      title: 'Import backup',
                      subtitle: 'Restore everything (replaces current data)',
                      trailing: _isRestoring
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
                      onTap: _dataBusy ? null : () => _importBackup(context),
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

  String _currencyLabel(String code) =>
      '${_supportedCurrencies[code] ?? code} ($code)';

  String _localeLabel(String? locale) =>
      locale == null ? 'Match device' : (_supportedLocales[locale] ?? locale);

  String _lockTimeoutLabel(int seconds) {
    if (seconds == 0) return 'Immediately';
    if (seconds < 60) return '$seconds seconds';
    return '${seconds ~/ 60} minute${seconds == 60 ? '' : 's'}';
  }

  Future<void> _chooseCurrency(
    BuildContext context,
    AppSettingsProvider settings,
  ) async {
    final selected = await _showChoiceSheet<String>(
      context,
      title: 'Base currency',
      current: settings.baseCurrencyCode,
      choices: _supportedCurrencies,
    );
    if (selected != null) await settings.setBaseCurrencyCode(selected);
  }

  Future<void> _chooseLocale(
    BuildContext context,
    AppSettingsProvider settings,
  ) async {
    final choices = <String, String>{
      'device': 'Match device',
      ..._supportedLocales,
    };
    final selected = await _showChoiceSheet<String>(
      context,
      title: 'Number format',
      current: settings.localeOverride ?? 'device',
      choices: choices,
    );
    if (selected != null) {
      await settings.setLocaleOverride(selected == 'device' ? null : selected);
    }
  }

  Future<void> _chooseLockTimeout(
    BuildContext context,
    AppSettingsProvider settings,
  ) async {
    const choices = <int, String>{
      0: 'Immediately',
      30: '30 seconds',
      60: '1 minute',
      300: '5 minutes',
      900: '15 minutes',
    };
    final selected = await _showChoiceSheet<int>(
      context,
      title: 'Lock delay',
      current: settings.autoLockTimeoutSeconds,
      choices: choices,
    );
    if (selected != null) {
      await settings.setAutoLockTimeoutSeconds(selected);
    }
  }

  Future<T?> _showChoiceSheet<T>(
    BuildContext context, {
    required String title,
    required T current,
    required Map<T, String> choices,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.75,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(AppDesign.spacingM),
                child: Text(title, style: AppTypography.headingMedium),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final entry in choices.entries)
                      ListTile(
                        title: Text(entry.value),
                        trailing: entry.key == current
                            ? Icon(
                                Symbols.check_rounded,
                                color: AppColors.getAccent(
                                  Theme.of(sheetContext).brightness ==
                                      Brightness.dark,
                                ),
                              )
                            : null,
                        onTap: () => Navigator.pop(sheetContext, entry.key),
                      ),
                    const SizedBox(height: AppDesign.spacingS),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPrivacyDetails(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppDesign.getCardColor(dialogContext),
        title: const Text('Your data in Budgie'),
        content: const Text(
          'Transactions, budgets, goals, settings, quick-entry parsing, and '
          'insights are processed and stored on this device. Budgie does not '
          'use a cloud account or send financial data to an AI service.\n\n'
          'Data leaves Budgie only when you choose an export, backup, or share '
          'action. Files are not encrypted after you share them, so choose '
          'their destination carefully.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}

const _supportedCurrencies = <String, String>{
  'USD': 'US Dollar',
  'CAD': 'Canadian Dollar',
  'EUR': 'Euro',
  'GBP': 'British Pound',
  'AUD': 'Australian Dollar',
  'JPY': 'Japanese Yen',
  'CNY': 'Chinese Yuan',
  'INR': 'Indian Rupee',
  'KRW': 'South Korean Won',
  'MXN': 'Mexican Peso',
  'BRL': 'Brazilian Real',
};

const _supportedLocales = <String, String>{
  'en_US': 'English (United States)',
  'en_CA': 'English (Canada)',
  'en_GB': 'English (United Kingdom)',
  'en_AU': 'English (Australia)',
  'de_DE': 'German (Germany)',
  'fr_FR': 'French (France)',
  'es_ES': 'Spanish (Spain)',
  'ja_JP': 'Japanese (Japan)',
};

/// Accent-gradient tinted brand card: Budgie mark + privacy summary.
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
                  'Local by default · no cloud account',
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
