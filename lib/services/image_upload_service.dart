import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';

/// ✅ CORS対応: 画像アップロードと通知送信サービス
/// 
/// Cloud Functions を使用して、Web でも動作する画像通知機能を提供
class ImageNotificationService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ImagePicker _picker = ImagePicker();

  // ============================================
  // 画像をアップロードして通知を送信
  // ============================================

  /// 画像を選択してアップロード（通知は自動送信）
  Future<String?> pickAndUploadImage({
    required String reportId,
    ImageSource source = ImageSource.gallery,
  }) async {
    try {
      // 画像を選択
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image == null) return null;

      // アップロード
      final imageUrl = await uploadImage(
        imageFile: File(image.path),
        reportId: reportId,
      );

      // ✅ Storage トリガーが自動的に通知を送信します
      print('✅ Image uploaded: $imageUrl');
      print('📨 Storage trigger will send notification automatically');

      return imageUrl;

    } catch (e) {
      print('❌ Error picking/uploading image: $e');
      return null;
    }
  }

  /// 画像をアップロード
  Future<String> uploadImage({
    required File imageFile,
    required String reportId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    // ファイル名を生成
    final fileName = 'image_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref = _storage.ref().child('disaster_reports/$reportId/$fileName');

    // アップロード
    final uploadTask = ref.putFile(imageFile);

    // アップロード完了を待機
    await uploadTask;

    // URL を取得
    final downloadUrl = await ref.getDownloadURL();

    return downloadUrl;
  }

  // ============================================
  // ✅ CORS対応: Cloud Functions 経由で通知を送信
  // ============================================

  /// 特定のユーザーに画像通知を送信
  Future<bool> sendImageNotificationToUser({
    required String targetUserId,
    required String imageUrl,
    String? title,
    String? body,
    String? reportId,
    BuildContext? context,
  }) async {
    try {
      print('📨 Sending image notification via Cloud Functions...');

      // ✅ Callable Function を呼び出す（CORS なし！）
      final callable = _functions.httpsCallable('sendImageNotification');
      
      final result = await callable.call({
        'targetUserId': targetUserId,
        'title': title ?? '新しい画像',
        'body': body ?? '画像が追加されました',
        'imageUrl': imageUrl,
        'reportId': reportId ?? '',
      });

      print('✅ Notification sent: ${result.data}');

      // 成功メッセージを表示
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ 通知を送信しました'),
            backgroundColor: Colors.green,
          ),
        );
      }

      return true;

    } on FirebaseFunctionsException catch (e) {
      print('❌ Functions Error: ${e.code} - ${e.message}');
      
      // エラーメッセージを表示
      if (context != null && context.mounted) {
        String errorMessage = '通知の送信に失敗しました';
        
        switch (e.code) {
          case 'unauthenticated':
            errorMessage = 'ログインが必要です';
            break;
          case 'not-found':
            errorMessage = 'ユーザーが見つかりません';
            break;
          case 'permission-denied':
            errorMessage = '権限がありません';
            break;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ $errorMessage'),
            backgroundColor: Colors.red,
          ),
        );
      }

      return false;

    } catch (e) {
      print('❌ Error: $e');
      
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ エラー: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }

      return false;
    }
  }

  /// 複数のユーザーに画像通知を送信
  Future<Map<String, dynamic>> sendImageNotificationToMultiple({
    required List<String> userIds,
    required String imageUrl,
    String? title,
    String? body,
    String? reportId,
    BuildContext? context,
  }) async {
    try {
      print('📨 Sending image notification to ${userIds.length} users...');

      final callable = _functions.httpsCallable('sendImageNotificationToMultiple');
      
      final result = await callable.call({
        'userIds': userIds,
        'title': title ?? '新しい画像',
        'body': body ?? '画像が追加されました',
        'imageUrl': imageUrl,
        'reportId': reportId ?? '',
      });

      print('✅ Notifications sent: ${result.data}');

      if (context != null && context.mounted) {
        final successCount = result.data['successCount'] ?? 0;
        final failureCount = result.data['failureCount'] ?? 0;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${userIds.length}人中$successCount人に送信しました'),
            backgroundColor: failureCount > 0 ? Colors.orange : Colors.green,
          ),
        );
      }

      return result.data;

    } on FirebaseFunctionsException catch (e) {
      print('❌ Functions Error: ${e.code} - ${e.message}');
      return {'success': false, 'error': e.message};
    } catch (e) {
      print('❌ Error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// トピックに画像通知を送信
  Future<bool> sendImageNotificationToTopic({
    required String topic,
    required String imageUrl,
    String? title,
    String? body,
    BuildContext? context,
  }) async {
    try {
      print('📨 Sending image notification to topic: $topic');

      final callable = _functions.httpsCallable('sendImageNotificationToTopic');
      
      final result = await callable.call({
        'topic': topic,
        'title': title ?? '新しい画像',
        'body': body ?? '画像が追加されました',
        'imageUrl': imageUrl,
      });

      print('✅ Topic notification sent: ${result.data}');

      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ トピック通知を送信しました'),
            backgroundColor: Colors.green,
          ),
        );
      }

      return true;

    } on FirebaseFunctionsException catch (e) {
      print('❌ Functions Error: ${e.code} - ${e.message}');
      return false;
    } catch (e) {
      print('❌ Error: $e');
      return false;
    }
  }

  // ============================================
  // 完全なフロー: 画像アップロード → 通知送信
  // ============================================

  /// 完全なフロー: 画像を選択 → アップロード → 通知送信
  Future<bool> uploadImageAndNotify({
    required String reportId,
    required List<String> targetUserIds,
    String? title,
    String? body,
    ImageSource source = ImageSource.gallery,
    BuildContext? context,
  }) async {
    try {
      // ローディング表示
      if (context != null && context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('画像をアップロード中...'),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      // 1. 画像を選択してアップロード
      print('📤 Step 1: Selecting and uploading image...');
      final imageUrl = await pickAndUploadImage(
        reportId: reportId,
        source: source,
      );

      if (imageUrl == null) {
        if (context != null && context.mounted) {
          Navigator.of(context).pop(); // ローディングを閉じる
        }
        return false;
      }

      print('✅ Step 1 Complete: Image uploaded');

      // 2. 複数ユーザーに通知を送信
      print('📨 Step 2: Sending notifications...');
      final result = await sendImageNotificationToMultiple(
        userIds: targetUserIds,
        imageUrl: imageUrl,
        title: title,
        body: body,
        reportId: reportId,
      );

      // ローディングを閉じる
      if (context != null && context.mounted) {
        Navigator.of(context).pop();
      }

      print('✅ Step 2 Complete: Notifications sent');
      print('🎉 Full flow completed successfully!');

      // 成功メッセージ
      if (context != null && context.mounted) {
        final successCount = result['successCount'] ?? 0;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ 画像をアップロードして$successCount人に通知しました'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      return true;

    } catch (e) {
      print('❌ Error in full flow: $e');

      // ローディングを閉じる
      if (context != null && context.mounted) {
        Navigator.of(context).pop();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ エラー: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }

      return false;
    }
  }
}

// ============================================
// 使用例
// ============================================

/// Example 1: 単純な画像アップロード（自動通知）
Future<void> example1_SimpleUpload() async {
  final service = ImageNotificationService();
  
  await service.pickAndUploadImage(
    reportId: 'report_123',
    source: ImageSource.camera,
  );
  
  // ✅ Storage トリガーが自動的に通知を送信します
}

/// Example 2: 特定のユーザーに通知を送信
Future<void> example2_NotifySpecificUser(BuildContext context) async {
  final service = ImageNotificationService();
  
  await service.sendImageNotificationToUser(
    targetUserId: 'user_123',
    imageUrl: 'https://example.com/image.jpg',
    title: '新しい災害画像',
    body: '東京で地震が発生しました',
    reportId: 'report_123',
    context: context,
  );
}

/// Example 3: 複数ユーザーに通知を送信
Future<void> example3_NotifyMultipleUsers(BuildContext context) async {
  final service = ImageNotificationService();
  
  await service.sendImageNotificationToMultiple(
    userIds: ['user_1', 'user_2', 'user_3'],
    imageUrl: 'https://example.com/image.jpg',
    title: '新しい災害画像',
    body: '大阪で台風が接近しています',
    reportId: 'report_456',
    context: context,
  );
}

/// Example 4: 完全なフロー（画像選択 → アップロード → 通知）
Future<void> example4_CompleteFlow(BuildContext context) async {
  final service = ImageNotificationService();
  
  await service.uploadImageAndNotify(
    reportId: 'report_789',
    targetUserIds: ['user_1', 'user_2', 'user_3'],
    title: '緊急: 新しい災害画像',
    body: '福岡で地震が発生しました',
    source: ImageSource.gallery,
    context: context,
  );
}

/// Example 5: UI ボタンでの使用
class UploadImageButton extends StatelessWidget {
  final String reportId;
  final List<String> targetUserIds;

  const UploadImageButton({
    super.key,
    required this.reportId,
    required this.targetUserIds,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () async {
        final service = ImageNotificationService();
        await service.uploadImageAndNotify(
          reportId: reportId,
          targetUserIds: targetUserIds,
          title: '新しい災害画像',
          body: '画像が追加されました',
          context: context,
        );
      },
      icon: const Icon(Icons.camera_alt),
      label: const Text('画像をアップロード'),
    );
  }
}

/// Example 6: プログレスバー付きアップロード
class UploadImageWithProgress extends StatefulWidget {
  final String reportId;

  const UploadImageWithProgress({super.key, required this.reportId});

  @override
  State<UploadImageWithProgress> createState() => _UploadImageWithProgressState();
}

class _UploadImageWithProgressState extends State<UploadImageWithProgress> {
  bool _isUploading = false;
  double _uploadProgress = 0.0;

  Future<void> _uploadImage() async {
    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    try {
      final service = ImageNotificationService();
      final picker = ImagePicker();
      
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image == null) {
        setState(() => _isUploading = false);
        return;
      }

      final file = File(image.path);
      final ref = FirebaseStorage.instance
          .ref()
          .child('disaster_reports/${widget.reportId}/image_${DateTime.now().millisecondsSinceEpoch}.jpg');

      final uploadTask = ref.putFile(file);

      // 進捗を監視
      uploadTask.snapshotEvents.listen((snapshot) {
        setState(() {
          _uploadProgress = snapshot.bytesTransferred / snapshot.totalBytes;
        });
      });

      await uploadTask;
      final imageUrl = await ref.getDownloadURL();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ アップロード完了'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ エラー: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: _isUploading ? null : _uploadImage,
          child: const Text('画像をアップロード'),
        ),
        if (_isUploading) ...[
          const SizedBox(height: 16),
          LinearProgressIndicator(value: _uploadProgress),
          const SizedBox(height: 8),
          Text('${(_uploadProgress * 100).toStringAsFixed(1)}%'),
        ],
      ],
    );
  }
}