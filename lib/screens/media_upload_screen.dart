import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart' show kIsWeb, Uint8List;
import 'dart:io' show File, Platform;
import '../services/media_service.dart';
import 'media_preview_screen.dart';

class MediaUploadScreen extends StatefulWidget {
  final String? incidentCase;

  const MediaUploadScreen({
    super.key,
    this.incidentCase,
  });

  @override
  State<MediaUploadScreen> createState() => _MediaUploadScreenState();
}

class _MediaUploadScreenState extends State<MediaUploadScreen> {
  final MediaService _mediaService = MediaService();
  final List<XFile> _selectedFiles = [];
  final List<String> _fileTypes = [];
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  int _currentUploadIndex = 0;
  Position? _currentLocation;
  bool _includeLocation = true;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final location = await _mediaService.getCurrentLocation();
      if (mounted) {
        setState(() {
          _currentLocation = location;
        });
      }
      if (location != null) {
        print('✅ 現在地: ${location.latitude}, ${location.longitude}');
      }
    } catch (e) {
      print('❌ 位置情報エラー: $e');
    }
  }

  Future<void> _pickMedia(ImageSource source, bool isVideo) async {
    try {
      if (isVideo) {
        final video = await _mediaService.pickVideo(source: source);
        if (video != null) {
          setState(() {
            _selectedFiles.add(video);
            _fileTypes.add('video');
          });
        }
      } else {
        final image = await _mediaService.pickImage(source: source);
        if (image != null) {
          setState(() {
            _selectedFiles.add(image);
            _fileTypes.add('image');
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('エラー: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickMultipleImages() async {
    try {
      final images = await _mediaService.pickMultipleImages();
      if (images.isNotEmpty) {
        setState(() {
          for (var image in images) {
            _selectedFiles.add(image);
            _fileTypes.add('image');
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('エラー: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showMediaSourceDialog(bool isVideo) {
    final isMobile = _mediaService.isMobile;
    final isDesktop = _mediaService.isDesktop;

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
            Text(
              isVideo ? 'ビデオを選択' : '写真を選択',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            
            // Camera option (only for mobile)
            if (isMobile)
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.blue),
                title: Text(isVideo ? 'ビデオを録画' : 'カメラで撮影'),
                onTap: () {
                  Navigator.pop(context);
                  _pickMedia(ImageSource.camera, isVideo);
                },
              ),
            
            // Camera option disabled for Web/Desktop
            if (kIsWeb || isDesktop)
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.grey),
                title: Row(
                  children: [
                    Text(
                      isVideo ? 'ビデオを録画' : 'カメラで撮影',
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.block, color: Colors.red.shade300, size: 16),
                  ],
                ),
                subtitle: Text(
                  '${kIsWeb ? 'Web' : 'Desktop'}環境では利用できません',
                  style: const TextStyle(fontSize: 11),
                ),
                enabled: false,
              ),
            
            // Gallery option
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.green),
              title: Text(isVideo ? 'ギャラリーから選択' : 'ギャラリーから選択'),
              onTap: () {
                Navigator.pop(context);
                _pickMedia(ImageSource.gallery, isVideo);
              },
            ),
            
            // Multiple images option
            if (!isVideo)
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: Colors.orange),
                title: const Text('複数の写真を選択'),
                onTap: () {
                  Navigator.pop(context);
                  _pickMultipleImages();
                },
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadMedia() async {
    if (_selectedFiles.isEmpty) return;

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
      _currentUploadIndex = 0;
    });

    try {
      final location = _includeLocation ? _currentLocation : null;

      final results = await _mediaService.uploadMultipleMedia(
        files: _selectedFiles,
        types: _fileTypes,
        incidentCase: widget.incidentCase,
        location: location,
        onProgress: (current, total, progress) {
          if (mounted) {
            setState(() {
              _currentUploadIndex = current;
              _uploadProgress = ((current - 1) / total) + (progress / total);
            });
          }
        },
      );

      // Count successful uploads
      final successCount = results.where((r) => r['success'] == true).length;
      final failCount = results.length - successCount;

      if (mounted) {
        setState(() {
          _isUploading = false;
          _selectedFiles.clear();
          _fileTypes.clear();
        });

        // Use ScaffoldMessenger before navigation
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ $successCount件アップロード完了${failCount > 0 ? '（$failCount件失敗）' : ''}',
            ),
            backgroundColor: failCount > 0 ? Colors.orange : Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );

        // Navigate back if all successful (with delay to show snackbar)
        if (failCount == 0) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              Navigator.of(context).pop(results);
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('アップロード失敗: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _removeFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
      _fileTypes.removeAt(index);
    });
  }

  void _previewFile(int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MediaPreviewScreen(
          xFile: _selectedFiles[index],
          type: _fileTypes[index],
          latitude: _currentLocation?.latitude,
          longitude: _currentLocation?.longitude,
          incidentCase: widget.incidentCase,
        ),
      ),
    );
  }

  Widget _buildFilePreview(XFile file, String type) {
    if (type == 'video') {
      return Container(
        color: Colors.black87,
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.play_circle_outline,
              color: Colors.white,
              size: 48,
            ),
            SizedBox(height: 8),
            Text(
              'ビデオ',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    // Image preview
    if (kIsWeb || _mediaService.isDesktop) {
      // Web/Desktop: Use Image.memory
      return FutureBuilder<Uint8List>(
        future: file.readAsBytes(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return Image.memory(
              snapshot.data!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.grey.shade300,
                  child: const Icon(
                    Icons.broken_image,
                    color: Colors.grey,
                    size: 48,
                  ),
                );
              },
            );
          }
          return const Center(child: CircularProgressIndicator());
        },
      );
    } else {
      // Mobile: Use Image.file
      return Image.file(
        File(file.path),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey.shade300,
            child: const Icon(
              Icons.broken_image,
              color: Colors.grey,
              size: 48,
            ),
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final platformInfo = _mediaService.getPlatformInfo();

    return Scaffold(
      appBar: AppBar(
        title: const Text('メディアアップロード'),
        actions: [
          if (_selectedFiles.isNotEmpty && !_isUploading)
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _selectedFiles.clear();
                  _fileTypes.clear();
                });
              },
              icon: const Icon(Icons.clear_all, color: Colors.white),
              label: const Text('クリア', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: Column(
        children: [
          // Platform info banner
          if (!_mediaService.isMobile)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.blue.shade50,
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '$platformInfo環境: カメラ撮影は利用できません',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Action Buttons
          if (!_isUploading) ...[
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showMediaSourceDialog(false),
                      icon: const Icon(Icons.add_photo_alternate),
                      label: const Text('写真'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showMediaSourceDialog(true),
                      icon: const Icon(Icons.videocam),
                      label: const Text('ビデオ'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Location Toggle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                child: SwitchListTile(
                  title: const Text('位置情報を含める'),
                  subtitle: _currentLocation != null
                      ? Text(
                          '現在地: ${_currentLocation!.latitude.toStringAsFixed(6)}, '
                          '${_currentLocation!.longitude.toStringAsFixed(6)}',
                          style: const TextStyle(fontSize: 12),
                        )
                      : Text(
                          '位置情報が取得できません${_mediaService.isDesktop ? '（Desktop環境）' : ''}',
                          style: const TextStyle(fontSize: 12),
                        ),
                  value: _includeLocation,
                  onChanged: _currentLocation != null
                      ? (value) {
                          setState(() => _includeLocation = value);
                        }
                      : null,
                  secondary: Icon(
                    Icons.location_on,
                    color: _currentLocation != null ? Colors.green : Colors.grey,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // File count
            if (_selectedFiles.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${_selectedFiles.length}件のファイルが選択されました',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
          ],

          // Upload Progress
          if (_isUploading)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'アップロード中... $_currentUploadIndex/${_selectedFiles.length}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                LinearProgressIndicator(
                                  value: _uploadProgress,
                                  backgroundColor: Colors.grey.shade300,
                                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${(_uploadProgress * 100).toStringAsFixed(0)}%',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Media Grid
          Expanded(
            child: _selectedFiles.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.cloud_upload_outlined,
                          size: 80,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'ファイルが選択されていません',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '上のボタンから写真やビデオを追加してください',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: _selectedFiles.length,
                    itemBuilder: (context, index) {
                      final file = _selectedFiles[index];
                      final type = _fileTypes[index];

                      return GestureDetector(
                        onTap: () => _previewFile(index),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: _buildFilePreview(file, type),
                            ),
                            // Remove button
                            if (!_isUploading)
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () => _removeFile(index),
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.3),
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 16,
                                    ),
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
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      type == 'video' ? Icons.videocam : Icons.image,
                                      color: Colors.white,
                                      size: 12,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // Upload Button
          if (_selectedFiles.isNotEmpty && !_isUploading)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _uploadMedia,
                    icon: const Icon(Icons.cloud_upload),
                    label: Text(
                      'アップロード (${_selectedFiles.length}件)',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}