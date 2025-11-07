import 'package:flutter/foundation.dart';
import 'dart:io';

class MediaProvider with ChangeNotifier {
  final List<File> _selectedMedia = [];
  bool _isUploading = false;
  double _uploadProgress = 0.0;

  List<File> get selectedMedia => _selectedMedia;
  bool get isUploading => _isUploading;
  double get uploadProgress => _uploadProgress;

  void addMedia(File file) {
    _selectedMedia.add(file);
    notifyListeners();
  }

  void removeMedia(int index) {
    _selectedMedia.removeAt(index);
    notifyListeners();
  }

  void clearMedia() {
    _selectedMedia.clear();
    notifyListeners();
  }

  void setUploadProgress(double progress) {
    _uploadProgress = progress;
    notifyListeners();
  }

  void setUploading(bool uploading) {
    _isUploading = uploading;
    notifyListeners();
  }
}