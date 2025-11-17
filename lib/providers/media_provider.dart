import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:location/location.dart';
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

  Future<String?> uploadMedia({
    required File file,
    required String type, // e.g., 'image' or 'video'
    String? incidentCase,
    LocationData? location,
    Function(double progress)? onProgress,
  }) async {
    try {
      final storageRef = FirebaseStorage.instance.ref();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
      final uploadTask = storageRef.child('media/$fileName').putFile(file);

      // Track upload progress
      uploadTask.snapshotEvents.listen((event) {
        if (onProgress != null) {
          final progress = event.bytesTransferred / event.totalBytes;
          onProgress(progress);
        }
      });

      // Wait for upload to complete
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Save metadata to Firestore
      final metadata = {
        'url': downloadUrl,
        'type': type,
        'incidentCase': incidentCase,
        'timestamp': FieldValue.serverTimestamp(),
        'location': location != null
            ? {
                'latitude': location.latitude,
                'longitude': location.longitude,
              }
            : null,
      };

      await FirebaseFirestore.instance.collection('media').add(metadata);

      return downloadUrl;
    } catch (e) {
      print('Error uploading media: $e');
      return null;
    }
  }
}