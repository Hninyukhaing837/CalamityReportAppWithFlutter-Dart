import 'package:firebase_storage/firebase_storage.dart';
import '../models/media_item.dart';

class MediaUploadService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String?> uploadMedia(
    MediaItem item,
    void Function(double) onProgress,
  ) async {
    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${item.file.path.split('/').last}';
      final ref = _storage.ref().child('${item.type}s/$fileName');

      final uploadTask = ref.putFile(
        item.file,
        SettableMetadata(
          contentType: item.type == 'video' ? 'video/mp4' : 'image/jpeg',
          customMetadata: {
            'uploadedAt': DateTime.now().toIso8601String(),
            'type': item.type,
          },
        ),
      );

      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        onProgress(progress);
      });

      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print('Error uploading media: $e');
      return null;
    }
  }

  Future<List<String>> uploadMultipleMedia(
    List<MediaItem> items,
    void Function(MediaItem, double) onItemProgress,
    void Function(MediaItem, String?) onItemComplete,
  ) async {
    final List<String> uploadedUrls = [];

    for (var item in items) {
      if (!item.isSelected) continue;

      final url = await uploadMedia(
        item,
        (progress) => onItemProgress(item, progress),
      );

      onItemComplete(item, url);
      if (url != null) {
        uploadedUrls.add(url);
      }
    }

    return uploadedUrls;
  }
}