import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data';
import 'dart:io' show File, Platform;

// Geolocator import - これが重要！
import 'package:geolocator/geolocator.dart';

class MediaService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ImagePicker _picker = ImagePicker();

  // Check if platform is mobile (Android/iOS)
  bool get isMobile {
    if (kIsWeb) return false;
    try {
      return Platform.isAndroid || Platform.isIOS;
    } catch (e) {
      return false;
    }
  }

  // Check if platform is desktop (Windows/macOS/Linux)
  bool get isDesktop {
    if (kIsWeb) return false;
    try {
      return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
    } catch (e) {
      return false;
    }
  }

  // Pick image from camera or gallery
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
  }) async {
    try {
      // Web/Desktopではカメラ未サポート
      if ((kIsWeb || isDesktop) && source == ImageSource.camera) {
        print('⚠️ ${kIsWeb ? 'Web' : 'Desktop'}環境: カメラはギャラリーに変更');
        source = ImageSource.gallery;
      }

      return await _picker.pickImage(
        source: source,
        maxWidth: maxWidth ?? 1920,
        maxHeight: maxHeight ?? 1080,
        imageQuality: imageQuality ?? 85,
      );
    } catch (e) {
      print('❌ 画像選択エラー: $e');
      rethrow;
    }
  }

  // Pick video from camera or gallery
  Future<XFile?> pickVideo({
    required ImageSource source,
    Duration? maxDuration,
  }) async {
    try {
      // Web/Desktopではカメラ未サポート
      if ((kIsWeb || isDesktop) && source == ImageSource.camera) {
        print('⚠️ ${kIsWeb ? 'Web' : 'Desktop'}環境: カメラはギャラリーに変更');
        source = ImageSource.gallery;
      }

      return await _picker.pickVideo(
        source: source,
        maxDuration: maxDuration ?? const Duration(minutes: 5),
      );
    } catch (e) {
      print('❌ ビデオ選択エラー: $e');
      rethrow;
    }
  }

  // Pick multiple images
  Future<List<XFile>> pickMultipleImages() async {
    try {
      return await _picker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
    } catch (e) {
      print('❌ 複数画像選択エラー: $e');
      rethrow;
    }
  }

  // Get current location
  Future<Position?> getCurrentLocation() async {
    try {
      // Desktop環境では位置情報が制限される
      if (isDesktop) {
        print('⚠️ Desktop環境: 位置情報は制限される場合があります');
      }

      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('⚠️ 位置情報サービスが無効です');
        return null;
      }

      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('⚠️ 位置情報の権限が拒否されました');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('⚠️ 位置情報の権限が永久に拒否されました');
        return null;
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      print('✅ 位置情報取得: ${position.latitude}, ${position.longitude}');
      return position;
    } catch (e) {
      print('❌ 位置情報取得エラー: $e');
      return null;
    }
  }

  // Get file extension from filename
  String _getFileExtension(String fileName) {
    final parts = fileName.split('.');
    if (parts.length > 1) {
      return '.${parts.last}';
    }
    return '';
  }

  // Upload media to Firebase Storage - Universal version
  Future<Map<String, dynamic>> uploadMedia({
    required XFile file,
    required String type, // 'image' or 'video'
    String? incidentCase,
    Position? location,
    Function(double)? onProgress,
  }) async {
    try {
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('🔍 メディアアップロード開始');
      print('🖥️ プラットフォーム: ${kIsWeb ? 'Web' : isDesktop ? 'Desktop' : 'Mobile'}');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('ログインが必要です');
      }

      // Read file as bytes (universal approach)
      final Uint8List fileBytes = await file.readAsBytes();
      print('📦 ファイルサイズ: ${fileBytes.length} bytes');

      // Generate unique file name
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = _getFileExtension(file.name);
      final fileName = '${type}_${user.uid}_$timestamp$extension';
      final storagePath = 'media/${user.uid}/$fileName';

      print('📝 ファイル名: $fileName');
      print('📂 保存先: $storagePath');

      // Create reference to Firebase Storage
      final storageRef = _storage.ref().child(storagePath);

      // Upload using putData (works on all platforms)
      final uploadTask = storageRef.putData(
        fileBytes,
        SettableMetadata(
          contentType: type == 'image' 
              ? (extension.toLowerCase() == '.png' ? 'image/png' : 'image/jpeg')
              : 'video/mp4',
          customMetadata: {
            'uploadedBy': user.uid,
            'uploadedAt': DateTime.now().toIso8601String(),
            'platform': kIsWeb ? 'web' : isDesktop ? 'desktop' : 'mobile',
            if (incidentCase != null) 'incidentCase': incidentCase,
          },
        ),
      );

      // Listen to upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        print('📊 アップロード進捗: ${(progress * 100).toStringAsFixed(1)}%');
        onProgress?.call(progress);
      });

      // Wait for upload to complete
      final taskSnapshot = await uploadTask;
      print('✅ アップロード完了');

      // Get download URL
      final downloadUrl = await taskSnapshot.ref.getDownloadURL();
      print('🔗 ダウンロードURL: $downloadUrl');

      // Save metadata to Firestore
      final mediaData = {
        'fileName': fileName,
        'storagePath': storagePath,
        'downloadUrl': downloadUrl,
        'type': type,
        'userId': user.uid,
        'userName': user.displayName ?? user.email ?? 'Unknown',
        'userEmail': user.email,
        'uploadedAt': FieldValue.serverTimestamp(),
        'fileSize': fileBytes.length,
        'platform': kIsWeb ? 'web' : isDesktop ? 'desktop' : 'mobile',
        if (incidentCase != null) 'incidentCase': incidentCase,
        if (location != null) ...{
          'latitude': location.latitude,
          'longitude': location.longitude,
          'accuracy': location.accuracy,
          'altitude': location.altitude,
        },
      };

      final docRef = await _firestore.collection('media').add(mediaData);
      print('✅ Firestoreに保存: ${docRef.id}');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      return {
        'success': true,
        'mediaId': docRef.id,
        'downloadUrl': downloadUrl,
        'fileName': fileName,
        ...mediaData,
      };
    } catch (e) {
      print('❌ アップロードエラー: $e');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      rethrow;
    }
  }

  // Upload multiple media files
  Future<List<Map<String, dynamic>>> uploadMultipleMedia({
    required List<XFile> files,
    required List<String> types,
    String? incidentCase,
    Position? location,
    Function(int current, int total, double progress)? onProgress,
  }) async {
    final results = <Map<String, dynamic>>[];
    
    for (int i = 0; i < files.length; i++) {
      try {
        print('📤 アップロード中 ${i + 1}/${files.length}');
        
        final result = await uploadMedia(
          file: files[i],
          type: types[i],
          incidentCase: incidentCase,
          location: location,
          onProgress: (progress) {
            onProgress?.call(i + 1, files.length, progress);
          },
        );
        
        results.add(result);
        print('✅ ${i + 1}/${files.length} 完了');
      } catch (e) {
        print('❌ ${i + 1}/${files.length} 失敗: $e');
        results.add({
          'success': false,
          'error': e.toString(),
          'fileName': files[i].name,
        });
      }
    }
    
    return results;
  }

  // Get user's uploaded media
  Stream<QuerySnapshot> getUserMedia({String? userId}) {
    final user = userId ?? _auth.currentUser?.uid;
    if (user == null) {
      throw Exception('ユーザーIDが見つかりません');
    }

    return _firestore
        .collection('media')
        .where('userId', isEqualTo: user)
        .orderBy('uploadedAt', descending: true)
        .snapshots();
  }

  // Get media by incident case
  Stream<QuerySnapshot> getMediaByIncident(String incidentCase) {
    return _firestore
        .collection('media')
        .where('incidentCase', isEqualTo: incidentCase)
        .orderBy('uploadedAt', descending: true)
        .snapshots();
  }

  // Get all media with location
  Stream<QuerySnapshot> getMediaWithLocation() {
    return _firestore
        .collection('media')
        .where('latitude', isNull: false)
        .orderBy('uploadedAt', descending: true)
        .snapshots();
  }

  // Delete media
  Future<void> deleteMedia(String mediaId, String storagePath) async {
    try {
      print('🗑️ メディア削除開始: $mediaId');

      // Delete from Storage
      await _storage.ref().child(storagePath).delete();
      print('✅ Storageから削除');

      // Delete from Firestore
      await _firestore.collection('media').doc(mediaId).delete();
      print('✅ Firestoreから削除');

      print('✅ 削除完了');
    } catch (e) {
      print('❌ 削除エラー: $e');
      rethrow;
    }
  }

  // Get media by ID
  Future<DocumentSnapshot> getMediaById(String mediaId) {
    return _firestore.collection('media').doc(mediaId).get();
  }

  // Update media metadata
  Future<void> updateMediaMetadata(String mediaId, Map<String, dynamic> data) {
    return _firestore.collection('media').doc(mediaId).update(data);
  }

  // Search media
  Future<List<QueryDocumentSnapshot>> searchMedia({
    String? query,
    String? type,
    String? userId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    Query<Map<String, dynamic>> queryRef = _firestore.collection('media');

    if (userId != null) {
      queryRef = queryRef.where('userId', isEqualTo: userId);
    }

    if (type != null) {
      queryRef = queryRef.where('type', isEqualTo: type);
    }

    final snapshot = await queryRef.get();
    return snapshot.docs;
  }

  String getPlatformInfo() {
    if (kIsWeb) return 'Web';
    if (isDesktop) {
      try {
        if (Platform.isWindows) return 'Windows';
        if (Platform.isMacOS) return 'macOS';
        if (Platform.isLinux) return 'Linux';
      } catch (e) {
        return 'Desktop';
      }
    }
    if (isMobile) {
      try {
        if (Platform.isAndroid) return 'Android';
        if (Platform.isIOS) return 'iOS';
      } catch (e) {
        return 'Mobile';
      }
    }
    return 'Unknown';
  }
}