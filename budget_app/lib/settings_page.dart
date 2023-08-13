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
                initialValue: true,
                title: const Text('Light Mode'),
                leading: const Icon(Icons.wb_sunny),
                onToggle: (bool value) {
                  setState(() {
                    _themeMode = value ? ThemeMode.light : _themeMode;
                    // Update the theme in your app & save to shared_preferences
                  });
                },
              ),
              SettingsTile.switchTile(
                initialValue: false,
                title: const Text('Dark Mode'),
                leading: const Icon(Icons.nights_stay),
                onToggle: (bool value) {
                  setState(() {
                    _themeMode = value ? ThemeMode.dark : _themeMode;
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
