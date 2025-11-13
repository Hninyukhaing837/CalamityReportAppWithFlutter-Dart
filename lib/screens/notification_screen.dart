import 'package:flutter/material.dart';
import 'notification_list_screen.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  bool isNotificationsEnabled = true; // State for enabling/disabling notifications
  bool isEmergencyAlertsEnabled = true; // State for enabling/disabling emergency alerts

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('通知設定'), // "Notification Settings"
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          ListTile(
            title: const Text('通知を有効にする'), // "Enable Notifications"
            trailing: Switch(
              value: isNotificationsEnabled,
              onChanged: (value) {
                setState(() {
                  isNotificationsEnabled = value;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(value
                        ? '通知が有効になりました' // "Notifications enabled"
                        : '通知が無効になりました'), // "Notifications disabled"
                  ),
                );
              },
            ),
          ),
          const Divider(),
          ListTile(
            title: const Text('緊急アラートを受信する'), // "Receive Emergency Alerts"
            trailing: Switch(
              value: isEmergencyAlertsEnabled,
              onChanged: (value) {
                setState(() {
                  isEmergencyAlertsEnabled = value;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(value
                        ? '緊急アラートが有効になりました' // "Emergency alerts enabled"
                        : '緊急アラートが無効になりました'), // "Emergency alerts disabled"
                  ),
                );
              },
            ),
          ),
          const Divider(),
          ListTile(
            title: const Text('通知履歴を見る'), // "View Notification History"
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const NotificationListScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}