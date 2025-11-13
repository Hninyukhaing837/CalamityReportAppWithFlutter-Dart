import 'package:flutter/material.dart';

class NotificationProvider with ChangeNotifier {
  final List<Map<String, dynamic>> _notifications = [];

  List<Map<String, dynamic>> get notifications => _notifications;

  void addNotification(Map<String, dynamic> notification) {
    _notifications.add(notification);
    notifyListeners(); // Notify listeners to rebuild the UI
  }
}