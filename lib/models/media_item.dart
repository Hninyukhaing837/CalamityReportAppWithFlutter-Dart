import 'dart:io';
import 'package:flutter/material.dart';

class MediaItem {
  final String filePath;
  final String type;
  final DateTime dateAdded;
  final String? thumbnailPath;
  final bool isSelected;
  final bool isUploading;
  final bool isUploaded;
  final bool isFavorite;
  final double uploadProgress;
  final String? uploadError;
  final int fileSize;

  MediaItem({
    required this.filePath,
    required this.type,
    DateTime? dateAdded,
    this.thumbnailPath,
    this.isSelected = false,
    this.isUploading = false,
    this.isUploaded = false,
    this.isFavorite = false,
    this.uploadProgress = 0.0,
    this.uploadError,
    this.fileSize = 0,
  }) : this.dateAdded = dateAdded ?? DateTime.now();

  File get file => File(filePath);
  
  IconData get icon {
    switch (type) {
      case 'image':
        return Icons.image;
      case 'video':
        return Icons.video_file;
      case 'audio':
        return Icons.audio_file;
      default:
        return Icons.insert_drive_file;
    }
  }

  String get title {
    return filePath.split('/').last;
  }

  MediaItem copyWith({
    String? filePath,
    String? type,
    DateTime? dateAdded,
    String? thumbnailPath,
    bool? isSelected,
    bool? isUploading,
    bool? isUploaded,
    bool? isFavorite,
    double? uploadProgress,
    String? uploadError,
    int? fileSize,
  }) {
    return MediaItem(
      filePath: filePath ?? this.filePath,
      type: type ?? this.type,
      dateAdded: dateAdded ?? this.dateAdded,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      isSelected: isSelected ?? this.isSelected,
      isUploading: isUploading ?? this.isUploading,
      isUploaded: isUploaded ?? this.isUploaded,
      isFavorite: isFavorite ?? this.isFavorite,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      uploadError: uploadError ?? this.uploadError,
      fileSize: fileSize ?? this.fileSize,
    );
  }
}