import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:firebase_storage/firebase_storage.dart';
// For web-compatible file handling
import 'dart:io'; // For mobile file handling (dart:io is not supported on web)

class MediaUploadService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Upload media to Firebase Storage
  Future<String?> uploadMedia({
    required dynamic file, // Use dynamic to support both File (mobile) and Uint8List (web)
    required String folder, // Folder name in Firebase Storage
    required String fileName, // File name
    Function(double progress)? onProgress, // Optional progress callback
  }) async {
    try {
      final ref = _storage.ref().child('$folder/$fileName');
      UploadTask uploadTask;

      if (kIsWeb) {
        // Web: Use Uint8List for file uploads
        uploadTask = ref.putData(file as Uint8List);
      } else {
        // Mobile: Use File for file uploads
        uploadTask = ref.putFile(file as File);
      }

      // Track upload progress
      uploadTask.snapshotEvents.listen((event) {
        if (onProgress != null) {
          final progress = event.bytesTransferred / event.totalBytes;
          onProgress(progress);
        }
      });

      // Wait for the upload to complete
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl; // Return the download URL
    } catch (e) {
      print('Error uploading media: $e');
      return null;
    }
  }
}