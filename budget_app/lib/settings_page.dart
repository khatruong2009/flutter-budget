import 'package:flutter/material.dart';
import 'package:settings_ui/settings_ui.dart';
import 'theme_provider.dart';
import 'package:provider/provider.dart';

class SettingsPage extends StatefulWidget {
  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
// Default value

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SettingsList(
        lightTheme: SettingsThemeData(tileHighlightColor: Colors.blue[50]),
        darkTheme: SettingsThemeData(tileHighlightColor: Colors.grey[800]),
        sections: [
          SettingsSection(
            title: const Text('Appearance'),
            tiles: [
              SettingsTile.switchTile(
                initialValue: Provider.of<ThemeProvider>(context, listen: false)
                        .themeMode ==
                    ThemeMode.light,
                title: Text(Provider.of<ThemeProvider>(context).themeMode ==
                        ThemeMode.light
                    ? 'Light Mode'
                    : 'Dark Mode'),
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
          // Add more settings sections here...
        ],
      ),
    );
  }
}
