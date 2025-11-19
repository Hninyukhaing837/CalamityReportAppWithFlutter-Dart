import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class NotificationListScreen extends StatefulWidget {
  const NotificationListScreen({super.key});

  @override
  State<NotificationListScreen> createState() => _NotificationListScreenState();
}

class _NotificationListScreenState extends State<NotificationListScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String _selectedFilter = 'all';
  bool _isSelectionMode = false;
  Set<String> _selectedNotifications = {};

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('通知履歴'),
        ),
        body: const Center(
          child: Text('ログインしてください'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isSelectionMode 
              ? '${_selectedNotifications.length}件選択中' 
              : '通知履歴',
        ),
        elevation: 0,
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: _exitSelectionMode,
              )
            : null,
        actions: _isSelectionMode
            ? _buildSelectionActions()
            : _buildNormalActions(user.uid),
      ),
      // ✅ FIX 1: Move filter chips to body (not app bar bottom)
      body: Column(
        children: [
          // Filter chips as horizontal list
          _buildFilterList(),
          const Divider(height: 1),
          // Notification list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getNotificationsStream(user.uid),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _buildErrorState(snapshot.error.toString());
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final notifications = snapshot.data?.docs ?? [];

                if (notifications.isEmpty) {
                  return _buildEmptyState();
                }

                // Separate pinned and regular notifications
                final pinnedNotifications = notifications.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return data['pinned'] == true;
                }).toList();

                final regularNotifications = notifications.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return data['pinned'] != true;
                }).toList();

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Pinned section
                    if (pinnedNotifications.isNotEmpty && _selectedFilter != 'pinned') ...[
                      _buildSectionHeader('ピン留め通知', Icons.push_pin, pinnedNotifications.length),
                      const SizedBox(height: 12),
                      ...pinnedNotifications.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildNotificationCard(
                            context,
                            doc.id,
                            data,
                            user.uid,
                            isPinned: true,
                          ),
                        );
                      }).toList(),
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 12),
                    ],

                    // Regular notifications grouped by date
                    if (_selectedFilter == 'pinned') ...[
                      ..._buildGroupedNotifications(pinnedNotifications, user.uid, showPinned: true),
                    ] else ...[
                      ..._buildGroupedNotifications(regularNotifications, user.uid),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ✅ FIX 1: New filter list (scrollable, not chips)
  Widget _buildFilterList() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          _buildFilterItem('all', '全て', Icons.notifications, null),
          _buildFilterItem('pinned', 'ピン留め', Icons.push_pin, Colors.amber),
          _buildFilterItem('favorites', 'お気に入り', Icons.star, Colors.pink),
          _buildFilterItem('unread', '未読', Icons.mark_email_unread, Colors.orange),
          _buildFilterItem('emergency', '緊急', Icons.warning, Colors.red),
          _buildFilterItem('media', 'メディア', Icons.photo_library, Colors.green),
        ],
      ),
    );
  }

  Widget _buildFilterItem(String value, String label, IconData icon, Color? color) {
    final isSelected = _selectedFilter == value;
    final filterColor = color ?? Colors.blue;
    
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: isSelected ? filterColor.withOpacity(0.7) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedFilter = value;
              _selectedNotifications.clear();
              _isSelectionMode = false;
            });
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: isSelected ? Colors.white : Colors.grey.shade700,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey.shade700,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Build section header (for pinned section)
  Widget _buildSectionHeader(String title, IconData icon, int count) {
    return Row(
      children: [
        Icon(icon, color: Colors.amber.shade700, size: 24),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.amber.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.amber.shade900,
            ),
          ),
        ),
      ],
    );
  }

  // Build grouped notifications
  List<Widget> _buildGroupedNotifications(
    List<QueryDocumentSnapshot> notifications,
    String userId, {
    bool showPinned = false,
  }) {
    if (notifications.isEmpty) return [];

    final groupedNotifications = _groupNotificationsByDate(notifications);
    
    return groupedNotifications.map((group) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDateHeader(group),
          const SizedBox(height: 12),
          ...group.notifications.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildNotificationCard(
                context,
                doc.id,
                data,
                userId,
                isPinned: showPinned,
              ),
            );
          }).toList(),
          const SizedBox(height: 12),
        ],
      );
    }).toList();
  }

  // ✅ FIX 3: Updated normal mode actions with selection button
  List<Widget> _buildNormalActions(String userId) {
    return [
      // Enter selection mode button
      IconButton(
        icon: const Icon(Icons.checklist),
        onPressed: _enterSelectionMode,
        tooltip: '選択',
      ),
      // Mark all as read
      IconButton(
        icon: const Icon(Icons.done_all),
        onPressed: () => _showMarkAllReadDialog(context, userId),
        tooltip: 'すべて既読にする',
      ),
      // More options menu
      PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert),
        onSelected: (value) {
          switch (value) {
            case 'clear_all':
              _showClearAllDialog(context, userId);
              break;
            case 'unpin_all':
              _showUnpinAllDialog(context, userId);
              break;
            case 'unfavorite_all':
              _showUnfavoriteAllDialog(context, userId);
              break;
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'clear_all',
            child: Row(
              children: [
                Icon(Icons.delete_sweep, color: Colors.red),
                SizedBox(width: 12),
                Text('すべて削除'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'unpin_all',
            child: Row(
              children: [
                Icon(Icons.push_pin_outlined),
                SizedBox(width: 12),
                Text('すべてピン解除'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'unfavorite_all',
            child: Row(
              children: [
                Icon(Icons.star_outline),
                SizedBox(width: 12),
                Text('すべてお気に入り解除'),
              ],
            ),
          ),
        ],
      ),
    ];
  }

  // Selection mode actions
  List<Widget> _buildSelectionActions() {
    return [
      // Select all
      IconButton(
        icon: const Icon(Icons.select_all),
        onPressed: _selectAll,
        tooltip: 'すべて選択',
      ),
      // More selection options
      PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert),
        onSelected: (value) {
          if (_selectedNotifications.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('通知を選択してください'),
                backgroundColor: Colors.orange,
              ),
            );
            return;
          }
          
          switch (value) {
            case 'delete':
              _deleteSelected(context);
              break;
            case 'pin':
              _pinSelected(context);
              break;
            case 'unpin':
              _unpinSelected(context);
              break;
            case 'favorite':
              _favoriteSelected(context);
              break;
            case 'unfavorite':
              _unfavoriteSelected(context);
              break;
            case 'mark_read':
              _markSelectedAsRead(context);
              break;
            case 'mark_unread':
              _markSelectedAsUnread(context);
              break;
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete, color: Colors.red),
                SizedBox(width: 12),
                Text('削除'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'pin',
            child: Row(
              children: [
                Icon(Icons.push_pin),
                SizedBox(width: 12),
                Text('ピン留め'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'unpin',
            child: Row(
              children: [
                Icon(Icons.push_pin_outlined),
                SizedBox(width: 12),
                Text('ピン解除'),
              ],
            ),
          ),
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: 'favorite',
            child: Row(
              children: [
                Icon(Icons.star, color: Colors.amber),
                SizedBox(width: 12),
                Text('お気に入り'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'unfavorite',
            child: Row(
              children: [
                Icon(Icons.star_outline),
                SizedBox(width: 12),
                Text('お気に入り解除'),
              ],
            ),
          ),
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: 'mark_read',
            child: Row(
              children: [
                Icon(Icons.mark_email_read),
                SizedBox(width: 12),
                Text('既読にする'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'mark_unread',
            child: Row(
              children: [
                Icon(Icons.mark_email_unread),
                SizedBox(width: 12),
                Text('未読にする'),
              ],
            ),
          ),
        ],
      ),
    ];
  }

  // Get filtered notifications stream
  Stream<QuerySnapshot> _getNotificationsStream(String userId) {
    Query query = _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId);

    // Apply filters
    switch (_selectedFilter) {
      case 'unread':
        query = query.where('read', isEqualTo: false);
        break;
      case 'emergency':
        query = query.where('type', isEqualTo: 'emergency');
        break;
      case 'media':
        query = query.where('type', isEqualTo: 'media');
        break;
      case 'favorites':
        query = query.where('favorite', isEqualTo: true);
        break;
      case 'pinned':
        query = query.where('pinned', isEqualTo: true);
        break;
    }

    return query.orderBy('receivedAt', descending: true).limit(100).snapshots();
  }

  // Group notifications by date
  List<NotificationGroup> _groupNotificationsByDate(
    List<QueryDocumentSnapshot> notifications,
  ) {
    final Map<String, List<QueryDocumentSnapshot>> grouped = {};
    
    for (var doc in notifications) {
      final data = doc.data() as Map<String, dynamic>;
      final timestamp = data['receivedAt'] as Timestamp?;
      
      if (timestamp != null) {
        final date = timestamp.toDate();
        final dateKey = _getDateKey(date);
        
        if (!grouped.containsKey(dateKey)) {
          grouped[dateKey] = [];
        }
        grouped[dateKey]!.add(doc);
      }
    }

    // Convert to list and sort by date (newest first)
    final groups = grouped.entries.map((entry) {
      return NotificationGroup(
        dateKey: entry.key,
        date: _parseDateKey(entry.key),
        notifications: entry.value,
      );
    }).toList();

    groups.sort((a, b) => b.date.compareTo(a.date));
    
    return groups;
  }

  String _getDateKey(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) {
      return 'today';
    } else if (dateOnly == yesterday) {
      return 'yesterday';
    } else if (dateOnly.isAfter(today.subtract(const Duration(days: 7)))) {
      return 'this_week';
    } else if (dateOnly.isAfter(today.subtract(const Duration(days: 30)))) {
      return 'this_month';
    } else {
      return DateFormat('yyyy-MM').format(date);
    }
  }

  DateTime _parseDateKey(String key) {
    final now = DateTime.now();
    switch (key) {
      case 'today':
        return now;
      case 'yesterday':
        return now.subtract(const Duration(days: 1));
      case 'this_week':
        return now.subtract(const Duration(days: 3));
      case 'this_month':
        return now.subtract(const Duration(days: 15));
      default:
        try {
          final parts = key.split('-');
          return DateTime(int.parse(parts[0]), int.parse(parts[1]));
        } catch (e) {
          return DateTime.now();
        }
    }
  }

  String _getDateLabel(String dateKey) {
    switch (dateKey) {
      case 'today':
        return '今日';
      case 'yesterday':
        return '昨日';
      case 'this_week':
        return '今週';
      case 'this_month':
        return '今月';
      default:
        try {
          final parts = dateKey.split('-');
          return '${parts[0]}年${parts[1]}月';
        } catch (e) {
          return dateKey;
        }
    }
  }

  // Date header
  Widget _buildDateHeader(NotificationGroup group) {
    final allSelected = group.notifications.every(
      (doc) => _selectedNotifications.contains(doc.id),
    );

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.calendar_today,
                size: 14,
                color: Colors.blue.shade700,
              ),
              const SizedBox(width: 6),
              Text(
                _getDateLabel(group.dateKey),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '(${group.notifications.length})',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue.shade600,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        if (_isSelectionMode)
          TextButton.icon(
            onPressed: () => _toggleGroupSelection(group),
            icon: Icon(
              allSelected ? Icons.check_box : Icons.check_box_outline_blank,
              size: 20,
            ),
            label: Text(allSelected ? 'すべて解除' : 'すべて選択'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.blue.shade700,
            ),
          ),
      ],
    );
  }

  // ✅ FIX 2 & 4: Notification card with image support and full view on tap
  Widget _buildNotificationCard(
    BuildContext context,
    String docId,
    Map<String, dynamic> data,
    String userId, {
    bool isPinned = false,
  }) {
    final title = data['title'] ?? '通知';
    final body = data['body'] ?? '';
    final type = data['type'] ?? 'general';
    final imageUrl = data['imageUrl'] ?? ''; // ✅ Support FCM image
    final read = data['read'] ?? false;
    final pinned = data['pinned'] ?? false;
    final favorite = data['favorite'] ?? false;
    final timestamp = data['receivedAt'] as Timestamp?;
    final isSelected = _selectedNotifications.contains(docId);
    
    // Determine notification type and styling
    final isEmergency = type == 'emergency';
    final isMedia = type == 'media' || imageUrl.isNotEmpty;
    
    Color iconColor;
    Color bgColor;
    IconData icon;
    
    if (isEmergency) {
      iconColor = Colors.red.shade700;
      bgColor = Colors.red.shade50;
      icon = Icons.warning;
    } else if (isMedia) {
      iconColor = Colors.green.shade700;
      bgColor = Colors.green.shade50;
      icon = Icons.photo_library;
    } else {
      iconColor = Colors.blue.shade700;
      bgColor = Colors.blue.shade50;
      icon = Icons.notifications;
    }

    // Special styling for pinned notifications
    Color borderColor;
    if (isSelected) {
      borderColor = Colors.blue.shade700;
    } else if (pinned) {
      borderColor = Colors.amber.shade400;
    } else if (read) {
      borderColor = Colors.grey.shade200;
    } else {
      borderColor = bgColor;
    }

    return Dismissible(
      key: Key(docId),
      direction: _isSelectionMode ? DismissDirection.none : DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 0),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(
          Icons.delete,
          color: Colors.white,
          size: 28,
        ),
      ),
      confirmDismiss: (direction) async {
        return await _showDeleteConfirmation(context, docId);
      },
      onDismissed: (direction) {
        _deleteNotification(docId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('通知を削除しました'),
            duration: Duration(seconds: 2),
          ),
        );
      },
      child: Card(
        elevation: isSelected ? 4 : (pinned ? 3 : (read ? 0 : 2)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: borderColor,
            width: isSelected ? 3 : (pinned ? 2.5 : (read ? 1 : 2)),
          ),
        ),
        child: InkWell(
          // ✅ FIX 4: Show full notification dialog on tap
          onTap: () => _showFullNotificationDialog(context, docId, data),
          onLongPress: () => _handleLongPress(docId),
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              // Main content
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Selection checkbox (in selection mode)
                        if (_isSelectionMode)
                          Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: Checkbox(
                              value: isSelected,
                              onChanged: (value) => _toggleSelection(docId),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        
                        // Icon
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: bgColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            icon,
                            color: iconColor,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        
                        // Content
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      title,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: read ? FontWeight.normal : FontWeight.bold,
                                        color: Colors.grey.shade900,
                                      ),
                                    ),
                                  ),
                                  // Badges
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (pinned && !_isSelectionMode)
                                        Icon(
                                          Icons.push_pin,
                                          size: 16,
                                          color: Colors.amber.shade700,
                                        ),
                                      if (pinned && !_isSelectionMode)
                                        const SizedBox(width: 4),
                                      if (favorite && !_isSelectionMode)
                                        Icon(
                                          Icons.star,
                                          size: 16,
                                          color: Colors.amber.shade700,
                                        ),
                                      if (favorite && !_isSelectionMode)
                                        const SizedBox(width: 4),
                                      if (!read && !_isSelectionMode)
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: Colors.blue.shade700,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                              if (body.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  body,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              if (timestamp != null) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.access_time,
                                      size: 14,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _formatTimestamp(timestamp),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        
                        // Quick actions (not in selection mode)
                        if (!_isSelectionMode)
                          PopupMenuButton<String>(
                            icon: Icon(
                              Icons.more_vert,
                              size: 20,
                              color: Colors.grey.shade600,
                            ),
                            onSelected: (value) {
                              switch (value) {
                                case 'pin':
                                  _togglePin(docId, pinned);
                                  break;
                                case 'favorite':
                                  _toggleFavorite(docId, favorite);
                                  break;
                                case 'mark_read':
                                  _markAsRead(docId);
                                  break;
                                case 'mark_unread':
                                  _markAsUnread(docId);
                                  break;
                                case 'delete':
                                  _showDeleteConfirmation(context, docId).then((confirm) {
                                    if (confirm == true) {
                                      _deleteNotification(docId);
                                    }
                                  });
                                  break;
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'pin',
                                child: Row(
                                  children: [
                                    Icon(
                                      pinned ? Icons.push_pin_outlined : Icons.push_pin,
                                      size: 20,
                                      color: Colors.amber.shade700,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(pinned ? 'ピン解除' : 'ピン留め'),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'favorite',
                                child: Row(
                                  children: [
                                    Icon(
                                      favorite ? Icons.star : Icons.star_outline,
                                      size: 20,
                                      color: Colors.amber.shade700,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(favorite ? 'お気に入り解除' : 'お気に入り'),
                                  ],
                                ),
                              ),
                              const PopupMenuDivider(),
                              PopupMenuItem(
                                value: read ? 'mark_unread' : 'mark_read',
                                child: Row(
                                  children: [
                                    Icon(
                                      read ? Icons.mark_email_unread : Icons.mark_email_read,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(read ? '未読にする' : '既読にする'),
                                  ],
                                ),
                              ),
                              const PopupMenuDivider(),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete, size: 20, color: Colors.red),
                                    SizedBox(width: 12),
                                    Text('削除'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    
                    // ✅ FIX 2: Show image if available
                    if (imageUrl.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          imageUrl,
                          width: double.infinity,
                          height: 200,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: 200,
                              color: Colors.grey.shade200,
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.broken_image,
                                      size: 48,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '画像を読み込めません',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              height: 200,
                              color: Colors.grey.shade200,
                              child: Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              
              // Pinned indicator strip
              if (pinned && !_isSelectionMode)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.amber.shade400,
                          Colors.amber.shade600,
                        ],
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
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

  // ✅ FIX 4: Full notification dialog
  void _showFullNotificationDialog(
    BuildContext context,
    String docId,
    Map<String, dynamic> data,
  ) {
    // Mark as read if not in selection mode
    if (!_isSelectionMode) {
      if (data['read'] != true) {
        _markAsRead(docId);
      }
    } else {
      // In selection mode, toggle selection
      _toggleSelection(docId);
      return;
    }

    final title = data['title'] ?? '通知';
    final body = data['body'] ?? '';
    final imageUrl = data['imageUrl'] ?? '';
    final type = data['type'] ?? 'general';
    final timestamp = data['receivedAt'] as Timestamp?;
    final isEmergency = type == 'emergency';

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isEmergency ? Colors.red.shade50 : Colors.blue.shade50,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isEmergency ? Icons.warning : Icons.notifications,
                    color: isEmergency ? Colors.red.shade700 : Colors.blue.shade700,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isEmergency ? Colors.red.shade900 : Colors.blue.shade900,
                          ),
                        ),
                        if (timestamp != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            _formatTimestamp(timestamp),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            
            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Image if available
                    if (imageUrl.isNotEmpty) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          imageUrl,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: 200,
                              color: Colors.grey.shade200,
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.broken_image,
                                      size: 64,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '画像を読み込めません',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    
                    // Body text
                    if (body.isNotEmpty)
                      Text(
                        body,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade800,
                          height: 1.5,
                        ),
                      )
                    else
                      Text(
                        '内容がありません',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade500,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            
            // Actions
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isEmergency ? Colors.red.shade700 : Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  '閉じる',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'たった今';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}分前';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}時間前';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}日前';
    } else {
      return DateFormat('yyyy/MM/dd HH:mm').format(date);
    }
  }

  // Empty state
  Widget _buildEmptyState() {
    String message;
    String description;
    IconData emptyIcon;
    
    switch (_selectedFilter) {
      case 'pinned':
        message = 'ピン留め通知はありません';
        description = '重要な通知をピン留めすると、ここに表示されます';
        emptyIcon = Icons.push_pin_outlined;
        break;
      case 'favorites':
        message = 'お気に入り通知はありません';
        description = '通知をお気に入りに追加すると、ここに表示されます';
        emptyIcon = Icons.star_outline;
        break;
      case 'unread':
        message = '未読通知はありません';
        description = 'すべての通知を既読にしました';
        emptyIcon = Icons.mark_email_read;
        break;
      case 'emergency':
        message = '緊急通知はありません';
        description = '現在、緊急の通知はありません';
        emptyIcon = Icons.warning_amber;
        break;
      case 'media':
        message = 'メディア通知はありません';
        description = '画像や動画の通知はありません';
        emptyIcon = Icons.photo_library_outlined;
        break;
      default:
        message = '通知はありません';
        description = '新しい通知が届くとここに表示されます';
        emptyIcon = Icons.notifications_none;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            emptyIcon,
            size: 100,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 24),
          Text(
            message,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Error state
  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
          const SizedBox(height: 16),
          Text(
            'エラーが発生しました',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Selection mode methods
  void _enterSelectionMode() {
    setState(() {
      _isSelectionMode = true;
      _selectedNotifications.clear();
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedNotifications.clear();
    });
  }

  void _toggleSelection(String docId) {
    setState(() {
      if (_selectedNotifications.contains(docId)) {
        _selectedNotifications.remove(docId);
      } else {
        _selectedNotifications.add(docId);
      }
    });
  }

  void _toggleGroupSelection(NotificationGroup group) {
    setState(() {
      final allSelected = group.notifications.every(
        (doc) => _selectedNotifications.contains(doc.id),
      );
      
      if (allSelected) {
        for (var doc in group.notifications) {
          _selectedNotifications.remove(doc.id);
        }
      } else {
        for (var doc in group.notifications) {
          _selectedNotifications.add(doc.id);
        }
      }
    });
  }

  Future<void> _selectAll() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final snapshot = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: user.uid)
          .get();

      setState(() {
        _selectedNotifications = snapshot.docs.map((doc) => doc.id).toSet();
      });
    } catch (e) {
      print('❌ Error selecting all: $e');
    }
  }

  void _handleLongPress(String docId) {
    if (!_isSelectionMode) {
      _enterSelectionMode();
      _toggleSelection(docId);
    }
  }

  // Pin/Favorite methods
  Future<void> _togglePin(String docId, bool currentlyPinned) async {
    try {
      await _firestore.collection('notifications').doc(docId).update({
        'pinned': !currentlyPinned,
        'pinnedAt': !currentlyPinned ? FieldValue.serverTimestamp() : null,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              currentlyPinned ? 'ピン解除しました' : '📌 ピン留めしました',
            ),
            backgroundColor: currentlyPinned ? Colors.grey : Colors.amber.shade700,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('❌ Error toggling pin: $e');
    }
  }

  Future<void> _toggleFavorite(String docId, bool currentlyFavorite) async {
    try {
      await _firestore.collection('notifications').doc(docId).update({
        'favorite': !currentlyFavorite,
        'favoritedAt': !currentlyFavorite ? FieldValue.serverTimestamp() : null,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              currentlyFavorite ? 'お気に入り解除しました' : '⭐ お気に入りに追加しました',
            ),
            backgroundColor: currentlyFavorite ? Colors.grey : Colors.pink.shade700,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('❌ Error toggling favorite: $e');
    }
  }

  // Bulk pin/favorite operations
  Future<void> _pinSelected(BuildContext context) async {
    try {
      final batch = _firestore.batch();
      for (var docId in _selectedNotifications) {
        batch.update(
          _firestore.collection('notifications').doc(docId),
          {
            'pinned': true,
            'pinnedAt': FieldValue.serverTimestamp(),
          },
        );
      }
      await batch.commit();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('📌 ${_selectedNotifications.length}件をピン留めしました'),
            backgroundColor: Colors.amber.shade700,
          ),
        );
      }

      _exitSelectionMode();
    } catch (e) {
      print('❌ Error pinning selected: $e');
    }
  }

  Future<void> _unpinSelected(BuildContext context) async {
    try {
      final batch = _firestore.batch();
      for (var docId in _selectedNotifications) {
        batch.update(
          _firestore.collection('notifications').doc(docId),
          {
            'pinned': false,
            'pinnedAt': null,
          },
        );
      }
      await batch.commit();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${_selectedNotifications.length}件のピンを解除しました'),
            backgroundColor: Colors.green,
          ),
        );
      }

      _exitSelectionMode();
    } catch (e) {
      print('❌ Error unpinning selected: $e');
    }
  }

  Future<void> _favoriteSelected(BuildContext context) async {
    try {
      final batch = _firestore.batch();
      for (var docId in _selectedNotifications) {
        batch.update(
          _firestore.collection('notifications').doc(docId),
          {
            'favorite': true,
            'favoritedAt': FieldValue.serverTimestamp(),
          },
        );
      }
      await batch.commit();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⭐ ${_selectedNotifications.length}件をお気に入りに追加しました'),
            backgroundColor: Colors.pink.shade700,
          ),
        );
      }

      _exitSelectionMode();
    } catch (e) {
      print('❌ Error favoriting selected: $e');
    }
  }

  Future<void> _unfavoriteSelected(BuildContext context) async {
    try {
      final batch = _firestore.batch();
      for (var docId in _selectedNotifications) {
        batch.update(
          _firestore.collection('notifications').doc(docId),
          {
            'favorite': false,
            'favoritedAt': null,
          },
        );
      }
      await batch.commit();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${_selectedNotifications.length}件のお気に入りを解除しました'),
            backgroundColor: Colors.green,
          ),
        );
      }

      _exitSelectionMode();
    } catch (e) {
      print('❌ Error unfavoriting selected: $e');
    }
  }

  // Mark as read/unread methods
  Future<void> _markAsRead(String docId) async {
    try {
      await _firestore.collection('notifications').doc(docId).update({
        'read': true,
      });
    } catch (e) {
      print('❌ Error marking as read: $e');
    }
  }

  Future<void> _markAsUnread(String docId) async {
    try {
      await _firestore.collection('notifications').doc(docId).update({
        'read': false,
      });
    } catch (e) {
      print('❌ Error marking as unread: $e');
    }
  }

  Future<void> _markSelectedAsRead(BuildContext context) async {
    try {
      final batch = _firestore.batch();
      for (var docId in _selectedNotifications) {
        batch.update(
          _firestore.collection('notifications').doc(docId),
          {'read': true},
        );
      }
      await batch.commit();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${_selectedNotifications.length}件を既読にしました'),
            backgroundColor: Colors.green,
          ),
        );
      }

      _exitSelectionMode();
    } catch (e) {
      print('❌ Error marking selected as read: $e');
    }
  }

  Future<void> _markSelectedAsUnread(BuildContext context) async {
    try {
      final batch = _firestore.batch();
      for (var docId in _selectedNotifications) {
        batch.update(
          _firestore.collection('notifications').doc(docId),
          {'read': false},
        );
      }
      await batch.commit();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${_selectedNotifications.length}件を未読にしました'),
            backgroundColor: Colors.green,
          ),
        );
      }

      _exitSelectionMode();
    } catch (e) {
      print('❌ Error marking selected as unread: $e');
    }
  }

  // Delete methods
  Future<bool> _showDeleteConfirmation(BuildContext context, String docId) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('通知を削除'),
        content: const Text('この通知を削除しますか?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('削除'),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<void> _deleteSelected(BuildContext context) async {
    if (_selectedNotifications.isEmpty) return;

    final count = _selectedNotifications.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('選択した通知を削除'),
        content: Text('$count件の通知を削除しますか?\nこの操作は取り消せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        final batch = _firestore.batch();
        for (var docId in _selectedNotifications) {
          batch.delete(_firestore.collection('notifications').doc(docId));
        }
        await batch.commit();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ $count件の通知を削除しました'),
              backgroundColor: Colors.green,
            ),
          );
        }

        _exitSelectionMode();
      } catch (e) {
        print('❌ Error deleting selected: $e');
      }
    }
  }

  Future<void> _deleteNotification(String docId) async {
    try {
      await _firestore.collection('notifications').doc(docId).delete();
    } catch (e) {
      print('❌ Error deleting notification: $e');
    }
  }

  Future<void> _showMarkAllReadDialog(BuildContext context, String userId) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('すべて既読にする'),
        content: const Text('すべての通知を既読にしますか?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('既読にする'),
          ),
        ],
      ),
    );

    if (result == true && context.mounted) {
      await _markAllAsRead(userId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ すべての通知を既読にしました'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _showClearAllDialog(BuildContext context, String userId) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('すべての通知を削除'),
        content: const Text('本当にすべての通知を削除しますか?\nこの操作は取り消せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (result == true && context.mounted) {
      await _clearAllNotifications(userId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ すべての通知を削除しました'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _showUnpinAllDialog(BuildContext context, String userId) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('すべてピン解除'),
        content: const Text('すべてのピン留め通知を解除しますか?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('解除'),
          ),
        ],
      ),
    );

    if (result == true && context.mounted) {
      await _unpinAll(userId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ すべてのピンを解除しました'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _showUnfavoriteAllDialog(BuildContext context, String userId) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('すべてお気に入り解除'),
        content: const Text('すべてのお気に入り通知を解除しますか?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('解除'),
          ),
        ],
      ),
    );

    if (result == true && context.mounted) {
      await _unfavoriteAll(userId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ すべてのお気に入りを解除しました'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _markAllAsRead(String userId) async {
    try {
      final notifications = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('read', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (var doc in notifications.docs) {
        batch.update(doc.reference, {'read': true});
      }
      await batch.commit();

      print('✅ All notifications marked as read');
    } catch (e) {
      print('❌ Error marking all as read: $e');
    }
  }

  Future<void> _clearAllNotifications(String userId) async {
    try {
      final notifications = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .get();

      final batch = _firestore.batch();
      for (var doc in notifications.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      print('✅ All notifications cleared');
    } catch (e) {
      print('❌ Error clearing notifications: $e');
    }
  }

  Future<void> _unpinAll(String userId) async {
    try {
      final notifications = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('pinned', isEqualTo: true)
          .get();

      final batch = _firestore.batch();
      for (var doc in notifications.docs) {
        batch.update(doc.reference, {'pinned': false, 'pinnedAt': null});
      }
      await batch.commit();

      print('✅ All pins removed');
    } catch (e) {
      print('❌ Error unpinning all: $e');
    }
  }

  Future<void> _unfavoriteAll(String userId) async {
    try {
      final notifications = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('favorite', isEqualTo: true)
          .get();

      final batch = _firestore.batch();
      for (var doc in notifications.docs) {
        batch.update(doc.reference, {'favorite': false, 'favoritedAt': null});
      }
      await batch.commit();

      print('✅ All favorites removed');
    } catch (e) {
      print('❌ Error unfavoriting all: $e');
    }
  }
}

// Notification Group Model
class NotificationGroup {
  final String dateKey;
  final DateTime date;
  final List<QueryDocumentSnapshot> notifications;

  NotificationGroup({
    required this.dateKey,
    required this.date,
    required this.notifications,
  });
}