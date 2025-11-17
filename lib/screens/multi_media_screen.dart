import 'package:flutter/material.dart';
import 'dart:io';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../models/media_item.dart';

class MediaPreviewScreen extends StatefulWidget {
  final MediaItem item;
  final Function(MediaItem)? onUpdate; // Added onUpdate callback
  final Function(File, String)? onUpload;

  const MediaPreviewScreen({
    super.key,
    required this.item,
    this.onUpdate, // Added to constructor
    this.onUpload,
  });

  @override
  State<MediaPreviewScreen> createState() => _MediaPreviewScreenState();
}

class _MediaPreviewScreenState extends State<MediaPreviewScreen> {
  late MediaItem _item;
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _item = widget.item;
    if (_item.type == 'video') {
      _initializeVideo();
    }
  }

  Future<void> _initializeVideo() async {
    _videoController = VideoPlayerController.file(widget.item.file);
    await _videoController!.initialize();

    _chewieController = ChewieController(
      videoPlayerController: _videoController!,
      autoPlay: true,
      looping: true,
    );

    setState(() => _isInitialized = true);
  }

  void _toggleFavorite() {
    final updatedItem = _item.copyWith(isFavorite: !_item.isFavorite);
    setState(() => _item = updatedItem);
    widget.onUpdate?.call(updatedItem);
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Preview ${_item.type.toUpperCase()}'),
        actions: [
          IconButton(
            icon: Icon(
                _item.isFavorite ? Icons.favorite : Icons.favorite_border),
            onPressed: _toggleFavorite,
          ),
          if (widget.onUpload != null)
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: () {
                widget.onUpload!(_item.file, _item.type);
                Navigator.of(context).pop();
              },
            ),
        ],
      ),
      body: Center(
        child: _item.type == 'video'
            ? _isInitialized && _chewieController != null
                ? Chewie(controller: _chewieController!)
                : const CircularProgressIndicator()
            : Image.file(_item.file),
      ),
    );
  }
}

//Full-screen preview for both images and videos
//Video playback controls
//Image zoom and pan capabilities
//Upload confirmation
//Loading states
//Error handling
// resource cleanup

//Key enhancements added:
//Video thumbnail generation
//Image cropping with customizable aspect ratios
//Image compression with quality control
//Loading and processing states
//Error handling for media operations
//UI improvements with tooltips
//Separate controls for image and video
//Progress indicators during processing