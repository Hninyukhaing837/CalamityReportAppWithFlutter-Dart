import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'dart:io' show Platform;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notification_list_screen.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  bool isNotificationsEnabled = true;
  bool isEmergencyAlertsEnabled = true;
  bool isMediaUpdatesEnabled = true;
  late FirebaseMessaging _firebaseMessaging;
  String? _fcmToken;
  bool _isInitialized = false;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _initializeFCM();
  }

  Future<void> _initializeFCM() async {
    try {
      _firebaseMessaging = FirebaseMessaging.instance;

      // Request notification permissions
      final settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      print('✅ Notification permission: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        // Get FCM token
        if (kIsWeb) {
          _fcmToken = await _firebaseMessaging.getToken(
            vapidKey: 'BK-A4HhdrXOJVV0O-CBt4rcmbqKz1O4j5EZktr-J4YJMvmHXCkGJKIOeLOGzpX4Fo_d5CyKs_A5NGyU78vOQUlI',
          );
        } else {
          _fcmToken = await _firebaseMessaging.getToken();
        }

        print('✅ FCM Token: $_fcmToken');

        // Save token to Firestore
        await _saveTokenToFirestore();

        // Listen for token refresh
        _firebaseMessaging.onTokenRefresh.listen((newToken) {
          print('🔄 FCM Token refreshed: $newToken');
          setState(() {
            _fcmToken = newToken;
          });
          _saveTokenToFirestore();
        });

        // Setup message handlers
        _setupMessageHandlers();

        setState(() {
          _isInitialized = true;
        });
      } else {
        print('⚠️ Notification permission denied');
        setState(() {
          isNotificationsEnabled = false;
        });
      }
    } catch (e) {
      print('❌ FCM initialization error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('通知の初期化に失敗しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveTokenToFirestore() async {
    if (_fcmToken == null) return;
    
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('⚠️ No authenticated user');
        return;
      }

      await _firestore.collection('user_tokens').doc(user.uid).set({
        'fcmToken': _fcmToken,
        'platform': kIsWeb ? 'web' : (Platform.isAndroid ? 'android' : 'ios'),
        'updatedAt': FieldValue.serverTimestamp(),
        'userId': user.uid,
        'userEmail': user.email,
      }, SetOptions(merge: true));

      print('✅ Token saved to Firestore');
    } catch (e) {
      print('❌ Error saving token: $e');
    }
  }

  void _setupMessageHandlers() {
    // Foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('📱 Foreground message received');
      print('Title: ${message.notification?.title}');
      print('Body: ${message.notification?.body}');
      print('Data: ${message.data}');

      if (message.notification != null) {
        // Save to Firestore
        _saveNotificationToFirestore(message);
        
        // Show in-app notification
        _showNotification(
          message.notification!.title,
          message.notification!.body,
          message.data,
        );
      }
    });

    // Background message opened
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('🔔 Notification opened app');
      print('Data: ${message.data}');

      // Save to Firestore
      _saveNotificationToFirestore(message);

      if (message.data.isNotEmpty) {
        _handleNotificationData(message.data);
      }
    });

    // Check if app was opened from terminated state
    _firebaseMessaging.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        print('🚀 App opened from terminated state');
        print('Data: ${message.data}');
        
        // Save to Firestore
        _saveNotificationToFirestore(message);
        
        _handleNotificationData(message.data);
      }
    });
  }

  Future<void> _saveNotificationToFirestore(RemoteMessage message) async {
  try {
    final user = _auth.currentUser;
    if (user == null) return;

    // Use message ID to prevent duplicates
    final notificationId = message.messageId ?? 
                          'notif_${DateTime.now().millisecondsSinceEpoch}';

    // Check if already exists
    final existingDoc = await _firestore
        .collection('notifications')
        .doc(notificationId)
        .get();
    
    if (existingDoc.exists) {
      print('⚠️ Notification already saved: $notificationId');
      return;
    }

    // Save with document ID to prevent duplicates
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
      'type': message.data['type'] ?? 'general',
      'messageId': notificationId,
    });

    print('✅ Notification saved to history: $notificationId');
    } catch (e) {
      print('❌ Error saving notification: $e');
    }
  }

  void _showNotification(String? title, String? body, Map<String, dynamic> data) {
    if (!mounted) return;

    final isEmergency = data['type'] == 'emergency' || data['severity'] == 'high';
    
    ScaffoldMessenger.of(context).showSnackBar(
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
                    title ?? '通知',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            if (body != null) ...[
              const SizedBox(height: 4),
              Text(
                body,
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ],
        ),
        duration: Duration(seconds: isEmergency ? 10 : 5),
        action: SnackBarAction(
          label: '開く',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            _handleNotificationData(data);
          },
        ),
      ),
    );
  }

  void _handleNotificationData(Map<String, dynamic> data) {
    print('🔧 Handling notification data: $data');

    if (data['screen'] == 'history' || data['screen'] == 'notifications') {
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const NotificationListScreen(),
          ),
        );
      }
    } else if (data['screen'] == 'media_gallery') {
      print('🖼️ Navigate to media gallery');
    } else if (data['screen'] == 'emergency') {
      print('🚨 Navigate to emergency screen');
    }
  }

  Future<void> _testNotification() async {
    _showNotification(
      'テスト通知',
      'これはテスト通知です。FCMが正しく設定されています。',
      {'type': 'test'},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('通知設定'),
        elevation: 0,
        actions: [
          if (kDebugMode)
            IconButton(
              icon: const Icon(Icons.notifications_active),
              onPressed: _testNotification,
              tooltip: 'テスト通知',
            ),
        ],
      ),
      body: _isInitialized 
        ? _buildMainContent()
        : _buildLoadingState(),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          const Text('通知を初期化しています...'),
          const SizedBox(height: 8),
          Text(
            kIsWeb ? 'Web環境' : 'モバイル環境',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _buildStatusCard(),
        const SizedBox(height: 24),

        _buildSectionHeader('通知設定', Icons.settings),
        const SizedBox(height: 8),
        _buildNotificationToggleCard(),
        const SizedBox(height: 24),

        _buildSectionHeader('受信する通知の種類', Icons.category),
        const SizedBox(height: 8),
        _buildTopicSettingsCard(),
        const SizedBox(height: 24),

        _buildSectionHeader('通知履歴', Icons.history),
        const SizedBox(height: 8),
        _buildHistoryCard(),
      ],
    );
  }

  Widget _buildStatusCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade700, Colors.blue.shade500],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isNotificationsEnabled
                    ? Icons.notifications_active
                    : Icons.notifications_off,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isNotificationsEnabled ? '通知有効' : '通知無効',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isNotificationsEnabled
                        ? 'すべての通知を受信中'
                        : 'すべての通知が無効です',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isNotificationsEnabled ? Icons.check_circle : Icons.cancel,
              color: Colors.white,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.blue.shade700, size: 24),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationToggleCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: SwitchListTile(
        title: const Text(
          '通知を有効にする',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: const Text('アプリからの通知を受信します'),
        value: isNotificationsEnabled,
        activeColor: Colors.blue.shade700,
        secondary: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isNotificationsEnabled
                ? Colors.blue.shade50
                : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            isNotificationsEnabled
                ? Icons.notifications_active
                : Icons.notifications_off,
            color: isNotificationsEnabled
                ? Colors.blue.shade700
                : Colors.grey.shade600,
          ),
        ),
        onChanged: (value) {
          setState(() {
            isNotificationsEnabled = value;
            if (!value) {
              isEmergencyAlertsEnabled = false;
              isMediaUpdatesEnabled = false;
            }
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                value ? '✅ 通知が有効になりました' : '🔕 通知が無効になりました',
              ),
              backgroundColor: value ? Colors.green : Colors.grey,
            ),
          );
        },
      ),
    );
  }

  Widget _buildTopicSettingsCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          SwitchListTile(
            title: const Text(
              '緊急アラート',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: const Text('災害情報などの重要な通知を受信します'),
            value: isEmergencyAlertsEnabled && isNotificationsEnabled,
            activeColor: Colors.red.shade700,
            secondary: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (isEmergencyAlertsEnabled && isNotificationsEnabled)
                    ? Colors.red.shade50
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.warning,
                color: (isEmergencyAlertsEnabled && isNotificationsEnabled)
                    ? Colors.red.shade700
                    : Colors.grey.shade600,
              ),
            ),
            onChanged: isNotificationsEnabled
                ? (value) {
                    setState(() {
                      isEmergencyAlertsEnabled = value;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          value
                              ? '✅ 緊急アラートが有効になりました'
                              : '🔕 緊急アラートが無効になりました',
                        ),
                        backgroundColor: value ? Colors.green : Colors.grey,
                      ),
                    );
                  }
                : null,
          ),
          const Divider(height: 1),
          
          SwitchListTile(
            title: const Text(
              'メディア更新通知',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: const Text('新しい画像や動画がアップロードされた時に通知します'),
            value: isMediaUpdatesEnabled && isNotificationsEnabled,
            activeColor: Colors.green.shade700,
            secondary: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (isMediaUpdatesEnabled && isNotificationsEnabled)
                    ? Colors.green.shade50
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.photo_library,
                color: (isMediaUpdatesEnabled && isNotificationsEnabled)
                    ? Colors.green.shade700
                    : Colors.grey.shade600,
              ),
            ),
            onChanged: isNotificationsEnabled
                ? (value) {
                    setState(() {
                      isMediaUpdatesEnabled = value;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          value
                              ? '✅ メディア更新通知が有効になりました'
                              : '🔕 メディア更新通知が無効になりました',
                        ),
                        backgroundColor: value ? Colors.green : Colors.grey,
                      ),
                    );
                  }
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.purple.shade50,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.history,
            color: Colors.purple.shade700,
            size: 28,
          ),
        ),
        title: const Text(
          '通知履歴を見る',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: const Text('過去の通知を確認できます'),
        trailing: Icon(
          Icons.chevron_right,
          color: Colors.grey.shade400,
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const NotificationListScreen(),
            ),
          );
        },
      ),
    );
  }
}