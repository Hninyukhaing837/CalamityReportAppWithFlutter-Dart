import 'package:flutter/material.dart';

class AppInfoScreen extends StatelessWidget {
  const AppInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('アプリ情報'), // "App Information"
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ListTile(
                leading: const Icon(Icons.info, color: Colors.blue),
                title: const Text(
                  'アプリ名', // "App Name"
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text('災害情報アプリ'),
              ),
            ),
            Card(
              elevation: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ListTile(
                leading: const Icon(Icons.update, color: Colors.green),
                title: const Text(
                  'バージョン', // "Version"
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text('1.0.0'),
              ),
            ),
            Card(
              elevation: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ListTile(
                leading: const Icon(Icons.person, color: Colors.orange),
                title: const Text(
                  '開発者', // "Developer"
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text('Hnin Yu Khaing'),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'このアプリは災害報告のために設計されています。', // "This app is designed for calamity reporting."
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}