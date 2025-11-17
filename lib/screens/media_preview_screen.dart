import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'dart:io'; // For File operations (mobile only)
import 'package:video_player/video_player.dart'; // For video playback
import 'package:photo_view/photo_view.dart'; // For image zoom and pan
import '../models/media_item.dart'; // Import MediaItem model

class MediaPreviewScreen extends StatefulWidget {
  final MediaItem item; // MediaItem contains filePath and type ('image' or 'video')
  final Function(dynamic, String) onUpload; // Callback for uploading media

  const MediaPreviewScreen({
    Key? key,
    required this.item,
    required this.onUpload,
  }) : super(key: key);

  @override
  State<MediaPreviewScreen> createState() => _MediaPreviewScreenState();
}

class _MediaPreviewScreenState extends State<MediaPreviewScreen> {
  late VideoPlayerController? _videoController; // Controller for video playback
  bool _isLoading = true; // Loading state for media

  @override
  void initState() {
    super.initState();
    if (widget.item.type == 'video') {
      _initializeVideoPlayer(); // Initialize video player if the media is a video
    } else {
      _isLoading = false; // No loading needed for images
    }
  }

  // Initialize the video player
  Future<void> _initializeVideoPlayer() async {
    try {
      if (kIsWeb) {
        // Use network-based video player for web
        _videoController = VideoPlayerController.network(widget.item.filePath);
      } else {
        // Use file-based video player for mobile
        _videoController = VideoPlayerController.file(File(widget.item.filePath));
      }

      await _videoController!.initialize();
      setState(() {
        _isLoading = false; // Video is ready to play
      });
      _videoController?.play(); // Auto-play the video
    } catch (e) {
      setState(() {
        _isLoading = false; // Stop loading if there's an error
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load video: $e')),
      );
    }
  }

  @override
  void dispose() {
    _videoController?.dispose(); // Dispose of the video controller to free resources
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Media Preview'),
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud_upload),
            tooltip: 'Upload Media',
            onPressed: () {
              _confirmUpload(context); // Confirm upload before proceeding
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator()) // Show loading spinner
          : widget.item.type == 'image'
              ? _buildImagePreview() // Build image preview
              : _buildVideoPreview(), // Build video preview
    );
  }

  // Build image preview with zoom and pan
  Widget _buildImagePreview() {
    return kIsWeb
        ? Image.network(widget.item.filePath) // Web-compatible image preview
        : PhotoView(
            imageProvider: FileImage(File(widget.item.filePath)),
            backgroundDecoration: const BoxDecoration(color: Colors.black),
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 2.0,
          );
  }

  // Build video preview with playback controls
  Widget _buildVideoPreview() {
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        AspectRatio(
          aspectRatio: _videoController?.value.aspectRatio ?? 16 / 9,
          child: VideoPlayer(_videoController!),
        ),
        VideoProgressIndicator(
          _videoController!,
          allowScrubbing: true,
          colors: const VideoProgressColors(
            playedColor: Colors.blue,
            bufferedColor: Colors.grey,
            backgroundColor: Colors.black,
          ),
        ),
        FloatingActionButton(
          onPressed: () {
            setState(() {
              if (_videoController!.value.isPlaying) {
                _videoController?.pause();
              } else {
                _videoController?.play();
              }
            });
          },
          child: Icon(
            _videoController!.value.isPlaying ? Icons.pause : Icons.play_arrow,
          ),
        ),
      ],
    );
  }

  // Confirm upload dialog
  Future<void> _confirmUpload(BuildContext context) async {
    final shouldUpload = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('メディアをアップロード'),
        content: const Text('このメディアをアップロードしてもよろしいですか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('アップロード'),
          ),
        ],
      ),
    );

    if (shouldUpload == true) {
      _uploadMedia(); // Proceed with the upload
    }
  }

  // Simulate media upload
  Future<void> _uploadMedia() async {
    setState(() {
      _isLoading = true; // Show loading spinner during upload
    });

    try {
      // Simulate upload delay
      await Future.delayed(const Duration(seconds: 2));
      widget.onUpload(widget.item.filePath, widget.item.type); // Trigger the upload callback
      setState(() {
        _isLoading = false; // Stop loading after upload
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Media uploaded successfully!')),
      );
      Navigator.pop(context); // Close the preview screen after upload
    } catch (e) {
      setState(() {
        _isLoading = false; // Stop loading if there's an error
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload media: $e')),
      );
    }
  }
}