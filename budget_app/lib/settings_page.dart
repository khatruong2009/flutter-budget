import 'package:flutter/material.dart';
import 'package:settings_ui/settings_ui.dart';
import 'theme_provider.dart';
import 'transaction_model.dart';
import 'package:provider/provider.dart';

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

    try {
      final transactionModel =
          Provider.of<TransactionModel>(context, listen: false);

      // Get the position of the button for iPad popover positioning
      final RenderBox? box = context.findRenderObject() as RenderBox?;
      final Rect? sharePositionOrigin =
          box != null ? box.localToGlobal(Offset.zero) & box.size : null;

      await transactionModel.exportTransactionsToCSV(sharePositionOrigin);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transactions exported successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting transactions: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SettingsList(
        darkTheme: SettingsThemeData(tileHighlightColor: Colors.grey[800]),
        lightTheme: SettingsThemeData(tileHighlightColor: Colors.blue[50]),
        sections: [
          SettingsSection(
            title: const Text('Appearance'),
            tiles: [
              SettingsTile.switchTile(
                initialValue: Provider.of<ThemeProvider>(context, listen: false)
                        .themeMode ==
                    ThemeMode.dark,
                title: const Text('Dark Mode'),
                leading: Icon(Provider.of<ThemeProvider>(context).themeMode ==
                        ThemeMode.light
                    ? Icons.wb_sunny
                    : Icons.nights_stay),
                onToggle: (bool value) {
                  Provider.of<ThemeProvider>(context, listen: false)
                      .toggleTheme();
                  // Save to shared_preferences if needed
                },
              ),
            ],
          ),
          SettingsSection(
            title: const Text('Data'),
            tiles: [
              SettingsTile.navigation(
                title: const Text('Export Transactions'),
                description: const Text('Export all transactions as CSV'),
                leading: _isExporting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.file_download),
                onPressed: _isExporting
                    ? null
                    : (context) => _exportTransactions(context),
              ),
            ],
          ),
          // Add more settings sections here...
        ],
      ),
    );
  }
}
