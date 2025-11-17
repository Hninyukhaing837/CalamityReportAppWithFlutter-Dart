import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DirectChatScreen extends StatefulWidget {
  final String otherUserId;
  final String otherUserName;
  final Color otherUserColor;

  const DirectChatScreen({
    super.key,
    required this.otherUserId,
    required this.otherUserName,
    required this.otherUserColor,
  });

  @override
  State<DirectChatScreen> createState() => _DirectChatScreenState();
}

class _DirectChatScreenState extends State<DirectChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final currentUser = FirebaseAuth.instance.currentUser;
  bool _isComposing = false;
  bool _showScrollButton = false;

  String? _chatId;

  @override
  void initState() {
    super.initState();
    if (currentUser != null) {
      _chatId = _getChatId(currentUser!.uid, widget.otherUserId);
      _scrollController.addListener(_scrollListener);
      // 画面を開いたら既読にする
      _markMessagesAsSeen();
      _updateLastSeen();
    }
  }

  void _scrollListener() {
    if (_scrollController.hasClients) {
      setState(() {
        _showScrollButton = _scrollController.offset > 100;
      });
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  String _getChatId(String userId1, String userId2) {
    final ids = [userId1, userId2]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  String _getCurrentUserName() {
    if (currentUser?.displayName != null && currentUser!.displayName!.isNotEmpty) {
      return currentUser!.displayName!;
    } else if (currentUser?.email != null && currentUser!.email!.isNotEmpty) {
      return currentUser!.email!.split('@')[0];
    }
    return 'User ${currentUser!.uid.substring(0, 8)}';
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  Color _getCurrentUserColor() {
    final hash = currentUser!.uid.hashCode;
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

  // ユーザーのlastSeenを更新
  Future<void> _updateLastSeen() async {
    if (currentUser == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .set({
        'lastSeen': FieldValue.serverTimestamp(),
        'isOnline': true,
      }, SetOptions(merge: true));
    } catch (e) {
    }
  }

  // メッセージを既読(seen)にする
  Future<void> _markMessagesAsSeen() async {
    if (currentUser == null || _chatId == null) return;

    try { 
      // 相手から送られたメッセージで、まだ既読になっていないものを取得
      final unreadMessages = await FirebaseFirestore.instance
          .collection('direct_messages')
          .doc(_chatId)
          .collection('messages')
          .where('senderId', isEqualTo: widget.otherUserId)
          .where('recipientId', isEqualTo: currentUser!.uid)
          .get();

      if (unreadMessages.docs.isEmpty) {
        return;
      }

      // statusがseenでないものだけを既読にする
      final batch = FirebaseFirestore.instance.batch();
      int updateCount = 0;

      for (var doc in unreadMessages.docs) {
        final data = doc.data();
        final currentStatus = data['status'] as String?;
        
        if (currentStatus != 'seen') {
          batch.update(doc.reference, {
            'status': 'seen',
            'seenAt': FieldValue.serverTimestamp(),
          });
          updateCount++;
        }
      }

      if (updateCount > 0) {
        await batch.commit();
      }
    } catch (e) {
    }
  }

  // メッセージ送信
  void _sendMessage() async {
    if (currentUser == null || _chatId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ログインしてください')),
      );
      return;
    }

    final messageText = _messageController.text.trim();
    if (messageText.isEmpty) return;

    setState(() => _isComposing = false);
    _messageController.clear();

    try {
      final messageData = {
        'content': messageText,
        'timestamp': FieldValue.serverTimestamp(),
        'senderId': currentUser!.uid,
        'senderName': _getCurrentUserName(),
        'recipientId': widget.otherUserId,
        'status': 'sent', // 初期ステータス
        'deliveredAt': null,
        'seenAt': null,
      };

      // メッセージを追加
      final docRef = await FirebaseFirestore.instance
          .collection('direct_messages')
          .doc(_chatId)
          .collection('messages')
          .add(messageData);

      // チャットメタデータを更新
      final chatMetadata = {
        'participants': [currentUser!.uid, widget.otherUserId],
        'lastMessage': messageText,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSenderId': currentUser!.uid,
      };

      await FirebaseFirestore.instance
          .collection('direct_messages')
          .doc(_chatId)
          .set(chatMetadata, SetOptions(merge: true));

      // 少し待ってからdeliveredに更新
      await Future.delayed(const Duration(milliseconds: 200));
      await docRef.update({
        'status': 'delivered',
        'deliveredAt': FieldValue.serverTimestamp(),
      });

      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('送信失敗: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // メッセージオプションを表示（削除のみ - 自分のメッセージの場合のみ）
  void _showMessageOptions(BuildContext context, String messageId, String senderId, String content) {
    final isMyMessage = senderId == currentUser?.uid;

    // 自分のメッセージでない場合は何も表示しない
    if (!isMyMessage) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red, size: 24),
              title: const Text(
                'メッセージを削除',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _deleteMessage(messageId);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // メッセージ削除
  Future<void> _deleteMessage(String messageId) async {

    if (currentUser == null || _chatId == null) {
      return;
    }

    // 確認ダイアログ
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Text('メッセージを削除'),
          ],
        ),
        content: const Text(
          'このメッセージを削除しますか？\n\n相手の画面からも削除されます。',
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context, false);
            },
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('削除する'),
          ),
        ],
      ),
    );

    if (shouldDelete != true || !mounted) {
      return;
    }

    try {
      final docRef = FirebaseFirestore.instance
          .collection('direct_messages')
          .doc(_chatId)
          .collection('messages')
          .doc(messageId);

      // 存在確認
      final docSnapshot = await docRef.get();
      
      if (!docSnapshot.exists) {
        throw Exception('メッセージが見つかりません');
      }

      final data = docSnapshot.data()!;
      final senderId = data['senderId'] as String?;

      // 権限確認
      if (senderId != currentUser!.uid) {
        throw Exception('自分のメッセージのみ削除できます');
      }

      // 削除実行
      await docRef.delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('メッセージを削除しました'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('削除失敗: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  String _formatMessageTime(Timestamp? timestamp) {
    if (timestamp == null) return '';
    
    final dateTime = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final timeString = '$hour:$minute';

    if (difference.inDays == 0) {
      return timeString;
    } else if (difference.inDays == 1) {
      return '昨日 $timeString';
    } else if (difference.inDays < 7) {
      final weekdays = ['月', '火', '水', '木', '金', '土', '日'];
      final weekday = weekdays[dateTime.weekday - 1];
      return '$weekday $timeString';
    } else {
      return '${dateTime.month}/${dateTime.day} $timeString';
    }
  }

  Widget _buildDateDivider(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    String label;
    if (difference.inDays == 0) {
      label = '今日';
    } else if (difference.inDays == 1) {
      label = '昨日';
    } else {
      final weekdays = ['月', '火', '水', '木', '金', '土', '日'];
      final weekday = weekdays[date.weekday - 1];
      label = '${date.month}月${date.day}日 ($weekday)';
    }

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // ステータスアイコン
  Widget _buildStatusIndicator(String? status) {
    switch (status) {
      case 'sent':
        return const Icon(Icons.done, size: 14, color: Colors.white70); // Single checkmark
      case 'delivered':
        return const Icon(Icons.done_all, size: 14, color: Colors.white70); // Double checkmark
      case 'seen':
        return const Text(
          'Seen',
          style: TextStyle(fontSize: 12, color: Colors.lightBlueAccent), // "Seen" text
        );
      default:
        return const SizedBox.shrink(); // No indicator for unknown status
    }
  }

  @override
  Widget build(BuildContext context) {
    // chatIdまたはcurrentUserがnullの場合
    if (currentUser == null || _chatId == null) {
      return Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          backgroundColor: widget.otherUserColor,
          title: const Text('チャット'),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red),
              SizedBox(height: 16),
              Text('ログインが必要です'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: widget.otherUserColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Hero(
              tag: 'avatar_${widget.otherUserId}',
              child: CircleAvatar(
                backgroundColor: Colors.white,
                radius: 18,
                child: Text(
                  _getInitials(widget.otherUserName),
                  style: TextStyle(
                    color: widget.otherUserColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.otherUserName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  // オンライン状態表示
                  StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(widget.otherUserId)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasData && snapshot.data!.exists) {
                        final data = snapshot.data!.data() as Map<String, dynamic>;
                        final isOnline = data['isOnline'] as bool? ?? false;
                        final lastSeen = data['lastSeen'] as Timestamp?;
                        
                        if (isOnline && lastSeen != null) {
                          final difference = DateTime.now().difference(lastSeen.toDate());
                          if (difference.inMinutes < 2) {
                            return const Text(
                              'オンライン',
                              style: TextStyle(fontSize: 11, color: Colors.white70),
                            );
                          }
                        }
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('direct_messages')
                  .doc(_chatId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: widget.otherUserColor),
                        const SizedBox(height: 16),
                        const Text('メッセージを読み込み中...'),
                      ],
                    ),
                  );
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
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 80,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'まだメッセージがありません',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '最初のメッセージを送信しましょう！',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final messages = snapshot.data!.docs;

                // メッセージが表示されたら既読にする
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    _markMessagesAsSeen();
                  }
                });

                return Stack(
                  children: [
                    ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final messageDoc = messages[index];
                        final message = messageDoc.data() as Map<String, dynamic>;
                        final isCurrentUser = message['senderId'] == currentUser?.uid;
                        final timestamp = message['timestamp'] as Timestamp?;
                        final status = message['status'] as String?;

                        // 日付区切りの判定
                        bool showDivider = false;
                        if (index < messages.length - 1) {
                          final nextMessage = messages[index + 1].data() as Map<String, dynamic>;
                          final nextTimestamp = nextMessage['timestamp'] as Timestamp?;
                          if (timestamp != null && nextTimestamp != null) {
                            final currentDate = timestamp.toDate();
                            final nextDate = nextTimestamp.toDate();
                            showDivider = currentDate.day != nextDate.day ||
                                currentDate.month != nextDate.month ||
                                currentDate.year != nextDate.year;
                          }
                        } else if (index == messages.length - 1 && timestamp != null) {
                          showDivider = true;
                        }

                        return Column(
                          children: [
                            if (showDivider && timestamp != null)
                              _buildDateDivider(timestamp.toDate()),
                            _buildMessageBubble(
                              messageId: messageDoc.id,
                              message: message['content'] ?? '',
                              timestamp: timestamp,
                              isCurrentUser: isCurrentUser,
                              senderId: message['senderId'] ?? '',
                              status: status,
                            ),
                          ],
                        );
                      },
                    ),
                    if (_showScrollButton)
                      Positioned(
                        right: 16,
                        bottom: 16,
                        child: FloatingActionButton.small(
                          backgroundColor: widget.otherUserColor,
                          onPressed: _scrollToBottom,
                          child: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble({
    required String messageId,
    required String message,
    required Timestamp? timestamp,
    required bool isCurrentUser,
    required String senderId,
    String? status,
  }) {
    const fixedColor = Colors.green; // Set a fixed color for all avatars

    final userName = isCurrentUser ? _getCurrentUserName() : widget.otherUserName;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment:
            isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isCurrentUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: fixedColor, // Use the fixed color
              child: Text(
                _getInitials(userName),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: GestureDetector(
              onTap: isCurrentUser 
                  ? () => _showMessageOptions(context, messageId, senderId, message)
                  : null,
              onLongPress: isCurrentUser
                  ? () => _showMessageOptions(context, messageId, senderId, message)
                  : null,
              child: Column(
                crossAxisAlignment:
                    isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.7,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isCurrentUser ? fixedColor : Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(20),
                        topRight: const Radius.circular(20),
                        bottomLeft: Radius.circular(isCurrentUser ? 20 : 4),
                        bottomRight: Radius.circular(isCurrentUser ? 4 : 20),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          message,
                          style: TextStyle(
                            fontSize: 15,
                            color: isCurrentUser ? Colors.white : Colors.black87,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _formatMessageTime(timestamp),
                              style: TextStyle(
                                fontSize: 10,
                                color: isCurrentUser
                                    ? Colors.white.withOpacity(0.7)
                                    : Colors.grey.shade600,
                              ),
                            ),
                            if (isCurrentUser && status != 'seen') ...[
                              const SizedBox(width: 4),
                              _buildStatusIndicator(status), // Status indicator
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (isCurrentUser && status == 'seen') 
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '既読', 
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.lightGreen,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (isCurrentUser) const SizedBox(width: 8),
          if (isCurrentUser)
            CircleAvatar(
              radius: 16,
              backgroundColor: fixedColor, // Use the fixed color
              child: Text(
                _getInitials(userName),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'メッセージを入力...',
                      hintStyle: TextStyle(color: Colors.grey.shade500),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                    ),
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (text) {
                      setState(() {
                        _isComposing = text.trim().isNotEmpty;
                      });
                    },
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                child: Material(
                  color: _isComposing ? widget.otherUserColor : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(24),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: _isComposing ? _sendMessage : null,
                    child: Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.send_rounded,
                        color: _isComposing ? Colors.white : Colors.grey.shade500,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    // オフライン状態に更新
    if (currentUser != null) {
      FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .update({
        'isOnline': false,
        'lastSeen': FieldValue.serverTimestamp(),
      }).catchError((e) {
      });
    }
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}