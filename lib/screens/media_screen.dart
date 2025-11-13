import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../providers/media_provider.dart';

class MediaScreen extends StatefulWidget {
  const MediaScreen({super.key});

  @override
  State<MediaScreen> createState() => _MediaScreenState();
}

class _MediaScreenState extends State<MediaScreen> {
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    print('Requesting permissions...');
    if (kIsWeb) {
      // No permissions are required for web
      print('Running on web: No permissions required.');
    } else if (Platform.isAndroid) {
      await Permission.camera.request();
      await Permission.photos.request();
      await Permission.storage.request();
      print('Permissions requested on Android.');
    } else if (Platform.isIOS) {
      await Permission.camera.request();
      await Permission.photos.request();
      print('Permissions requested on iOS.');
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        final mediaProvider = Provider.of<MediaProvider>(context, listen: false);
        mediaProvider.addMedia(File(image.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('画像の選択中にエラーが発生しました: $e')), // "Error picking image" -> "画像の選択中にエラーが発生しました"
        );
      }
    }
  }

  Future<void> _pickMultipleImages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (images.isNotEmpty) {
        final mediaProvider = Provider.of<MediaProvider>(context, listen: false);
        for (var image in images) {
          mediaProvider.addMedia(File(image.path));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('複数画像の選択中にエラーが発生しました: $e')), // "Error picking images" -> "複数画像の選択中にエラーが発生しました"
        );
      }
    }
  }

  Future<void> _pickVideo(ImageSource source) async {
    try {
      final XFile? video = await _picker.pickVideo(
        source: source,
        maxDuration: const Duration(minutes: 5),
      );

      if (video != null) {
        final mediaProvider = Provider.of<MediaProvider>(context, listen: false);
        mediaProvider.addMedia(File(video.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ビデオの選択中にエラーが発生しました: $e')), // "Error picking video" -> "ビデオの選択中にエラーが発生しました"
        );
      }
    }
  }

  void _showMediaSourceDialog(bool isVideo) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: Text(isVideo ? 'ビデオを録画' : '写真を撮影'), // "Record Video" -> "ビデオを録画", "Take Photo" -> "写真を撮影"
                onTap: () {
                  Navigator.pop(context);
                  if (isVideo) {
                    _pickVideo(ImageSource.camera);
                  } else {
                    _pickImage(ImageSource.camera);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: Text(isVideo ? 'ギャラリーから選択' : '写真を選択'), // "Choose from Gallery" -> "ギャラリーから選択", "Choose from Photos" -> "写真を選択"
                onTap: () {
                  Navigator.pop(context);
                  if (isVideo) {
                    _pickVideo(ImageSource.gallery);
                  } else {
                    _pickImage(ImageSource.gallery);
                  }
                },
              ),
              if (!isVideo)
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('複数の写真を選択'), // "Choose Multiple Photos" -> "複数の写真を選択"
                  onTap: () {
                    Navigator.pop(context);
                    _pickMultipleImages();
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('メディアギャラリー'), // "Media Gallery" -> "メディアギャラリー"
        actions: [
          Consumer<MediaProvider>(
            builder: (context, mediaProvider, child) {
              if (mediaProvider.selectedMedia.isNotEmpty) {
                return IconButton(
                  icon: const Icon(Icons.delete_sweep),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('すべてのメディアを削除'), // "Clear All Media" -> "すべてのメディアを削除"
                        content: const Text('すべてのメディアを削除してもよろしいですか？'), // "Are you sure you want to remove all media?" -> "すべてのメディアを削除してもよろしいですか？"
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('キャンセル'), // "Cancel" -> "キャンセル"
                          ),
                          TextButton(
                            onPressed: () {
                              mediaProvider.clearMedia();
                              Navigator.pop(context);
                            },
                            child: const Text('削除'), // "Clear" -> "削除"
                          ),
                        ],
                      ),
                    );
                  },
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: Consumer<MediaProvider>(
        builder: (context, mediaProvider, child) {
          return Column(
            children: [
              // Action buttons
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _showMediaSourceDialog(false),
                      icon: const Icon(Icons.photo),
                      label: const Text('写真を追加'), // "Add Photo" -> "写真を追加"
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _showMediaSourceDialog(true),
                      icon: const Icon(Icons.videocam),
                      label: const Text('ビデオを追加'), // "Add Video" -> "ビデオを追加"
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              // Media count
              if (mediaProvider.selectedMedia.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    '${mediaProvider.selectedMedia.length} 件のメディアが選択されました', // "item(s) selected" -> "件のメディアが選択されました"
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),

              const SizedBox(height: 8),

              // Media grid
              Expanded(
                child: mediaProvider.selectedMedia.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.photo_library_outlined,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'メディアが選択されていません', // "No media selected" -> "メディアが選択されていません"
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '上のボタンをタップして写真やビデオを追加してください', // "Tap the buttons above to add photos or videos" -> "上のボタンをタップして写真やビデオを追加してください"
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
                        itemCount: mediaProvider.selectedMedia.length,
                        itemBuilder: (context, index) {
                          final file = mediaProvider.selectedMedia[index];
                          final isVideo = file.path.endsWith('.mp4') ||
                              file.path.endsWith('.mov') ||
                              file.path.endsWith('.avi');

                          return Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: isVideo
                                    ? Container(
                                        color: Colors.black87,
                                        child: const Icon(
                                          Icons.play_circle_outline,
                                          color: Colors.white,
                                          size: 48,
                                        ),
                                      )
                                    : (file.existsSync())
                                        ? Image.file(
                                            file,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) {
                                              return Container(
                                                color: Colors.grey.shade300,
                                                child: const Icon(
                                                  Icons.broken_image,
                                                  color: Colors.grey,
                                                ),
                                              );
                                            },
                                          )
                                        : Container(
                                            color: Colors.grey.shade300,
                                            child: const Icon(
                                              Icons.broken_image,
                                              color: Colors.grey,
                                            ),
                                          ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () => mediaProvider.removeMedia(index),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
              ),

              // Upload button
              if (mediaProvider.selectedMedia.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: mediaProvider.isUploading
                          ? null
                          : () {
                              // TODO: Implement upload to Firebase Storage
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('アップロード機能は近日公開予定です'), // "Upload functionality coming soon" -> "アップロード機能は近日公開予定です"
                                ),
                              );
                            },
                      icon: mediaProvider.isUploading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.cloud_upload),
                      label: Text(
                        mediaProvider.isUploading
                            ? 'アップロード中 ${(mediaProvider.uploadProgress * 100).toInt()}%' // "Uploading" -> "アップロード中"
                            : 'クラウドにアップロード', // "Upload to Cloud" -> "クラウドにアップロード"
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

//Multiple image selection
//Grid view of selected media
//Preview capability for each item
//Selection/deselection with checkmarks
//Upload counter in app bar
//Loading indicators
//Maximum item limit
//Error handling

//Media preview with video support
//Firebase Storage upload with progress
//File filtering by type and favorites
//Search functionality
//Sort options
//State management with Provider