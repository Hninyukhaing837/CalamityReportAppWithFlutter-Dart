import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/fcm_service.dart';
import 'notification_list_screen.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FCMService _fcmService = FCMService();

  bool _notificationsEnabled = true;
  bool _emergencyAlertsEnabled = true;
  bool _mediaUpdatesEnabled = true;
  bool _notificationSoundEnabled = true;
  String _notificationSoundDuration = 'default';
  bool _isLoadingPreferences = true;

  @override
  void initState() {
    super.initState();
    _loadNotificationPreferences();
    _subscribeToTopics();
  }

  //Load notification preferences from Firestore
  Future<void> _loadNotificationPreferences() async {
    final user = _auth.currentUser;
    if (user == null) {
      setState(() => _isLoadingPreferences = false);
      return;
    }

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _notificationsEnabled = data['notificationsEnabled'] as bool? ?? true;
          _emergencyAlertsEnabled = data['emergencyAlertsEnabled'] as bool? ?? true;
          _mediaUpdatesEnabled = data['mediaUpdatesEnabled'] as bool? ?? true;
          _notificationSoundEnabled = data['notificationSoundEnabled'] as bool? ?? true;
          _notificationSoundDuration = data['notificationSoundDuration'] as String? ?? 'default';
          _isLoadingPreferences = false;
        });
        print('Loaded notification preferences');
      } else {
        setState(() => _isLoadingPreferences = false);
      }
    } catch (e) {
      print('Error loading preferences: $e');
      setState(() => _isLoadingPreferences = false);
    }
  }

  //Save notification preference to Firestore
  Future<void> _saveNotificationPreference(String key, dynamic value) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('users').doc(user.uid).set({
        key: value,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print('Saved $key: $value');
    } catch (e) {
      print('Error saving preference: $e');
    }
  }

  //Subscribe to relevant FCM topics
  Future<void> _subscribeToTopics() async {
    if (_emergencyAlertsEnabled) {
      await _fcmService.subscribeToTopic('emergency');
    }
    if (_mediaUpdatesEnabled) {
      await _fcmService.subscribeToTopic('media_updates');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.medium(
            title: const Text('通知設定'),
            backgroundColor: const Color.fromARGB(255, 156, 200, 244),
            foregroundColor: Colors.white,
          ),
          SliverToBoxAdapter(
            child: _isLoadingPreferences
                ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            )
                : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),

                  _buildSectionHeader('基本設定', Icons.settings),
                  const SizedBox(height: 12),
                  _buildNotificationToggleCard(),
                  const SizedBox(height: 24),

                  // NEW: Sound Settings Section
                  _buildSectionHeader('サウンド設定', Icons.volume_up),
                  const SizedBox(height: 12),
                  _buildSoundSettingsCard(),
                  const SizedBox(height: 24),

                  _buildSectionHeader('通知カテゴリー', Icons.category),
                  const SizedBox(height: 12),
                  _buildTopicSettingsCard(),
                  const SizedBox(height: 24),

                  _buildSectionHeader('履歴', Icons.history),
                  const SizedBox(height: 12),
                  _buildHistoryCard(user),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
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
      child: Column(
        children: [
          SwitchListTile(
            title: const Text(
              '通知を有効にする',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: const Text('アプリからの通知を受信します'),
            value: _notificationsEnabled,
            activeThumbColor: Colors.blue.shade700,
            secondary: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _notificationsEnabled
                    ? Colors.blue.shade50
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _notificationsEnabled
                    ? Icons.notifications_active
                    : Icons.notifications_off,
                color: _notificationsEnabled
                    ? Colors.blue.shade700
                    : Colors.grey.shade600,
              ),
            ),
            onChanged: (value) async {
              setState(() {
                _notificationsEnabled = value;
                if (!value) {
                  _emergencyAlertsEnabled = false;
                  _mediaUpdatesEnabled = false;
                }
              });

              await _saveNotificationPreference('notificationsEnabled', value);

              if (!value) {
                // Unsubscribe from all topics
                await _fcmService.unsubscribeFromTopic('emergency');
                await _fcmService.unsubscribeFromTopic('media_updates');

                // Delete token from device (prevents ALL notifications)
                try {
                  await FirebaseMessaging.instance.deleteToken();
                  print('FCM token deleted from device');
                } catch (e) {
                  print('Error deleting device token: $e');
                }

                // Delete FCM token from Firestore
                final user = _auth.currentUser;
                if (user != null) {
                  try {
                    await _firestore.collection('users').doc(user.uid).update({
                      'fcmToken': FieldValue.delete(),
                      'notificationsEnabled': false,
                      'updatedAt': FieldValue.serverTimestamp(),
                    });
                    print('FCM token deleted from Firestore');
                  } catch (e) {
                    print('Error deleting FCM token: $e');
                  }
                }
              } else {
                // Re-enable: Request new token
                await _fcmService.initialize();
              }

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      value
                          ? '通知が有効になりました'
                          : '通知が無効になりました',
                    ),
                    backgroundColor: value ? Colors.green : Colors.grey,
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  // NEW: Sound Settings Card
  Widget _buildSoundSettingsCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Sound On/Off Toggle
          SwitchListTile(
            title: const Text(
              '通知音を鳴らす',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: const Text('通知が届いたときに音を鳴らします'),
            value: _notificationSoundEnabled && _notificationsEnabled,
            activeThumbColor: Colors.purple.shade700,
            secondary: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (_notificationSoundEnabled && _notificationsEnabled)
                    ? Colors.purple.shade50
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _notificationSoundEnabled && _notificationsEnabled
                    ? Icons.volume_up
                    : Icons.volume_off,
                color: (_notificationSoundEnabled && _notificationsEnabled)
                    ? Colors.purple.shade700
                    : Colors.grey.shade600,
              ),
            ),
            onChanged: _notificationsEnabled
                ? (value) async {
              setState(() {
                _notificationSoundEnabled = value;
              });

              await _saveNotificationPreference('notificationSoundEnabled', value);

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      value
                          ? '🔔 通知音が有効になりました'
                          : '🔕 通知音が無効になりました',
                    ),
                    backgroundColor: value ? Colors.green : Colors.grey,
                  ),
                );
              }
            }
                : null,
          ),

          const Divider(height: 1),

          // Sound Duration Selector
          ListTile(
            enabled: _notificationsEnabled && _notificationSoundEnabled,
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (_notificationsEnabled && _notificationSoundEnabled)
                    ? Colors.orange.shade50
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.music_note,
                color: (_notificationsEnabled && _notificationSoundEnabled)
                    ? Colors.orange.shade700
                    : Colors.grey.shade600,
              ),
            ),
            title: const Text(
              '通知音の長さ',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              _getNotificationSoundLabel(),
              style: TextStyle(
                color: (_notificationsEnabled && _notificationSoundEnabled)
                    ? Colors.grey.shade700
                    : Colors.grey.shade400,
              ),
            ),
            trailing: Icon(
              Icons.chevron_right,
              color: (_notificationsEnabled && _notificationSoundEnabled)
                  ? Colors.grey.shade600
                  : Colors.grey.shade400,
            ),
            onTap: (_notificationsEnabled && _notificationSoundEnabled)
                ? () => _showSoundDurationDialog()
                : null,
          ),
        ],
      ),
    );
  }

  String _getNotificationSoundLabel() {
    switch (_notificationSoundDuration) {
      case 'short':
        return '短い (1-2秒)';
      case 'long':
        return '長い (5-7秒)';
      case 'default':
      default:
        return '標準 (3-4秒)';
    }
  }

  void _showSoundDurationDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.music_note, color: Colors.orange),
            SizedBox(width: 8),
            Text('通知音の長さを選択'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSoundOption(
              dialogContext,
              'short',
              '短い',
              '1-2秒の短い通知音',
              Icons.timer,
              Colors.green,
            ),
            const SizedBox(height: 8),
            _buildSoundOption(
              dialogContext,
              'default',
              '標準',
              '3-4秒の通常の通知音',
              Icons.timer_3,
              Colors.blue,
            ),
            const SizedBox(height: 8),
            _buildSoundOption(
              dialogContext,
              'long',
              '長い',
              '5-7秒の長い通知音',
              Icons.timer_10,
              Colors.orange,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('キャンセル'),
          ),
        ],
      ),
    );
  }

  Widget _buildSoundOption(
      BuildContext dialogContext,
      String value,
      String title,
      String description,
      IconData icon,
      Color color,
      ) {
    final isSelected = _notificationSoundDuration == value;

    return InkWell(
      onTap: () async {
        setState(() {
          _notificationSoundDuration = value;
        });

        await _saveNotificationPreference('notificationSoundDuration', value);

        if (mounted) {
          Navigator.pop(dialogContext);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('通知音を「$title」に設定しました'),
              backgroundColor: Colors.green,
            ),
          );
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.grey.shade50,
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected ? color.withOpacity(0.2) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: isSelected ? color : Colors.grey.shade600,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isSelected ? color : Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: color,
                size: 28,
              ),
          ],
        ),
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
            value: _emergencyAlertsEnabled && _notificationsEnabled,
            activeThumbColor: Colors.red.shade700,
            secondary: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (_emergencyAlertsEnabled && _notificationsEnabled)
                    ? Colors.red.shade50
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.warning,
                color: (_emergencyAlertsEnabled && _notificationsEnabled)
                    ? Colors.red.shade700
                    : Colors.grey.shade600,
              ),
            ),
            onChanged: _notificationsEnabled
                ? (value) async {
              setState(() {
                _emergencyAlertsEnabled = value;
              });

              await _saveNotificationPreference('emergencyAlertsEnabled', value);

              if (value) {
                await _fcmService.subscribeToTopic('emergency');
              } else {
                await _fcmService.unsubscribeFromTopic('emergency');
              }

              if (mounted) {
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
            value: _mediaUpdatesEnabled && _notificationsEnabled,
            activeThumbColor: Colors.green.shade700,
            secondary: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (_mediaUpdatesEnabled && _notificationsEnabled)
                    ? Colors.green.shade50
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.photo_library,
                color: (_mediaUpdatesEnabled && _notificationsEnabled)
                    ? Colors.green.shade700
                    : Colors.grey.shade600,
              ),
            ),
            onChanged: _notificationsEnabled
                ? (value) async {
              setState(() {
                _mediaUpdatesEnabled = value;
              });

              await _saveNotificationPreference('mediaUpdatesEnabled', value);

              if (value) {
                await _fcmService.subscribeToTopic('media_updates');
              } else {
                await _fcmService.unsubscribeFromTopic('media_updates');
              }

              if (mounted) {
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
            }
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(User? user) {
    if (user == null) {
      return Card(
        elevation: 1,
        child: ListTile(
          leading: const Icon(Icons.history),
          title: const Text('通知履歴を見る'),
          subtitle: const Text('過去の通知を確認できます'),
          trailing: const Icon(Icons.chevron_right),
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

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('notifications')
          .where('userId', isEqualTo: user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        final totalCount = snapshot.hasData ? snapshot.data!.docs.length : 0;
        final unreadCount = snapshot.hasData
            ? snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['read'] == false;
        }).length
            : 0;

        return Card(
          elevation: 1,
          child: ListTile(
            leading: Stack(
              children: [
                const Icon(Icons.history),
                if (unreadCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            title: Row(
              children: [
                const Text('通知履歴を見る'),
                if (totalCount > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$totalCount',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            subtitle: Text(
              unreadCount > 0
                  ? '$unreadCount件の未読通知があります'
                  : '過去の通知を確認できます',
            ),
            trailing: const Icon(Icons.chevron_right),
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
      },
    );
  }
}