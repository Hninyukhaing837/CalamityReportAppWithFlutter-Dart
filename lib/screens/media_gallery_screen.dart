import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/media_service.dart';
import 'media_preview_screen.dart';
import 'media_upload_screen.dart';
import 'media_map_view_screen.dart';

class MediaGalleryScreen extends StatefulWidget {
  final String? incidentCase;

  const MediaGalleryScreen({
    super.key,
    this.incidentCase,
  });

  @override
  State<MediaGalleryScreen> createState() => _MediaGalleryScreenState();
}

class _MediaGalleryScreenState extends State<MediaGalleryScreen> {
  final MediaService _mediaService = MediaService();
  String _filterType = 'all'; // 'all', 'image', 'video'
  bool _showOnlyWithLocation = false;

  Stream<QuerySnapshot> _getMediaStream() {
    if (widget.incidentCase != null) {
      return _mediaService.getMediaByIncident(widget.incidentCase!);
    } else if (_showOnlyWithLocation) {
      return _mediaService.getMediaWithLocation();
    } else {
      return _mediaService.getUserMedia();
    }
  }

  List<DocumentSnapshot> _filterMedia(List<DocumentSnapshot> docs) {
    if (_filterType == 'all') return docs;
    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return data['type'] == _filterType;
    }).toList();
  }

  Future<void> _deleteMedia(String mediaId, String storagePath) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('削除確認'),
        content: const Text('このメディアを削除しますか？\n\nこの操作は取り消せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _mediaService.deleteMedia(mediaId, storagePath);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ 削除しました'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('削除失敗: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('フィルター'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('すべて'),
              value: 'all',
              groupValue: _filterType,
              onChanged: (value) {
                setState(() => _filterType = value!);
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('画像のみ'),
              value: 'image',
              groupValue: _filterType,
              onChanged: (value) {
                setState(() => _filterType = value!);
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('ビデオのみ'),
              value: 'video',
              groupValue: _filterType,
              onChanged: (value) {
                setState(() => _filterType = value!);
                Navigator.pop(context);
              },
            ),
            const Divider(),
            SwitchListTile(
              title: const Text('位置情報付きのみ'),
              value: _showOnlyWithLocation,
              onChanged: (value) {
                setState(() => _showOnlyWithLocation = value);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showMediaOptions(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final hasLocation = data['latitude'] != null && data['longitude'] != null;

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
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.open_in_full, color: Colors.blue),
              title: const Text('プレビュー'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MediaPreviewScreen(
                      mediaId: doc.id,
                      url: data['downloadUrl'],
                      type: data['type'],
                      latitude: data['latitude'],
                      longitude: data['longitude'],
                      incidentCase: data['incidentCase'],
                      timestamp: (data['uploadedAt'] as Timestamp?)?.toDate(),
                      userName: data['userName'],
                    ),
                  ),
                );
              },
            ),
            if (hasLocation)
              ListTile(
                leading: const Icon(Icons.map, color: Colors.green),
                title: const Text('地図で表示'),
                onTap: () {
                  Navigator.pop(context);
                  
                  // Web環境ではメッセージダイアログを表示
                  if (kIsWeb) {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue.shade700),
                            const SizedBox(width: 12),
                            const Text('マップ表示'),
                          ],
                        ),
                        content: const Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'マップ表示はWebではサポートされていません。',
                              style: TextStyle(fontSize: 16),
                            ),
                            SizedBox(height: 12),
                            Text(
                              'モバイルアプリでご利用ください。',
                              style: TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('閉じる'),
                          ),
                        ],
                      ),
                    );
                  } else {
                    // モバイル環境では通常のマップ画面を表示
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MediaMapViewScreen(
                          mediaId: doc.id,
                          latitude: data['latitude'],
                          longitude: data['longitude'],
                          type: data['type'],
                          downloadUrl: data['downloadUrl'],
                          incidentCase: data['incidentCase'],
                        ),
                      ),
                    );
                  }
                },
              ),
            ListTile(
              leading: const Icon(Icons.info_outline, color: Colors.orange),
              title: const Text('詳細情報'),
              onTap: () {
                Navigator.pop(context);
                _showMediaDetails(doc);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('削除'),
              onTap: () {
                Navigator.pop(context);
                _deleteMedia(doc.id, data['storagePath']);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _showMediaDetails(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('メディア詳細'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('タイプ', data['type'] == 'image' ? '画像' : 'ビデオ'),
              _buildDetailRow('ファイル名', data['fileName'] ?? 'N/A'),
              _buildDetailRow('アップロード者', data['userName'] ?? 'N/A'),
              if (data['incidentCase'] != null)
                _buildDetailRow('インシデントケース', data['incidentCase']),
              if (data['uploadedAt'] != null)
                _buildDetailRow(
                  'アップロード日時',
                  _formatDateTime((data['uploadedAt'] as Timestamp).toDate()),
                ),
              if (data['fileSize'] != null)
                _buildDetailRow('ファイルサイズ', _formatFileSize(data['fileSize'])),
              if (data['latitude'] != null && data['longitude'] != null)
                _buildDetailRow(
                  '位置情報',
                  '${data['latitude'].toStringAsFixed(6)}, ${data['longitude'].toStringAsFixed(6)}',
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}/${dateTime.month}/${dateTime.day} '
        '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.incidentCase != null
            ? 'メディア: ${widget.incidentCase}'
            : 'メディアギャラリー'),
        actions: [
          IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.filter_list),
                if (_filterType != 'all' || _showOnlyWithLocation)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: _showFilterDialog,
            tooltip: 'フィルター',
          ),
          IconButton(
            icon: const Icon(Icons.map_outlined),
            onPressed: () {
              if (kIsWeb) {
                // Web環境ではメッセージダイアログを表示
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade700),
                        const SizedBox(width: 12),
                        const Text('マップビュー'),
                      ],
                    ),
                    content: const Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'マップビューはWebではサポートされていません。',
                          style: TextStyle(fontSize: 16),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'モバイルアプリでご利用ください。',
                          style: TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('閉じる'),
                      ),
                    ],
                  ),
                );
              } else {
                // モバイル環境では通常のマップ画面を表示
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MediaMapViewScreen(),
                  ),
                );
              }
            },
            tooltip: 'マップビュー',
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _getMediaStream(),
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
                  Icon(
                    Icons.photo_library_outlined,
                    size: 80,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'メディアがありません',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '右下のボタンからメディアをアップロードしてください',
                    style: TextStyle(color: Colors.grey.shade500),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          final filteredDocs = _filterMedia(snapshot.data!.docs);

          if (filteredDocs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.filter_list_off,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'フィルター条件に一致するメディアがありません',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Filter info
              if (_filterType != 'all' || _showOnlyWithLocation)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  color: Colors.blue.shade50,
                  child: Row(
                    children: [
                      Icon(Icons.filter_list, size: 20, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'フィルター: ${_filterType == 'image' ? '画像のみ' : _filterType == 'video' ? 'ビデオのみ' : 'すべて'}'
                          '${_showOnlyWithLocation ? ' • 位置情報付き' : ''}',
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _filterType = 'all';
                            _showOnlyWithLocation = false;
                          });
                        },
                        icon: const Icon(Icons.clear, size: 16),
                        label: const Text('クリア', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ),

              // Media count
              Padding(
                padding: const EdgeInsets.all(12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${filteredDocs.length}件のメディア',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),

              // Media grid
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final doc = filteredDocs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final type = data['type'] as String;
                    final hasLocation = data['latitude'] != null;

                    return GestureDetector(
                      onTap: () => _showMediaOptions(doc),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: type == 'video'
                                ? Container(
                                    color: Colors.black87,
                                    child: const Icon(
                                      Icons.play_circle_outline,
                                      color: Colors.white,
                                      size: 48,
                                    ),
                                  )
                                : Image.network(
                                    data['downloadUrl'],
                                    fit: BoxFit.cover,
                                    loadingBuilder: (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Center(
                                        child: CircularProgressIndicator(
                                          value: loadingProgress.expectedTotalBytes != null
                                              ? loadingProgress.cumulativeBytesLoaded /
                                                  loadingProgress.expectedTotalBytes!
                                              : null,
                                        ),
                                      );
                                    },
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        color: Colors.grey.shade300,
                                        child: const Icon(Icons.broken_image, size: 48),
                                      );
                                    },
                                  ),
                          ),
                          // Location indicator
                          if (hasLocation)
                            Positioned(
                              top: 4,
                              right: 4,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.location_on,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          // Type indicator
                          Positioned(
                            bottom: 4,
                            left: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Icon(
                                type == 'video' ? Icons.videocam : Icons.image,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MediaUploadScreen(
                incidentCase: widget.incidentCase,
              ),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('アップロード'),
        backgroundColor: Colors.orange,
      ),
    );
  }
}