import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
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
  bool _isLoadingPreferences = true;

  @override
  void initState() {
    super.initState();
    _loadNotificationPreferences();
    _subscribeToTopics();
  }

  /// Load notification preferences from Firestore
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

  /// Save notification preference to Firestore
  Future<void> _saveNotificationPreference(String key, bool value) async {
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

  /// Subscribe to relevant FCM topics
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
            backgroundColor: Colors.blue.shade700,
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
            activeColor: Colors.blue.shade700,
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

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      value 
                          ? '✅ 通知が有効になりました' 
                          : '🔕 通知が無効になりました\n履歴から確認できます',
                    ),
                    backgroundColor: value ? Colors.green : Colors.grey,
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
            },
          ),
          if (!_notificationsEnabled)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '通知は履歴に保存されます。緊急通知は常に表示されます。',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
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
            activeColor: Colors.red.shade700,
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
            activeColor: Colors.green.shade700,
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