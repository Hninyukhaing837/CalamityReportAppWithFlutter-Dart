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
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  
  // Filtering
  String _selectedFilter = 'all';
  bool _isSelectionMode = false;
  Set<String> _selectedNotifications = {};
  
  List<DocumentSnapshot> _currentNotifications = [];
  List<DocumentSnapshot> _allNotifications = [];
  static const int _pageSize = 10;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  int _currentPage = 1;
  
  //  NEW: Search
  String _searchQuery = '';
  bool _isSearching = false;

  // Date filtering
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
        _currentPage = 1;
      });
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ✅ NEW: 検索テキスト変更リスナー（デバウンス）
  void _onSearchChanged() {
    setState(() => _searchQuery = _searchController.text.toLowerCase());
  }

  //検索フィルター（クライアント側）
  List<DocumentSnapshot> _applySearchFilter(List<DocumentSnapshot> docs) {
    if (_searchQuery.isEmpty) return docs;

    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final title = (data['title'] ?? '').toString().toLowerCase();
      final body = (data['body'] ?? '').toString().toLowerCase();
      return title.contains(_searchQuery) || body.contains(_searchQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('通知履歴', style: TextStyle(fontSize: 16))),
        body: const Center(child: Text('ログインしてください')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isSelectionMode 
              ? '${_selectedNotifications.length}件選択'
              : _isSearching 
                  ? '検索' 
                  : '通知履歴',
          style: const TextStyle(fontSize: 16), 
        ),
        elevation: 0,
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: _exitSelectionMode,
              )
            : _isSearching
                ? IconButton(
                    icon: const Icon(Icons.arrow_back, size: 20),
                    onPressed: () {
                      setState(() {
                        _isSearching = false;
                        _searchController.clear();
                        _searchQuery = '';
                      });
                    },
                  )
                : null,
        actions: _isSelectionMode
            ? _buildSelectionActions()
            : _isSearching
                ? []
                : _buildNormalActions(user.uid),
      ),
      body: Column(
        children: [
          if (_isSearching) _buildSearchBar(),
          if (!_isSearching) _buildFilterList(),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getNotificationsStream(user.uid),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _buildErrorState(snapshot.error.toString());
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final notifications = snapshot.data?.docs ?? [];
                final filtered = _applySearchFilter(notifications);

                if (filtered.isEmpty) {
                  return _buildEmptyState();
                }

                return _buildNotificationsListStream(user.uid, filtered);
              },
            ),
          ),
        ],
      ),
    );
  }

  // Add real-time stream method
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
      case 'report':
        query = query.where('type', isEqualTo: 'report');
        break;
    }

    // Date filters
    if (_startDate != null && _endDate != null) {
      query = query
          .where('receivedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(_startDate!))
          .where('receivedAt', isLessThanOrEqualTo: Timestamp.fromDate(_endDate!));
    }

    return query.orderBy('receivedAt', descending: true).snapshots();
  }

  // フィルターリスト
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
          _buildFilterItem('report', 'レポート', Icons.description, Colors.purple),
        ],
      ),
    );
  }

  Widget _buildFilterItem(String value, String label, IconData icon, Color? color) {
    final isSelected = _selectedFilter == value;
    final filterColor = color ?? Colors.blue;
    
    return StreamBuilder<int>(
      stream: _getNotificationCountStream(value),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        final displayCount = count > 99 ? '99+' : count.toString();
        
        return Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Material(
            color: isSelected ? filterColor : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedFilter = value;
                  _selectedNotifications.clear();
                  _isSelectionMode = false;
                  // Reset pagination
                  _currentPage = 1; 
                  _hasMore = true;
                  _currentNotifications.clear();
                  _allNotifications.clear(); 
                });
              },
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 14,
                      color: isSelected ? Colors.white : Colors.grey.shade700,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      label,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.grey.shade700,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                    // Show count badge for '全て' and '未読'
                    if ((value == 'all' || value == 'unread') && count > 0) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: isSelected 
                              ? Colors.white.withOpacity(0.3)
                              : filterColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          displayCount,
                          style: TextStyle(
                            color: isSelected ? Colors.white : filterColor,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Stream<int> _getNotificationCountStream(String filterType) {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(0);

    Query query = _firestore
        .collection('notifications')
        .where('userId', isEqualTo: user.uid);

    switch (filterType) {
      case 'unread':
        query = query.where('read', isEqualTo: false);
        break;
      case 'report':
        query = query.where('type', isEqualTo: 'report');
      break;
      case 'all':
        // Count all notifications
        break;
      default:
        return Stream.value(0); // Don't show count for other filters
    }

    return query.snapshots().map((snapshot) => snapshot.docs.length);
  }

  Widget _buildNotificationsListStream(String userId, List<DocumentSnapshot> filteredNotifications) {
    // Store all notifications from StreamBuilder
    _allNotifications = filteredNotifications;
    
    // Calculate how many to show based on current page
    final itemsToShow = _currentPage * _pageSize;
    _currentNotifications = _allNotifications.take(itemsToShow).toList();
    
    // Check if there are more to load
    _hasMore = _allNotifications.length > _currentNotifications.length;
    
    if (_currentNotifications.isNotEmpty) {
    }

    final pinnedNotifications = _currentNotifications.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return data['pinned'] == true;
    }).toList();

    final regularNotifications = _currentNotifications.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return data['pinned'] != true;
    }).toList();

    return RefreshIndicator(
      onRefresh: () async {
       setState(() {
          _currentPage = 1;
          _hasMore = _allNotifications.length > _pageSize;
        });
      },
      child: ListView(
        padding: const EdgeInsets.all(12), 
        children: [
          if (pinnedNotifications.isNotEmpty && _selectedFilter != 'pinned') ...[
            _buildSectionHeader('ピン留め通知', Icons.push_pin, pinnedNotifications.length),
            const SizedBox(height: 8),
            ...pinnedNotifications.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildNotificationCard(context, doc.id, data, userId, isPinned: true),
              );
            }),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
          ],
          if (_selectedFilter == 'pinned')
            ..._buildGroupedNotifications(pinnedNotifications, userId, showPinned: true)
          else
            ..._buildGroupedNotifications(regularNotifications, userId),

          if (_hasMore) ...[
            const SizedBox(height: 16),
            Center(
              child: _isLoadingMore
                  ? const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    )
                  : OutlinedButton.icon(
                      onPressed: _loadMoreNotifications,
                      icon: const Icon(Icons.history, size: 18),
                      label: const Text(
                        'さらに表示',
                        style: TextStyle(fontSize: 13),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
          ],

          // No more notifications message
          if (!_hasMore && _currentNotifications.length >= _pageSize) ...[
            const SizedBox(height: 16),
            Center(
              child: Text(
                'すべての通知を表示しました',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
            const SizedBox(height: 16),
        ],
       ],
      ),
    );
  }

  //検索バーを構築
  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'タイトルや本文を検索...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey.shade100,
            ),
          ),
          const SizedBox(height: 8),
          // Date filter row
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _selectDateRange(context),
                  icon: const Icon(Icons.date_range, size: 16),
                  label: Text(
                    _startDate != null && _endDate != null
                        ? '${DateFormat('MM/dd').format(_startDate!)} - ${DateFormat('MM/dd').format(_endDate!)}'
                        : '期間を選択',
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  ),
                ),
              ),
              if (_startDate != null && _endDate != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    setState(() {
                      _startDate = null;
                      _endDate = null;
                      _currentPage = 1;
                    });
                  },
                  tooltip: '期間をクリア',
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.blue.shade600,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = DateTime(
          picked.end.year,
          picked.end.month,
          picked.end.day,
          23,
          59,
          59,
        );
        _currentPage = 1;
      });
    }
  }
  
  // セクションヘッダーを構築
  Widget _buildSectionHeader(String title, IconData icon, int count) {
    return Row(
      children: [
        Icon(icon, color: Colors.amber.shade700, size: 18), // Smaller
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 14, // Smaller
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.amber.shade100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 10, // Smaller
              fontWeight: FontWeight.bold,
              color: Colors.amber.shade900,
            ),
          ),
        ),
      ],
    );
  }

  // 日付グループ化された通知を構築
  List<Widget> _buildGroupedNotifications(
    List<DocumentSnapshot> notifications,
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
          }),
          const SizedBox(height: 12),
        ],
      );
    }).toList();
  }

  // 日付ヘッダーを構築
  Widget _buildDateHeader(NotificationGroup group) {
    final allSelected = group.notifications.every(
      (doc) => _selectedNotifications.contains(doc.id),
    );

    String dateLabel = _getOutlookStyleDateLabel(group.dateKey, group.date);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), // Reduced
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(
          top: BorderSide(color: Colors.grey.shade300, width: 1),
          bottom: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.keyboard_arrow_down,
            size: 16, // Smaller
            color: Colors.grey.shade600,
          ),
          const SizedBox(width: 6),
          Text(
            dateLabel,
            style: TextStyle(
              fontSize: 12, // Smaller
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${group.notifications.length}',
              style: TextStyle(
                fontSize: 9, // Smaller
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade800,
              ),
            ),
          ),
          const Spacer(),
          if (_isSelectionMode)
            IconButton(
              icon: Icon(
                allSelected ? Icons.check_box : Icons.check_box_outline_blank,
                size: 16, // Smaller
                color: Colors.grey.shade700,
              ),
              onPressed: () => _toggleGroupSelection(group.notifications, allSelected),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }

  String _getOutlookStyleDateLabel(String dateKey, DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);
    
    // Calculate week boundaries
    final thisWeekStart = today.subtract(Duration(days: today.weekday - 1));
    final lastWeekStart = thisWeekStart.subtract(const Duration(days: 7));
    
    if (dateOnly == today) {
      return '今日';
    } else if (dateOnly == yesterday) {
      return '昨日';
    } else if (dateOnly.isAfter(thisWeekStart.subtract(const Duration(days: 1)))) {
      return '今週';
    } else if (dateOnly.isAfter(lastWeekStart.subtract(const Duration(days: 1)))) {
      return '先週';
    } else if (date.year == now.year && date.month == now.month) {
      return '今月';
    } else if (date.year == now.year) {
      return '${date.month}月';
    } else {
      return '${date.year}年${date.month}月';
    }
  }

  // 通知グループ化
  List<NotificationGroup> _groupNotificationsByDate(
    List<DocumentSnapshot> notifications,
  ) {
    final Map<String, List<DocumentSnapshot>> grouped = {};
    
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

    // Calculate week boundaries
    final thisWeekStart = today.subtract(Duration(days: today.weekday - 1));
    final lastWeekStart = thisWeekStart.subtract(const Duration(days: 7));

    if (dateOnly == today) {
      return 'today';
    } else if (dateOnly == yesterday) {
      return 'yesterday';
    } else if (dateOnly.isAfter(thisWeekStart.subtract(const Duration(days: 1)))) {
      return 'this_week';
    } else if (dateOnly.isAfter(lastWeekStart.subtract(const Duration(days: 1)))) {
      return 'last_week';
    } else if (date.year == now.year && date.month == now.month) {
      return 'this_month';
    } else {
      return '${date.year}-${date.month.toString().padLeft(2, '0')}';
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
        return now.subtract(Duration(days: now.weekday - 1));
      case 'last_week':
        return now.subtract(Duration(days: now.weekday + 6));
      case 'this_month':
        return DateTime(now.year, now.month, 1);
      default:
        try {
          final parts = key.split('-');
          return DateTime(int.parse(parts[0]), int.parse(parts[1]), 1);
        } catch (e) {
          return DateTime.now();
        }
    }
  }

  // 通知カードを構築（画像表示・検索ハイライト対応）
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
    final read = data['read'] as bool? ?? false;
    final pinned = data['pinned'] as bool? ?? false;
    final favorite = data['favorite'] as bool? ?? false;
    final imageUrl = data['mediaUrl'] ?? data['imageUrl'] ?? '';
    final timestamp = data['receivedAt'] as Timestamp?;

    final isSelected = _selectedNotifications.contains(docId);
    
    Color cardColor;
    Color accentColor;

    switch (type) {
      case 'emergency':
        cardColor = Colors.red.shade50;
        accentColor = Colors.red.shade400;
        break;
      case 'media':
        cardColor = Colors.purple.shade50;
        accentColor = Colors.purple.shade400;
        break;
      default:
        cardColor = read ? Colors.grey.shade50 : Colors.blue.shade50;
        accentColor = Colors.blue.shade400;
    }

    if (pinned) accentColor = Colors.amber.shade600;

    return Dismissible(
      key: Key(docId),
      direction: DismissDirection.endToStart,
      background: Container(
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 12),
        child: const Icon(Icons.delete, color: Colors.white, size: 20),
      ),
      confirmDismiss: (direction) async {
        return await _showDeleteConfirmation(context, docId);
      },
      onDismissed: (direction) {
        _deleteNotification(docId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('通知を削除しました'), duration: Duration(seconds: 2)),
        );
      },
      child: Card(
        elevation: isSelected ? 2 : (read ? 0 : 1),
        margin: EdgeInsets.zero,
        color: isSelected ? Colors.blue.shade50 : (read ? Colors.white : cardColor),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide.none,
        ),
        child: InkWell(
          onTap: () => _showFullNotificationDialog(context, docId, data),
          onLongPress: () => _handleLongPress(docId),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(10), // Reduced padding
            decoration: BoxDecoration(
              border: pinned 
                  ? Border(left: BorderSide(color: accentColor, width: 3))
                  : null,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isSelectionMode)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: Checkbox(
                        value: isSelected,
                        onChanged: (value) => _toggleSelection(docId),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),
                
                // Image or icon - smaller size
                if (imageUrl.isNotEmpty) ...[
                  GestureDetector(
                    onTap: () => _showImageInfoDialog(context, imageUrl, type),
                    child: Container(
                      width: 44, // Smaller
                      height: 44, // Smaller
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                                  strokeWidth: 2,
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            // Simple placeholder without CORS label
                            return Container(
                              color: Colors.grey.shade100,
                              child: Icon(
                                Icons.image,
                                color: Colors.grey.shade400,
                                size: 20,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(5),
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      _getTypeIcon(type),
                      color: accentColor,
                      size: 14, // Smaller
                    ),
                  ),
                ],
                
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildHighlightedText(
                              title,
                              style: TextStyle(
                                fontSize: 12, // Smaller
                                fontWeight: read ? FontWeight.w500 : FontWeight.w600,
                                color: Colors.grey.shade900,
                              ),
                            ),
                          ),
                          if (pinned) Icon(Icons.push_pin, size: 11, color: Colors.amber.shade700),
                          if (favorite) Icon(Icons.star, size: 11, color: Colors.amber.shade700),
                          if (!read) Container(
                            width: 5,
                            height: 5,
                            margin: const EdgeInsets.only(left: 3),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade700,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                      if (body.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        _buildHighlightedText(
                          body,
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600), // Smaller
                          maxLines: 2,
                        ),
                      ],
                      if (timestamp != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          _formatTimestamp(timestamp),
                          style: TextStyle(fontSize: 9, color: Colors.grey.shade500), // Smaller
                        ),
                      ],
                    ],
                  ),
                ),
                
                if (!_isSelectionMode)
                  _buildCompactMenu(docId, pinned, favorite, read),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactMenu(String docId, bool pinned, bool favorite, bool read) {
    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      icon: Icon(Icons.more_vert, size: 18, color: Colors.grey.shade600),
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
              if (confirm == true) _deleteNotification(docId);
            });
            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'pin',
          child: Row(
            children: [
              Icon(pinned ? Icons.push_pin_outlined : Icons.push_pin, size: 16),
              const SizedBox(width: 8),
              Text(pinned ? 'ピン解除' : 'ピン留め', style: const TextStyle(fontSize: 13)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'favorite',
          child: Row(
            children: [
              Icon(favorite ? Icons.star_outline : Icons.star, size: 16),
              const SizedBox(width: 8),
              Text(favorite ? 'お気に入り解除' : 'お気に入り', style: const TextStyle(fontSize: 13)),
            ],
          ),
        ),
        PopupMenuItem(
          value: read ? 'mark_unread' : 'mark_read',
          child: Row(
            children: [
              Icon(read ? Icons.mark_email_unread : Icons.mark_email_read, size: 16),
              const SizedBox(width: 8),
              Text(read ? '未読' : '既読', style: const TextStyle(fontSize: 13)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete, size: 16, color: Colors.red),
              SizedBox(width: 8),
              Text('削除', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'emergency':
        return Icons.warning_rounded;
      case 'chat':
        return Icons.chat_bubble_rounded;
      case 'media':
        return Icons.photo_library_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  IconData _getMediaIcon(String type) {
    switch (type) {
      case 'media':
        return Icons.photo_library;
      case 'emergency':
        return Icons.warning_amber_rounded;
      default:
        return Icons.image;
    }
  }

  void _showImageInfoDialog(BuildContext context, String imageUrl, String type) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.image, color: Colors.blue.shade700),
            const SizedBox(width: 8),
            const Text('画像通知'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Try to show the image
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 150,
                        color: Colors.grey.shade100,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.broken_image, color: Colors.grey.shade400, size: 48),
                            const SizedBox(height: 8),
                            Text(
                              'CORSエラー',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                '画像URL:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              SelectableText(
                imageUrl,
                style: TextStyle(fontSize: 11, color: Colors.blue.shade700),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange.shade700, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'ブラウザのCORSポリシーにより、外部画像は直接表示できない場合があります。',
                        style: TextStyle(fontSize: 11, color: Colors.orange.shade900),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  //検索ハイライト付きテキスト
  Widget _buildHighlightedText(
    String text, {
    TextStyle? style,
    int? maxLines,
  }) {
    if (_searchQuery.isEmpty) {
      return Text(
        text,
        style: style,
        maxLines: maxLines,
        overflow: maxLines != null ? TextOverflow.ellipsis : null,
      );
    }

    final spans = <TextSpan>[];
    final lowerText = text.toLowerCase();
    final lowerQuery = _searchQuery.toLowerCase();
    
    int start = 0;
    int index = lowerText.indexOf(lowerQuery);

    while (index != -1) {
      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index), style: style));
      }
      
      spans.add(TextSpan(
        text: text.substring(index, index + lowerQuery.length),
        style: style?.copyWith(
          backgroundColor: Colors.yellow,
          fontWeight: FontWeight.bold,
        ),
      ));
      
      start = index + lowerQuery.length;
      index = lowerText.indexOf(lowerQuery, start);
    }

    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start), style: style));
    }

    return Text.rich(
      TextSpan(children: spans),
      maxLines: maxLines,
      overflow: maxLines != null ? TextOverflow.ellipsis : null,
    );
  }

  // 通常モードのアクション
  List<Widget> _buildNormalActions(String userId) {
    return [
      IconButton(
        icon: const Icon(Icons.search, size: 20), 
        onPressed: () {
          setState(() => _isSearching = true);
        },
        tooltip: '検索',
      ),
      IconButton(
        icon: const Icon(Icons.checklist, size: 20),
        onPressed: _enterSelectionMode,
        tooltip: '選択',
      ),
      IconButton(
        icon: const Icon(Icons.done_all, size: 20), 
        onPressed: () => _showMarkAllReadDialog(context, userId),
        tooltip: 'すべて既読',
      ),
      PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert, size: 20), 
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
                Icon(Icons.delete_sweep, color: Colors.red, size: 18),
                SizedBox(width: 8),
                Text('すべて削除', style: TextStyle(fontSize: 13)),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'unpin_all',
            child: Row(
              children: [
                Icon(Icons.push_pin_outlined, size: 18),
                SizedBox(width: 8),
                Text('すべてピン解除', style: TextStyle(fontSize: 13)),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'unfavorite_all',
            child: Row(
              children: [
                Icon(Icons.star_outline, size: 18),
                SizedBox(width: 8),
                Text('すべてお気に入り解除', style: TextStyle(fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    ];
  }

  // 選択モードのアクション
  List<Widget> _buildSelectionActions() {
    return [
      IconButton(
        icon: const Icon(Icons.select_all),
        onPressed: _selectAll,
        tooltip: 'すべて選択',
      ),
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

  // 空の状態
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _searchQuery.isNotEmpty ? Icons.search_off : Icons.notifications_none,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty ? '検索結果がありません' : '通知がありません',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
          ),
          if (_searchQuery.isNotEmpty) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
              child: const Text('検索をクリア'),
            ),
          ],
        ],
      ),
    );
  }

  // エラー状態
  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 80, color: Colors.red.shade300),
          const SizedBox(height: 16),
          Text(
            'エラーが発生しました',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              setState(() {});
            },
            child: const Text('再試行'),
          ),
        ],
      ),
    );
  }

  String _getDayOfWeek(DateTime date) {
    const days = ['日', '月', '火', '水', '木', '金', '土'];
    return days[date.weekday % 7];
  }

  // タイムスタンプフォーマット
  String _formatTimestamp(Timestamp timestamp) {
    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    // For recent notifications (less than 1 hour), show relative time
    if (difference.inMinutes < 1) {
      return 'たった今';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}分前';
    }

    // Otherwise show full date with day of week: 11/15(月) 18:30
    final dayOfWeek = _getDayOfWeek(date);
    return '${date.month}/${date.day}($dayOfWeek) ${DateFormat('HH:mm').format(date)}';
  }

  // 通知詳細ダイアログ
  void _showFullNotificationDialog(
    BuildContext context,
    String docId,
    Map<String, dynamic> data,
  ) {
    if (!_isSelectionMode) {
      if (data['read'] != true) {
        _markAsRead(docId);
      }
    } else {
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                              DateFormat('yyyy/MM/dd HH:mm').format(timestamp.toDate()),
                              style: TextStyle(
                                fontSize: 12,
                                color: isEmergency ? Colors.red.shade700 : Colors.blue.shade700,
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
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (body.isNotEmpty) ...[
                      Text(
                        body,
                        style: const TextStyle(fontSize: 16, height: 1.5),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (imageUrl.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () => _showImageInfoDialog(context, imageUrl, type),
                        child: Container(
                          height: 60,
                          width: 60,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _getMediaIcon(type),
                                color: Colors.grey.shade600,
                                size: 24,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '画像',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ヘルパーメソッド
  void _enterSelectionMode() {
    setState(() => _isSelectionMode = true);
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
      
      if (_selectedNotifications.isEmpty) {
        _isSelectionMode = false;
      }
    });
  }

  void _toggleGroupSelection(List<DocumentSnapshot> notifications, bool currentlySelected) {
    setState(() {
      if (currentlySelected) {
        for (var doc in notifications) {
          _selectedNotifications.remove(doc.id);
        }
      } else {
        for (var doc in notifications) {
          _selectedNotifications.add(doc.id);
        }
      }
    });
  }

  Future<void> _loadMoreNotifications() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() => _isLoadingMore = true);

    try {
      // Simulate loading delay for better UX
      await Future.delayed(const Duration(milliseconds: 300));
      
      setState(() {
        _currentPage++; // Increment page
        _isLoadingMore = false;
      });
    } catch (e) {
      print('❌ Error loading more: $e');
      setState(() => _isLoadingMore = false);
    }
  }

  void _selectAll() {
    setState(() {
      _selectedNotifications = _currentNotifications.map((doc) => doc.id).toSet();
    });
  }

  void _handleLongPress(String docId) {
    if (!_isSelectionMode) {
      setState(() {
        _isSelectionMode = true;
        _selectedNotifications.add(docId);
      });
    } else {
      _toggleSelection(docId);
    }
  }

  Future<void> _togglePin(String docId, bool currentPinned) async {
    try {
      await _firestore.collection('notifications').doc(docId).update({
        'pinned': !currentPinned,
        'pinnedAt': !currentPinned ? FieldValue.serverTimestamp() : null,
      });
      
      // await _refreshNotifications();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(currentPinned ? 'ピン解除しました' : '📌 ピン留めしました'),
            backgroundColor: currentPinned ? Colors.grey : Colors.amber.shade700,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('❌ Error toggling pin: $e');
    }
  }

  Future<void> _toggleFavorite(String docId, bool currentFavorite) async {
    try {
      await _firestore.collection('notifications').doc(docId).update({
        'favorite': !currentFavorite,
        'favoritedAt': !currentFavorite ? FieldValue.serverTimestamp() : null,
      });
      
      // Refresh notifications to show changes immediately
      // await _refreshNotifications();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(currentFavorite ? 'お気に入り解除しました' : '⭐ お気に入りに追加しました'),
            backgroundColor: currentFavorite ? Colors.grey : Colors.pink.shade700,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('❌ Error toggling favorite: $e');
    }
  }

  Future<void> _markAsRead(String docId) async {
    try {
      await _firestore.collection('notifications').doc(docId).update({'read': true});
      // await _refreshNotifications();
    } catch (e) {
      print('❌ Error marking as read: $e');
    }
  }

  Future<void> _markAsUnread(String docId) async {
    try {
      await _firestore.collection('notifications').doc(docId).update({'read': false});
      // await _refreshNotifications();
    } catch (e) {
      print('❌ Error marking as unread: $e');
    }
  }

  Future<bool?> _showDeleteConfirmation(BuildContext context, String docId) {
    return showDialog<bool>(
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
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('削除'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteNotification(String docId) async {
    try {
      await _firestore.collection('notifications').doc(docId).delete();
      // ローカルリストからも削除
      // setState(() {
      //   _notifications.removeWhere((doc) => doc.id == docId);
      // });
    } catch (e) {
      print('❌ Error deleting notification: $e');
    }
  }

  Future<void> _deleteSelected(BuildContext context) async {
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
            style: TextButton.styleFrom(foregroundColor: Colors.red),
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

        // ローカルリストからも削除
        // setState(() {
        //   _notifications.removeWhere((doc) => _selectedNotifications.contains(doc.id));
        // });

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

  Future<void> _pinSelected(BuildContext context) async {
    try {
      final batch = _firestore.batch();
      for (var docId in _selectedNotifications) {
        batch.update(
          _firestore.collection('notifications').doc(docId),
          {'pinned': true, 'pinnedAt': FieldValue.serverTimestamp()},
        );
      }
      await batch.commit();

      // await _refreshNotifications();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${_selectedNotifications.length}件をピン留めしました'),
            backgroundColor: Colors.green,
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
          {'pinned': false, 'pinnedAt': null},
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
          {'favorite': true, 'favoritedAt': FieldValue.serverTimestamp()},
        );
      }
      await batch.commit();

      // await _refreshNotifications();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${_selectedNotifications.length}件をお気に入りに追加しました'),
            backgroundColor: Colors.green,
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
          {'favorite': false, 'favoritedAt': null},
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
      print('Error marking selected as read: $e');
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
            content: Text('${_selectedNotifications.length}件を未読にしました'),
            backgroundColor: Colors.green,
          ),
        );
      }

      _exitSelectionMode();
    } catch (e) {
      print('Error marking selected as unread: $e');
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
            style: TextButton.styleFrom(foregroundColor: Colors.red),
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
      // リストをクリア
      // setState(() {
      //   _notifications.clear();
      // });
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
        final batch = _firestore.batch();
        
        // Get all unread notifications for this user
        final snapshot = await _firestore
            .collection('notifications')
            .where('userId', isEqualTo: userId)
            .where('read', isEqualTo: false)
            .get();
  
        for (var doc in snapshot.docs) {
          batch.update(doc.reference, {'read': true});
        }
        
        await batch.commit();
        // await _refreshNotifications();
      } catch (e) {
        print('❌ Error marking all as read: $e');
      }
    }
  
    Future<void> _clearAllNotifications(String userId) async {
      try {
        final batch = _firestore.batch();
        
        final snapshot = await _firestore
            .collection('notifications')
            .where('userId', isEqualTo: userId)
            .get();
  
        for (var doc in snapshot.docs) {
          batch.delete(doc.reference);
        }
        
        await batch.commit();
      } catch (e) {
        print('❌ Error clearing all notifications: $e');
      }
    }
  
    Future<void> _unpinAll(String userId) async {
      try {
        final batch = _firestore.batch();
        
        final snapshot = await _firestore
            .collection('notifications')
            .where('userId', isEqualTo: userId)
            .where('pinned', isEqualTo: true)
            .get();
  
        for (var doc in snapshot.docs) {
          batch.update(doc.reference, {'pinned': false, 'pinnedAt': null});
        }
        
        await batch.commit();
        // await _refreshNotifications();
      } catch (e) {
        print('❌ Error unpinning all: $e');
      }
    }
  
    Future<void> _unfavoriteAll(String userId) async {
      try {
        final batch = _firestore.batch();
        
        final snapshot = await _firestore
            .collection('notifications')
            .where('userId', isEqualTo: userId)
            .where('favorite', isEqualTo: true)
            .get();
  
        for (var doc in snapshot.docs) {
          batch.update(doc.reference, {'favorite': false, 'favoritedAt': null});
        }
        
        await batch.commit();
        // await _refreshNotifications();
      } catch (e) {
        print('❌ Error unfavoriting all: $e');
      }
    }
  }
  
  class NotificationGroup {
    final String dateKey;
    final DateTime date;
    final List<DocumentSnapshot> notifications;
  
    NotificationGroup({
      required this.dateKey,
      required this.date,
      required this.notifications,
    });
  }