import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, Uint8List;
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io' show File;

class MediaPreviewScreen extends StatefulWidget {
  final String? mediaId;
  final String? url;
  final String type; // 'image' or 'video'
  final File? file; // For local files (non-web)
  final XFile? xFile; // For web-compatible files
  final double? latitude;
  final double? longitude;
  final String? incidentCase;
  final DateTime? timestamp;
  final String? userName;

  const MediaPreviewScreen({
    super.key,
    this.mediaId,
    this.url,
    required this.type,
    this.file,
    this.xFile,
    this.latitude,
    this.longitude,
    this.incidentCase,
    this.timestamp,
    this.userName,
  });

  @override
  State<MediaPreviewScreen> createState() => _MediaPreviewScreenState();
}

class _MediaPreviewScreenState extends State<MediaPreviewScreen> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _isInitialized = false;
  Uint8List? _imageBytes;

  @override
  void initState() {
    super.initState();
    if (widget.type == 'video') {
      _initializeVideo();
    } else if (kIsWeb && widget.xFile != null) {
      _loadImageBytes();
    }
  }

  Future<void> _loadImageBytes() async {
    if (widget.xFile != null) {
      final bytes = await widget.xFile!.readAsBytes();
      if (mounted) {
        setState(() => _imageBytes = bytes);
      }
    }
  }

  Future<void> _initializeVideo() async {
    try {
      if (kIsWeb && widget.url != null) {
        // Web環境ではネットワークURLのみ
        _videoController = VideoPlayerController.networkUrl(
          Uri.parse(widget.url!),
        );
      } else if (!kIsWeb && widget.file != null) {
        // モバイル環境ではFileを使用
        _videoController = VideoPlayerController.file(widget.file!);
      } else if (widget.url != null) {
        // フォールバック: URL
        _videoController = VideoPlayerController.networkUrl(
          Uri.parse(widget.url!),
        );
      }

      if (_videoController != null) {
        await _videoController!.initialize();

        _chewieController = ChewieController(
          videoPlayerController: _videoController!,
          autoPlay: true,
          looping: false,
          aspectRatio: _videoController!.value.aspectRatio,
          errorBuilder: (context, errorMessage) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'エラー: $errorMessage',
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          },
        );

        if (mounted) {
          setState(() => _isInitialized = true);
        }
      }
    } catch (e) {
      print('❌ ビデオ初期化エラー: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ビデオの読み込みに失敗しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showLocationOnMap() {
    if (widget.latitude == null || widget.longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('位置情報がありません')),
      );
      return;
    }

    // Web環境ではメッセージを表示
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
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'マップ表示はWebではサポートされていません。',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              Text(
                'モバイルアプリでご利用ください。',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 8),
                        const Text(
                          '位置情報:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '緯度: ${widget.latitude!.toStringAsFixed(6)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    Text(
                      '経度: ${widget.longitude!.toStringAsFixed(6)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
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
      return;
    }

    // モバイル環境では通常のマップ画面を表示
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MediaMapScreen(
          latitude: widget.latitude!,
          longitude: widget.longitude!,
          mediaType: widget.type,
          mediaUrl: widget.url,
          incidentCase: widget.incidentCase,
        ),
      ),
    );
  }

  Widget _buildMediaContent() {
    if (widget.type == 'video') {
      if (!_isInitialized || _chewieController == null) {
        return const Center(child: CircularProgressIndicator());
      }
      return Chewie(controller: _chewieController!);
    } else {
      // Image
      if (kIsWeb) {
        // Web環境
        if (_imageBytes != null) {
          return InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Image.memory(_imageBytes!, fit: BoxFit.contain),
          );
        } else if (widget.url != null) {
          return InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Image.network(
              widget.url!,
              fit: BoxFit.contain,
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
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      const Text(
                        '画像の読み込みに失敗しました',
                        style: TextStyle(color: Colors.red),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        }
      } else {
        // モバイル環境
        if (widget.file != null) {
          return InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Image.file(widget.file!, fit: BoxFit.contain),
          );
        } else if (widget.url != null) {
          return InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Image.network(
              widget.url!,
              fit: BoxFit.contain,
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
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      const Text(
                        '画像の読み込みに失敗しました',
                        style: TextStyle(color: Colors.red),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        }
      }
    }
    return const Center(child: Text('メディアがありません'));
  }

  Widget _buildInfoCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  widget.type == 'image' ? Icons.image : Icons.videocam,
                  color: Colors.blue,
                ),
                const SizedBox(width: 8),
                Text(
                  widget.type == 'image' ? '画像情報' : '動画情報',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            
            if (widget.userName != null) ...[
              _buildInfoRow(
                Icons.person,
                'アップロード者',
                widget.userName!,
              ),
              const SizedBox(height: 12),
            ],
            
            if (widget.timestamp != null) ...[
              _buildInfoRow(
                Icons.access_time,
                '日時',
                _formatDateTime(widget.timestamp!),
              ),
              const SizedBox(height: 12),
            ],
            
            if (widget.incidentCase != null) ...[
              _buildInfoRow(
                Icons.folder_outlined,
                'インシデントケース',
                widget.incidentCase!,
              ),
              const SizedBox(height: 12),
            ],
            
            if (widget.latitude != null && widget.longitude != null) ...[
              _buildInfoRow(
                Icons.location_on,
                '位置情報',
                '${widget.latitude!.toStringAsFixed(6)}, ${widget.longitude!.toStringAsFixed(6)}',
              ),
              const SizedBox(height: 12),
              
              // マップボタン - 常に表示
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _showLocationOnMap,
                  icon: const Icon(Icons.map),
                  label: const Text('マップで確認'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              
              // Web環境: 補足メッセージ
              if (kIsWeb) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700, size: 16),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Web環境ではマップ機能は制限されています',
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ] else ...[
              Container(
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
                    const Expanded(
                      child: Text(
                        '位置情報が含まれていません',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}/${dateTime.month}/${dateTime.day} '
        '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black87,
        title: Text(
          widget.type == 'image' ? '画像プレビュー' : '動画プレビュー',
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // マップボタン - 常に表示（Web環境ではダイアログを表示）
          if (widget.latitude != null && widget.longitude != null)
            IconButton(
              icon: const Icon(Icons.map_outlined),
              onPressed: _showLocationOnMap,
              tooltip: 'マップで見る',
            ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                builder: (context) => _buildInfoCard(),
              );
            },
            tooltip: '詳細情報',
          ),
        ],
      ),
      body: Center(child: _buildMediaContent()),
    );
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }
}

