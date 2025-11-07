import 'package:firebase_storage/firebase_storage.dart';
import '../models/media_item.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String?> uploadMedia(
    MediaItem item,
    void Function(double) onProgress,
  ) async {
    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${item.file.path.split('/').last}';
      final ref = _storage.ref().child('media/${item.type}s/$fileName');

      final uploadTask = ref.putFile(
        item.file,
        SettableMetadata(
          contentType: item.type == 'video' ? 'video/mp4' : 'image/jpeg',
          customMetadata: {
            'uploadedAt': DateTime.now().toIso8601String(),
            'type': item.type,
            'isFavorite': item.isFavorite.toString(),
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
      return null;
    }
  }
}