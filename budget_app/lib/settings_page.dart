import 'package:flutter/material.dart';
import 'package:settings_ui/settings_ui.dart';

class SettingsPage extends StatefulWidget {
  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  ThemeMode _themeMode = ThemeMode.system; // Default value

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
                initialValue: _themeMode == ThemeMode.light,
                title: Text(
                    _themeMode == ThemeMode.light ? 'Light Mode' : 'Dark Mode'),
                leading: Icon(_themeMode == ThemeMode.light
                    ? Icons.wb_sunny
                    : Icons.nights_stay),
                onToggle: (bool value) {
                  setState(() {
                    _themeMode = value ? ThemeMode.light : ThemeMode.dark;
                    // Update the theme in your app & save to shared_preferences
                  });
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