// Media Map Screen - モバイルのみ使用
class MediaMapScreen extends StatefulWidget {
  final double latitude;
  final double longitude;
  final String mediaType;
  final String? mediaUrl;
  final String? incidentCase;

  const MediaMapScreen({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.mediaType,
    this.mediaUrl,
    this.incidentCase,
  });

  @override
  State<MediaMapScreen> createState() => _MediaMapScreenState();
}

class _MediaMapScreenState extends State<MediaMapScreen> {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _setupMarker();
  }

  void _setupMarker() {
    _markers.add(
      Marker(
        markerId: const MarkerId('media_location'),
        position: LatLng(widget.latitude, widget.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          widget.mediaType == 'image'
              ? BitmapDescriptor.hueGreen
              : BitmapDescriptor.hueRed,
        ),
        infoWindow: InfoWindow(
          title: widget.mediaType == 'image' ? '📷 画像の位置' : '🎥 動画の位置',
          snippet: widget.incidentCase != null
              ? 'ケース: ${widget.incidentCase}'
              : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('メディアの位置'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: () {
              _mapController?.animateCamera(
                CameraUpdate.newLatLngZoom(
                  LatLng(widget.latitude, widget.longitude),
                  15,
                ),
              );
            },
            tooltip: 'この位置に移動',
          ),
        ],
      ),
      body: Column(
        children: [
          // Info banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: widget.mediaType == 'image'
                ? Colors.green.shade100
                : Colors.red.shade100,
            child: Row(
              children: [
                Icon(
                  widget.mediaType == 'image' ? Icons.image : Icons.videocam,
                  color: widget.mediaType == 'image'
                      ? Colors.green.shade700
                      : Colors.red.shade700,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.mediaType == 'image' ? '画像の撮影位置' : '動画の撮影位置',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '緯度: ${widget.latitude.toStringAsFixed(6)}, '
                        '経度: ${widget.longitude.toStringAsFixed(6)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Map
          Expanded(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(widget.latitude, widget.longitude),
                zoom: 15,
              ),
              markers: _markers,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              mapType: MapType.normal,
              onMapCreated: (controller) {
                _mapController = controller;
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}