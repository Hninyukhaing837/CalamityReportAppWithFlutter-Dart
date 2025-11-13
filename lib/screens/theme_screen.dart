import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class ThemeScreen extends StatelessWidget {
  const ThemeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('テーマの変更'), // "Change Theme"
      ),
      body: Column(
        children: [
          RadioListTile<ThemeMode>(
            title: const Text('ライトテーマ'), // "Light Theme"
            value: ThemeMode.light,
            groupValue: themeProvider.themeMode,
            onChanged: (value) {
              themeProvider.setThemeMode(value!);
            },
          ),
          RadioListTile<ThemeMode>(
            title: const Text('ダークテーマ'), // "Dark Theme"
            value: ThemeMode.dark,
            groupValue: themeProvider.themeMode,
            onChanged: (value) {
              themeProvider.setThemeMode(value!);
            },
          ),
          RadioListTile<ThemeMode>(
            title: const Text('システムデフォルト'), // "System Default"
            value: ThemeMode.system,
            groupValue: themeProvider.themeMode,
            onChanged: (value) {
              themeProvider.setThemeMode(value!);
            },
          ),
        ],
      ),
    );
  }
}