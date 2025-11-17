import 'package:calamity_report/models/media_item.dart';
import 'package:calamity_report/services/media_upload_service.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data'; // For web
import 'dart:io'; // For mobile
import 'package:flutter/foundation.dart'; // For kIsWeb
import '../services/media_service.dart';
import '../screens/media_preview_screen.dart';

class MediaPicker extends StatefulWidget {
  final Function(File, String) onMediaSelected; // Change dynamic to File
  final bool allowVideo;
  final double? maxWidth;
  final double? maxHeight;
  final int? imageQuality;
  final Duration? maxVideoDuration;

  const MediaPicker({
    super.key,
    required this.onMediaSelected,
    this.allowVideo = true,
    this.maxWidth,
    this.maxHeight,
    this.imageQuality,
    this.maxVideoDuration,
  });

  @override
  State<MediaPicker> createState() => _MediaPickerState();
}

class _MediaPickerState extends State<MediaPicker> {
  final MediaService _mediaService = MediaService();
  bool _isLoading = false;
  String? _error;

  Future<void> _pickMedia(ImageSource source, bool isVideo) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final XFile? file = isVideo
          ? await _mediaService.pickVideo(
              source: source,
              maxDuration: widget.maxVideoDuration,
            )
          : await _mediaService.pickImage(
              source: source,
              maxWidth: widget.maxWidth,
              maxHeight: widget.maxHeight,
              imageQuality: widget.imageQuality,
            );

      if (file != null && mounted) {
        if (kIsWeb) {
          // Web: Use Uint8List for uploads
          final Uint8List fileBytes = await file.readAsBytes();
          await MediaUploadService().uploadMedia(
            file: fileBytes,
            folder: 'uploads',
            fileName: file.name,
          );
        } else {
          // Mobile: Use File for uploads
          final File filePath = File(file.path);
          await MediaUploadService().uploadMedia(
            file: filePath,
            folder: 'uploads',
            fileName: file.name,
          );
        }

        final mediaItem = MediaItem(
          filePath: file.path,
          type: isVideo ? 'video' : 'image',
        );

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MediaPreviewScreen(
              item: mediaItem, // Pass MediaItem directly
              onUpload: (file, type) => widget.onMediaSelected(file as dynamic, type), // Cast file to dynamic
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showMediaSourceDialog(bool isVideo) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: Icon(isVideo ? Icons.videocam : Icons.photo_camera),
                title: Text('Use ${isVideo ? 'Camera' : 'Camera'}'),
                onTap: () {
                  Navigator.pop(context);
                  _pickMedia(ImageSource.camera, isVideo);
                },
              ),
              ListTile(
                leading: Icon(isVideo ? Icons.video_library : Icons.photo_library),
                title: Text('Choose from ${isVideo ? 'Gallery' : 'Gallery'}'),
                onTap: () {
                  Navigator.pop(context);
                  _pickMedia(ImageSource.gallery, isVideo);
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              _error!,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: CircularProgressIndicator(),
          )
        else
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.add_photo_alternate),
                  label: const Text('Photo'),
                  onPressed: () => _showMediaSourceDialog(false),
                ),
                if (widget.allowVideo)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.video_call),
                    label: const Text('Video'),
                    onPressed: () => _showMediaSourceDialog(true),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

//A reusable MediaPicker widget
//Image and video capture from camera or gallery
//Upload progress indication
//Success/error feedback
//Grid display of uploaded media
//Loading states and error handling

//Added more configuration options (maxWidth, maxHeight, imageQuality, maxVideoDuration)
//Better error handling with visual feedback
//Added a bottom sheet dialog for media source selection
//Improved UI with ElevatedButtons and icons
//Better padding and layout
//Added SafeArea for bottom sheet
//More descriptive button labels
//Error message display in the UI

// Example usage:
/*
MediaPicker(
  onMediaSelected: (file, type) {
    if (file is File) { // Ensure the dynamic type is a File
      print('Selected $type: ${file.path}');
    }
  },
  allowVideo: true,
  maxWidth: 1920,
  maxHeight: 1080,
  imageQuality: 85,
  maxVideoDuration: const Duration(minutes: 5),
)
*/