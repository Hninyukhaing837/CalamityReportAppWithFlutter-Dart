import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;
import 'dart:io';

class MediaService {
  final ImagePicker _picker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String?> uploadMedia(File file, String type) async {
    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(file.path)}';
      final ref = _storage.ref().child('$type/$fileName');
      
      final uploadTask = ref.putFile(
        file,
        SettableMetadata(
          contentType: type.startsWith('image') ? 'image/jpeg' : 'video/mp4',
          customMetadata: {
            'uploaded_at': DateTime.now().toIso8601String(),
            'type': type,
          },
        ),
      );

      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print('Error uploading media: $e');
      return null;
    }
  }

  Future<XFile?> pickImage({
    ImageSource source = ImageSource.gallery,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
  }) async {
    try {
      return await _picker.pickImage(
        source: source,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        imageQuality: imageQuality,
      );
    } catch (e) {
      print('Error picking image: $e');
      return null;
    }
  }

  Future<XFile?> pickVideo({
    ImageSource source = ImageSource.gallery,
    Duration? maxDuration,
  }) async {
    try {
      return await _picker.pickVideo(
        source: source,
        maxDuration: maxDuration,
      );
    } catch (e) {
      print('Error picking video: $e');
      return null;
    }
  }

  Future<bool> deleteMedia(String url) async {
    try {
      final ref = _storage.refFromURL(url);
      await ref.delete();
      return true;
    } catch (e) {
      print('Error deleting media: $e');
      return false;
    }
  }

  Future<List<String>> getMediaUrls(String type, {int limit = 10}) async {
    try {
      final ListResult result = await _storage.ref(type).listAll();
      final List<String> urls = [];
      
      for (var item in result.items) {
        final url = await item.getDownloadURL();
        urls.add(url);
        if (urls.length >= limit) break;
      }
      
      return urls;
    } catch (e) {
      print('Error getting media urls: $e');
      return [];
    }
  }
}

//Better error handling with try-catch blocks
//Support for both image and video uploads
//Custom metadata for uploaded files
//File deletion functionality
//Media listing capability
//Configurable image picking options
//Video picking support
//Proper file type handling