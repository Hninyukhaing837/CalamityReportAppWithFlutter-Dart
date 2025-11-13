import 'package:flutter/material.dart';
import 'theme_screen.dart';
import 'app_info_screen.dart';
import 'user_edit_screen.dart'; 

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('設定'), 
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('ユーザー詳細の編集'), 
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const UserEditScreen()),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.color_lens),
            title: const Text('テーマの変更'), // "Change Theme"
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ThemeScreen()),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('アプリ情報'), // "App Information"
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AppInfoScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}