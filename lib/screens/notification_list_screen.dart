import 'dart:convert'; // For JSON parsing
import 'package:flutter/material.dart';

class NotificationListScreen extends StatelessWidget {
  const NotificationListScreen({super.key});

  // Example JSON string for notifications
  final String jsonString = '''
  [
    {
      "title": "緊急アラート",
      "body": "洪水警報が発令されました。避難してください。",
      "timestamp": "2025-11-12T10:00:00Z",
      "type": "emergency"
    },
    {
      "title": "一般通知",
      "body": "新しいアップデートが利用可能です。",
      "timestamp": "2025-11-11T15:00:00Z",
      "type": "general"
    },
    {
      "title": "緊急アラート",
      "body": "地震警報が発令されました。安全な場所に避難してください。",
      "timestamp": "2025-11-10T08:00:00Z",
      "type": "emergency"
    },
    {
      "title": "一般通知",
      "body": "システムメンテナンスが完了しました。",
      "timestamp": "2025-11-09T12:00:00Z",
      "type": "general"
    }
  ]
  '''; // Replace this with actual JSON data from an API or local file

  @override
  Widget build(BuildContext context) {
    // Parse the JSON string into a list of maps
    final List<Map<String, dynamic>> notifications =
        List<Map<String, dynamic>>.from(json.decode(jsonString));

    // Separate notifications by type
    final List<Map<String, dynamic>> emergencyNotifications = notifications
        .where((notification) => notification['type'] == 'emergency')
        .toList();
    final List<Map<String, dynamic>> generalNotifications = notifications
        .where((notification) => notification['type'] == 'general')
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('通知履歴'), // "Notification History"
      ),
      body: ListView(
        children: [
          // Emergency Notifications Section
          if (emergencyNotifications.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                '緊急通知', // "Emergency Notifications"
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ...emergencyNotifications.map((notification) {
              return Card(
                color: Colors.red[50],
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: const Icon(Icons.warning, color: Colors.red),
                  title: Text(notification['title']),
                  subtitle: Text(notification['body']),
                  trailing: Text(
                    notification['timestamp'],
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('通知をタップしました: ${notification['title']}'), // "Tapped on notification"
                      ),
                    );
                  },
                ),
              );
            }),
          ],

          // General Notifications Section
          if (generalNotifications.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                '一般通知', // "General Notifications"
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ...generalNotifications.map((notification) {
              return Card(
                color: Colors.blue[50],
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: const Icon(Icons.info, color: Colors.blue),
                  title: Text(notification['title']),
                  subtitle: Text(notification['body']),
                  trailing: Text(
                    notification['timestamp'],
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('通知をタップしました: ${notification['title']}'), // "Tapped on notification"
                      ),
                    );
                  },
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}