import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Top-level function for background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('🔔 Background message received: ${message.messageId}');
  print('Title: ${message.notification?.title}');
  print('Body: ${message.notification?.body}');

  // Save to Firestore even in background
  await FCMService._saveNotificationToFirestoreStatic(message);
}

class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  late FirebaseMessaging _firebaseMessaging;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // NEW: Local notifications plugin for custom sounds
  final FlutterLocalNotificationsPlugin _localNotifications =
  FlutterLocalNotificationsPlugin();

  String? _fcmToken;
  bool _isInitialized = false;

  String? get fcmToken => _fcmToken;
  bool get isInitialized => _isInitialized;

  // Global key for showing SnackBars from anywhere
  static GlobalKey<ScaffoldMessengerState>? _scaffoldMessengerKey;

  static void setScaffoldMessengerKey(GlobalKey<ScaffoldMessengerState> key) {
    _scaffoldMessengerKey = key;
  }

  /// Initialize FCM - Call this in main.dart
  Future<void> initialize() async {
    try {
      print('Initializing FCM Service...');

      _firebaseMessaging = FirebaseMessaging.instance;

      // NEW: Initialize local notifications
      await _initializeLocalNotifications();

      // Set background message handler (must be top-level function)
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Request notification permissions
      final settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
        announcement: false,
        carPlay: false,
        criticalAlert: false,
      );

      print('Notification permission: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {

        // Get FCM token
        await _getToken();

        // Setup message handlers
        _setupMessageHandlers();

        // Listen for token refresh
        _firebaseMessaging.onTokenRefresh.listen((newToken) {
          print('🔄 FCM Token refreshed');
          _fcmToken = newToken;
          _saveTokenToFirestore();
        });

        _isInitialized = true;
        print('✅ FCM Service initialized successfully');
      } else {
        print('⚠️ Notification permission denied');
        _isInitialized = false;
      }
    } catch (e) {
      print('❌ FCM initialization error: $e');
      _isInitialized = false;
    }
  }

  /// NEW: Initialize local notifications for custom sounds
  Future<void> _initializeLocalNotifications() async {
    if (kIsWeb) {
      print('Local notifications not supported on web');
      return;
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        print('Local notification tapped: ${details.payload}');
      },
    );

    // Create Android notification channels programmatically from Dart
    if (Platform.isAndroid) {
      // Default channel
      const AndroidNotificationChannel defaultChannel = AndroidNotificationChannel(
        'default_channel',
        '一般通知',
        description: '一般的な通知',
        importance: Importance.high,
        enableVibration: true,
        showBadge: true,
      );

      // Emergency channel
      const AndroidNotificationChannel emergencyChannel = AndroidNotificationChannel(
        'emergency_channel',
        '緊急通知',
        description: '緊急災害情報',
        importance: Importance.max,
        enableVibration: true,
        showBadge: true,
      );

      // Create channels
      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(defaultChannel);

      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(emergencyChannel);

      print('✅ Android notification channels created from Dart');
    }

    print('✅ Local notifications initialized');
  }

  /// NEW: Update notification channels based on user sound preferences
  /// Call this whenever sound settings change
  Future<void> updateNotificationChannels() async {
    if (kIsWeb || !Platform.isAndroid) {
      print('⚠️ Channel updates only supported on Android');
      return;
    }

    try {
      // Get user's sound preferences
      final preferences = await _getUserSoundPreferences();
      final soundEnabled = preferences['soundEnabled'] as bool;
      final soundDuration = preferences['soundDuration'] as String;

      print('🔄 Updating notification channels - Sound: $soundEnabled, Duration: $soundDuration');

      // Get the Android implementation
      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin == null) {
        print('⚠️ Android plugin not available');
        return;
      }

      // Delete existing channels first (to force update)
      try {
        await androidPlugin.deleteNotificationChannel('default_channel');
        await androidPlugin.deleteNotificationChannel('emergency_channel');
        print('🗑️ Deleted old notification channels');
      } catch (e) {
        print('⚠️ Could not delete old channels (may not exist): $e');
      }

      // Recreate default channel with user preferences
      final defaultChannel = AndroidNotificationChannel(
        'default_channel',
        '一般通知',
        description: '一般的な通知',
        importance: Importance.high,
        enableVibration: true,
        showBadge: true,
        playSound: soundEnabled,
        sound: soundEnabled
            ? RawResourceAndroidNotificationSound(_getSoundFile(soundDuration).replaceAll('.mp3', ''))
            : null,
      );

      // Emergency channel - always with sound (for safety)
      final emergencyChannel = AndroidNotificationChannel(
        'emergency_channel',
        '緊急通知',
        description: '緊急災害情報',
        importance: Importance.max,
        enableVibration: true,
        showBadge: true,
        playSound: true, // Emergency notifications always have sound
        sound: RawResourceAndroidNotificationSound(
          _getSoundFile('long').replaceAll('.mp3', ''), // Emergency uses long sound
        ),
      );

      // Create the updated channels
      await androidPlugin.createNotificationChannel(defaultChannel);
      await androidPlugin.createNotificationChannel(emergencyChannel);

      print('✅ Notification channels updated with sound: ${soundEnabled ? _getSoundFile(soundDuration).replaceAll(".mp3", "") : "silent"}');
    } catch (e) {
      print('❌ Error updating notification channels: $e');
    }
  }

  /// NEW: Get user's sound preferences from Firestore
  Future<Map<String, dynamic>> _getUserSoundPreferences() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return {
          'soundEnabled': true,
          'soundDuration': 'default',
        };
      }

      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'soundEnabled': data['notificationSoundEnabled'] as bool? ?? true,
          'soundDuration': data['notificationSoundDuration'] as String? ?? 'default',
        };
      }
    } catch (e) {
      print('Error getting sound preferences: $e');
    }

    return {
      'soundEnabled': true,
      'soundDuration': 'default',
    };
  }

  /// NEW: Get sound file based on duration preference
  String _getSoundFile(String duration) {
    switch (duration) {
      case 'short':
        return 'notification_short.mp3'; // 1-2 seconds
      case 'long':
        return 'notification_long.mp3';  // 5-7 seconds
      case 'default':
      default:
        return 'notification_default.mp3'; // 3-4 seconds
    }
  }

  /// Get FCM Token
  Future<void> _getToken() async {
    try {
      if (kIsWeb) {
        _fcmToken = await _firebaseMessaging.getToken(
          vapidKey: 'BK-A4HhdrXOJVV0O-CBt4rcmbqKz1O4j5EZktr-J4YJMvmHXCkGJKIOeLOGzpX4Fo_d5CyKs_A5NGyU78vOQUlI',
        );
      } else {
        _fcmToken = await _firebaseMessaging.getToken();
      }

      if (_fcmToken != null) {
        print('✅ FCM Token obtained: ${_fcmToken!.substring(0, 20)}...');
        await _saveTokenToFirestore();
      } else {
        print('⚠️ Failed to get FCM token');
      }
    } catch (e) {
      print('❌ Error getting FCM token: $e');
    }
  }

  /// Save token to Firestore
  Future<void> _saveTokenToFirestore() async {
    if (_fcmToken == null) return;

    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('⚠️ No authenticated user - token not saved');
        return;
      }

      final tokenData = {
        'fcmToken': _fcmToken,
        'platform': kIsWeb ? 'web' : (Platform.isAndroid ? 'android' : 'ios'),
        'updatedAt': FieldValue.serverTimestamp(),
        'userId': user.uid,
        'userEmail': user.email,
        'deviceInfo': {
          'isWeb': kIsWeb,
          'platform': kIsWeb ? 'web' : Platform.operatingSystem,
        },
      };

      // Save to user_tokens collection (for detailed tracking)
      await _firestore.collection('user_tokens').doc(user.uid).set(
        tokenData,
        SetOptions(merge: true),
      );

      // Also save to users collection (for Cloud Functions)
      await _firestore.collection('users').doc(user.uid).set({
        'fcmToken': _fcmToken,
        'fcmUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print('✅ Token saved to Firestore for user: ${user.uid}');
    } catch (e) {
      print('❌ Error saving token: $e');
    }
  }

  /// Setup message handlers for foreground, background, and terminated states
  void _setupMessageHandlers() {
    // 1. FOREGROUND - App is open and in use
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      print('📱 Foreground message received');
      print('Message ID: ${message.messageId}');
      print('Title: ${message.notification?.title}');
      print('Body: ${message.notification?.body}');
      print('Data: ${message.data}');

      if (message.notification != null) {
        // Save to Firestore
        await _saveNotificationToFirestore(message);

        // NEW: Show notification with sound preferences
        await _showNotificationWithSoundPreferences(message);

        // Show in-app notification
        _showInAppNotification(message);
      }
    });

    // 2. BACKGROUND - App is in background, user taps notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('🔔 Notification opened app from background');
      print('Message ID: ${message.messageId}');
      print('Data: ${message.data}');

      // Handle navigation based on data
      _handleNotificationTap(message.data);
    });

    // 3. TERMINATED - App was closed, user taps notification
    _firebaseMessaging.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        print('🚀 App opened from terminated state');
        print('Message ID: ${message.messageId}');
        print('Data: ${message.data}');

        // Handle navigation
        _handleNotificationTap(message.data);
      }
    });
  }

  /// NEW: Show local notification with sound preferences
  Future<void> _showNotificationWithSoundPreferences(RemoteMessage message) async {
    if (kIsWeb) {
      print('Local notifications not supported on web');
      return;
    }

    try {
      // Get user's sound preferences
      final preferences = await _getUserSoundPreferences();
      final soundEnabled = preferences['soundEnabled'] as bool;
      final soundDuration = preferences['soundDuration'] as String;

      print('🔊 Sound preferences - Enabled: $soundEnabled, Duration: $soundDuration');

      // Determine notification priority/importance
      final isEmergency = message.data['type'] == 'emergency' ||
          message.data['severity'] == 'high';

      // Android notification details
      final androidDetails = AndroidNotificationDetails(
        isEmergency ? 'emergency_channel' : 'default_channel',
        isEmergency ? '緊急通知' : '一般通知',
        channelDescription: isEmergency ? '緊急災害情報' : '一般的な通知',
        importance: isEmergency ? Importance.max : Importance.high,
        priority: isEmergency ? Priority.max : Priority.high,
        playSound: soundEnabled,
        sound: soundEnabled
            ? RawResourceAndroidNotificationSound(_getSoundFile(soundDuration).replaceAll('.mp3', ''))
            : null,
        enableVibration: true,
        styleInformation: message.notification?.body != null
            ? BigTextStyleInformation(message.notification!.body!)
            : null,
      );

      // iOS notification details
      final iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: soundEnabled,
        sound: soundEnabled ? _getSoundFile(soundDuration) : null,
        interruptionLevel: isEmergency
            ? InterruptionLevel.critical
            : InterruptionLevel.active,
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // Show the notification
      await _localNotifications.show(
        message.hashCode,
        message.notification?.title ?? '通知',
        message.notification?.body ?? '',
        notificationDetails,
        payload: message.data.toString(),
      );

      print('✅ Local notification shown with sound: ${soundEnabled ? _getSoundFile(soundDuration) : "silent"}');
    } catch (e) {
      print('❌ Error showing local notification: $e');
    }
  }

  /// Save notification to Firestore with duplicate prevention
  Future<void> _saveNotificationToFirestore(RemoteMessage message) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('⚠️ No authenticated user - notification not saved');
        return;
      }

      // Create unique notification ID from message
      final notificationId = message.messageId ??
          'notif_${message.sentTime?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch}';

      print('📝 Saving notification: $notificationId');

      // Check if notification already exists (duplicate prevention)
      final existingDoc = await _firestore
          .collection('notifications')
          .doc(notificationId)
          .get();

      if (existingDoc.exists) {
        print('⚠️ Notification already exists, skipping: $notificationId');
        return;
      }

      // ✅ Extract image URL from multiple sources
      String imageUrl = '';

      // Priority 1: FCM Android notification image
      if (message.notification?.android?.imageUrl != null) {
        imageUrl = message.notification!.android!.imageUrl!;
        print('📸 Image from Android notification: $imageUrl');
      }
      // Priority 2: FCM iOS notification image  
      else if (message.notification?.apple?.imageUrl != null) {
        imageUrl = message.notification!.apple!.imageUrl!;
        print('📸 Image from iOS notification: $imageUrl');
      }
      // Priority 3: Custom data field
      else if (message.data.containsKey('imageUrl') && message.data['imageUrl']!.isNotEmpty) {
        imageUrl = message.data['imageUrl']!;
        print('📸 Image from data payload: $imageUrl');
      }
      // Priority 4: Legacy mediaUrl field
      else if (message.data.containsKey('mediaUrl') && message.data['mediaUrl']!.isNotEmpty) {
        imageUrl = message.data['mediaUrl']!;
        print('📸 Image from mediaUrl: $imageUrl');
      }

      // Save notification
      await _firestore
          .collection('notifications')
          .doc(notificationId)
          .set({
        'userId': user.uid,
        'title': message.notification?.title ?? '',
        'body': message.notification?.body ?? '',
        'data': message.data,
        'receivedAt': FieldValue.serverTimestamp(),
        'read': false,
        'type': message.data['type'] ?? (imageUrl.isNotEmpty ? 'media' : 'general'),
        'imageUrl': imageUrl,
        'messageId': notificationId,
        'sentTime': message.sentTime != null
            ? Timestamp.fromMillisecondsSinceEpoch(message.sentTime!.millisecondsSinceEpoch)
            : FieldValue.serverTimestamp(),
        'pinned': false,
        'favorite': false,
        // Preserve all emergency report data from Cloud Function
        'reportId': message.data['reportId'],
        'reportType': message.data['reportType'],
        'priority': message.data['priority'],
        'reportUserId': message.data['reportUserId'] ?? message.data['userId'],
        'reportUserName': message.data['reportUserName'] ?? message.data['userName'],
        'reportUserEmail': message.data['reportUserEmail'] ?? message.data['userEmail'],
        'distance': message.data['distance'] != null
            ? double.tryParse(message.data['distance'].toString())
            : null,
        'latitude': message.data['latitude'] != null
            ? double.tryParse(message.data['latitude'].toString())
            : null,
        'longitude': message.data['longitude'] != null
            ? double.tryParse(message.data['longitude'].toString())
            : null,
      });

      print('✅ Notification saved');
    } catch (e) {
      print('❌ Error saving notification: $e');
    }
  }

  /// Static method for background handler to save notifications
  static Future<void> _saveNotificationToFirestoreStatic(RemoteMessage message) async {
    try {
      // Get current user
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('⚠️ Background: No authenticated user');
        return;
      }

      final notificationId = message.messageId ??
          'notif_${message.sentTime?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch}';

      print('📝 Background: Saving notification: $notificationId');

      // Check for duplicates
      final existingDoc = await FirebaseFirestore.instance
          .collection('notifications')
          .doc(notificationId)
          .get();

      if (existingDoc.exists) {
        print('⚠️ Background: Notification already exists');
        return;
      }

      // Extract image URL
      String imageUrl = '';
      if (message.notification?.android?.imageUrl != null) {
        imageUrl = message.notification!.android!.imageUrl!;
        print('📸 Background: Image from Android notification: $imageUrl');
      }
      else if (message.notification?.apple?.imageUrl != null) {
        imageUrl = message.notification!.apple!.imageUrl!;
        print('📸 Background: Image from iOS notification: $imageUrl');
      }
      else if (message.data.containsKey('imageUrl') && message.data['imageUrl']!.isNotEmpty) {
        imageUrl = message.data['imageUrl']!;
        print('📸 Background: Image from data payload: $imageUrl');
      }
      else if (message.data.containsKey('mediaUrl') && message.data['mediaUrl']!.isNotEmpty) {
        imageUrl = message.data['mediaUrl']!;
        print('📸 Background: Image from mediaUrl: $imageUrl');
      }

      // Save notification
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(notificationId)
          .set({
        'userId': user.uid,
        'title': message.notification?.title ?? '',
        'body': message.notification?.body ?? '',
        'data': message.data,
        'receivedAt': FieldValue.serverTimestamp(),
        'read': false,
        'type': message.data['type'] ?? (imageUrl.isNotEmpty ? 'media' : 'general'),
        'imageUrl': imageUrl,
        'messageId': notificationId,
        'sentTime': message.sentTime != null
            ? Timestamp.fromMillisecondsSinceEpoch(message.sentTime!.millisecondsSinceEpoch)
            : FieldValue.serverTimestamp(),
        'pinned': false,
        'favorite': false,
        'reportId': message.data['reportId'],
        'reportType': message.data['reportType'],
        'priority': message.data['priority'],
        'reportUserId': message.data['reportUserId'] ?? message.data['userId'],
        'reportUserName': message.data['reportUserName'] ?? message.data['userName'],
        'reportUserEmail': message.data['reportUserEmail'] ?? message.data['userEmail'],
        'distance': message.data['distance'] != null
            ? double.tryParse(message.data['distance'].toString())
            : null,
        'latitude': message.data['latitude'] != null
            ? double.tryParse(message.data['latitude'].toString())
            : null,
        'longitude': message.data['longitude'] != null
            ? double.tryParse(message.data['longitude'].toString())
            : null,
      });

      print('✅ Background: Notification saved');
    } catch (e) {
      print('❌ Background: Error saving notification: $e');
    }
  }

  /// Show in-app notification (SnackBar/Banner)
  void _showInAppNotification(RemoteMessage message) {
    if (_scaffoldMessengerKey?.currentState == null) {
      print('⚠️ No scaffold messenger context available');
      return;
    }

    final scaffoldMessenger = _scaffoldMessengerKey!.currentState!;
    final isEmergency = message.data['type'] == 'emergency' ||
        message.data['severity'] == 'high';

    scaffoldMessenger.showSnackBar(
      SnackBar(
        backgroundColor: isEmergency ? Colors.red : Colors.blue.shade700,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isEmergency ? Icons.warning : Icons.notifications,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    message.notification?.title ?? '通知',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            if (message.notification?.body != null) ...[
              const SizedBox(height: 4),
              Text(
                message.notification!.body!,
                style: const TextStyle(color: Colors.white),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
        duration: Duration(seconds: isEmergency ? 10 : 5),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: '開く',
          textColor: Colors.white,
          onPressed: () {
            _handleNotificationTap(message.data);
          },
        ),
      ),
    );
  }

  /// Handle notification tap - navigate to appropriate screen
  void _handleNotificationTap(Map<String, dynamic> data) {
    print('🔧 Handling notification tap: $data');
    print('📍 Screen requested: ${data['screen']}');

    final screen = data['screen'] as String?;

    switch (screen) {
      case 'notifications':
      case 'history':
        print('→ Navigate to: /notification-history');
        break;

      case 'chat':
        final chatId = data['chatId'];
        print('→ Navigate to: /chat/$chatId');
        break;

      case 'report':
        final reportId = data['reportId'];
        print('→ Navigate to: /report/$reportId');
        break;

      case 'map':
        final lat = data['lat'];
        final lng = data['lng'];
        print('→ Navigate to: /map with lat=$lat, lng=$lng');
        break;

      default:
        print('→ Unknown screen or no screen specified: $screen');
        print('→ Default: Navigate to /notification-history');
    }
  }

  /// Subscribe to FCM topic
  Future<void> subscribeToTopic(String topic) async {
    try {
      if (kIsWeb) {
        print('Topic subscription not supported on web');
        return;
      }

      await _firebaseMessaging.subscribeToTopic(topic);
      print('Subscribed to topic: $topic');
    } catch (e) {
      print('Error subscribing to topic: $e');
    }
  }

  /// Unsubscribe from FCM topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      if (kIsWeb) {
        print('Topic unsubscription not supported on web');
        return;
      }

      await _firebaseMessaging.unsubscribeFromTopic(topic);
      print('Unsubscribed from topic: $topic');
    } catch (e) {
      print('Error unsubscribing from topic: $e');
    }
  }

  /// Delete FCM token (for logout)
  Future<void> deleteToken() async {
    try {
      await _firebaseMessaging.deleteToken();
      _fcmToken = null;
      print('✅ FCM token deleted');
    } catch (e) {
      print('❌ Error deleting token: $e');
    }
  }

  /// Get unread notification count
  Future<int> getUnreadCount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 0;

      final snapshot = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: user.uid)
          .where('read', isEqualTo: false)
          .get();

      return snapshot.docs.length;
    } catch (e) {
      print('❌ Error getting unread count: $e');
      return 0;
    }
  }

  /// Check if user has notification permission
  Future<bool> hasPermission() async {
    final settings = await _firebaseMessaging.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  /// Request notification permission (if not already granted)
  Future<bool> requestPermission() async {
    final settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }
}