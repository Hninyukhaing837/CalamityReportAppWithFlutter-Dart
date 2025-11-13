import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationService {
  static Future<void> initializeFCM() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    // Request permission for notifications (iOS-specific)
    await messaging.requestPermission();

    // Get FCM token
    String? token = await messaging.getToken();
    print('FCM Token: $token');

    // Listen for foreground notifications
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Notification received: ${message.notification?.title}');
    });

    // Listen for background notifications
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  // Background message handler
  static Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    print('Background message received: ${message.notification?.title}');
  }
}