import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'direct_chat_screen.dart';
import 'profile_settings_screen.dart';

class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  final currentUser = FirebaseAuth.instance.currentUser;

  String _getDisplayName(Map<String, dynamic> userData) {
    if (userData['name'] != null && userData['name'].toString().isNotEmpty) {
      return userData['name'];
    } else if (userData['email'] != null && userData['email'].toString().isNotEmpty) {
      return userData['email'].toString().split('@')[0];
    }
    return 'Unknown User';
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  Color _getColorFromString(String str) {
    final hash = str.hashCode;
    final colors = [
      Colors.blue,
      Colors.purple,
      Colors.teal,
      Colors.orange,
      Colors.pink,
      Colors.green,
      Colors.red,
      Colors.indigo,
    ];
    return colors[hash.abs() % colors.length];
  }

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return '';
    
    final dateTime = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'たった今';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}分前';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}時間前';
    } else if (difference.inDays == 1) {
      return '昨日';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}日前';
    } else {
      return '${dateTime.month}/${dateTime.day}';
    }
  }

  String _getChatId(String userId1, String userId2) {
    // Create a consistent chat ID by sorting user IDs
    final ids = [userId1, userId2]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  Future<Map<String, dynamic>?> _getLastMessage(String otherUserId) async {
    final chatId = _getChatId(currentUser!.uid, otherUserId);
    
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('direct_messages')
          .doc(chatId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.first.data();
      }
    } catch (e) {
      debugPrint('Error getting last message: $e');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('ログインしてください')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.blue,
        title: const Text(
          'メッセージ',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person, color: Colors.white),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ProfileSettingsScreen(),
                ),
              );
              if (result == true) {
                setState(() {});
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where(FieldPath.documentId, isNotEqualTo: currentUser!.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('エラー: ${snapshot.error}'),
                ],
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text(
                    '他のユーザーがいません',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            );
          }

          final users = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: users.length,
            itemBuilder: (context, index) {
              final userData = users[index].data() as Map<String, dynamic>;
              final userId = users[index].id;
              final userName = _getDisplayName(userData);
              final userColor = _getColorFromString(userId);

              return FutureBuilder<Map<String, dynamic>?>(
                future: _getLastMessage(userId),
                builder: (context, messageSnapshot) {
                  final lastMessage = messageSnapshot.data;
                  final lastMessageText = lastMessage?['content'] as String?;
                  final lastMessageTime = lastMessage?['timestamp'] as Timestamp?;
                  final isFromCurrentUser = lastMessage?['senderId'] == currentUser!.uid;

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      leading: Hero(
                        tag: 'avatar_$userId',
                        child: CircleAvatar(
                          radius: 28,
                          backgroundColor: userColor,
                          child: Text(
                            _getInitials(userName),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ),
                      title: Text(
                        userName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: lastMessageText != null
                          ? Row(
                              children: [
                                if (isFromCurrentUser) ...[
                                  const Icon(Icons.done, size: 14, color: Colors.grey),
                                  const SizedBox(width: 4),
                                ],
                                Expanded(
                                  child: Text(
                                    lastMessageText,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              'メッセージを送信',
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 14,
                              ),
                            ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (lastMessageTime != null)
                            Text(
                              _formatTime(lastMessageTime),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          const SizedBox(height: 4),
                          const Icon(
                            Icons.chevron_right,
                            color: Colors.grey,
                          ),
                        ],
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DirectChatScreen(
                              otherUserId: userId,
                              otherUserName: userName,
                              otherUserColor: userColor,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}