import 'package:flutter/material.dart';
import 'package:settings_ui/settings_ui.dart';
import 'theme_provider.dart';
import 'package:provider/provider.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    Key? key,
  }) : super(key: key);

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
                title: Text('Dark Mode'),
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
