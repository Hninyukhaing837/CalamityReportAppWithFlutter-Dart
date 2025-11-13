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

  late String chatId;

  @override
  void initState() {
    super.initState();
    chatId = _getChatId(currentUser!.uid, widget.otherUserId);
    _scrollController.addListener(_scrollListener);
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

  void _sendMessage() async {
    if (currentUser == null) {
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
      };

      // Add message to the chat
      await FirebaseFirestore.instance
          .collection('direct_messages')
          .doc(chatId)
          .collection('messages')
          .add(messageData);

      // Update chat metadata for both users
      final chatMetadata = {
        'participants': [currentUser!.uid, widget.otherUserId],
        'lastMessage': messageText,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSenderId': currentUser!.uid,
      };

      await FirebaseFirestore.instance
          .collection('direct_messages')
          .doc(chatId)
          .set(chatMetadata, SetOptions(merge: true));

      _scrollToBottom();
    } catch (e) {
      debugPrint('Error sending message: $e');
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

  @override
  Widget build(BuildContext context) {
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
              child: Text(
                widget.otherUserName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
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
                  .doc(chatId)
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

                        // Check if we need date divider
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
                              message: message['content'] ?? '',
                              timestamp: timestamp,
                              isCurrentUser: isCurrentUser,
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
    required String message,
    required Timestamp? timestamp,
    required bool isCurrentUser,
  }) {
    final userColor = isCurrentUser ? _getCurrentUserColor() : widget.otherUserColor;
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
              backgroundColor: userColor,
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
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.7,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isCurrentUser ? userColor : Colors.white,
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
                      if (isCurrentUser) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.done_all,
                          size: 14,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isCurrentUser) const SizedBox(width: 8),
          if (isCurrentUser)
            CircleAvatar(
              radius: 16,
              backgroundColor: userColor,
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
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}