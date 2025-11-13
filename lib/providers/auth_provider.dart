import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  String? errorMessage;
  bool isLoading = false;
  bool isAuthenticated = false;

  // Create or update user profile in Firestore
  Future<void> _createOrUpdateUserProfile(User user) async {
    try {
      final userRef = _firestore.collection('users').doc(user.uid);
      
      // Check if profile exists
      final doc = await userRef.get();
      
      if (!doc.exists) {
        // Create new profile
        await userRef.set({
          'uid': user.uid,
          'email': user.email ?? '',
          'name': user.displayName ?? user.email?.split('@')[0] ?? 'User',
          'createdAt': FieldValue.serverTimestamp(),
          'lastSeen': FieldValue.serverTimestamp(),
        });
        print('✅ User profile created for ${user.uid}');
      } else {
        // Update last seen
        await userRef.update({
          'lastSeen': FieldValue.serverTimestamp(),
        });
        print('✅ User profile updated for ${user.uid}');
      }
    } catch (e) {
      print('❌ Error creating/updating user profile: $e');
      // Don't throw error - allow login to proceed even if Firestore fails
    }
  }

  Future<void> signInWithEmailAndPassword(String email, String password) async {
    try {
      isLoading = true;
      notifyListeners();

      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Create or update user profile in Firestore
      if (userCredential.user != null) {
        await _createOrUpdateUserProfile(userCredential.user!);
      }
      
      isAuthenticated = true;
      errorMessage = null; // Clear any previous error messages
    } on FirebaseAuthException catch (e) {
      isAuthenticated = false;

      // Log the error code for debugging
      print('FirebaseAuthException code: ${e.code}');

      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'ユーザーが見つかりません';
          break;
        case 'wrong-password':
        case 'invalid-credential':
          errorMessage = 'パスワードが正しくありません';
          break;
        case 'invalid-email':
          errorMessage = 'メールアドレスの形式が正しくありません';
          break;
        case 'too-many-requests':
          errorMessage = 'リクエストが多すぎます。しばらくしてから再度お試しください';
          break;
        case 'user-disabled':
          errorMessage = 'このユーザーは無効化されています';
          break;
        default:
          errorMessage = 'ログイン中にエラーが発生しました: ${e.message}';
      }
    } catch (e) {
      isAuthenticated = false;
      errorMessage = '予期しないエラーが発生しました: $e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signUp(String email, String password, {String? displayName}) async {
    try {
      isLoading = true;
      notifyListeners();

      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      
      if (user != null) {
        // Set display name if provided
        if (displayName != null && displayName.isNotEmpty) {
          await user.updateDisplayName(displayName);
          await user.reload(); // Reload to get updated info
        }
        
        // Send email verification
        if (!user.emailVerified) {
          await user.sendEmailVerification();
        }
        
        // Create user profile in Firestore
        await _firestore.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'email': email,
          'name': displayName ?? email.split('@')[0],
          'createdAt': FieldValue.serverTimestamp(),
          'lastSeen': FieldValue.serverTimestamp(),
        });
        
        print('✅ New user profile created in Firestore');
      }
      
      isAuthenticated = true;
      errorMessage = null; // Clear any previous error messages
    } on FirebaseAuthException catch (e) {
      isAuthenticated = false;
      switch (e.code) {
        case 'email-already-in-use':
          errorMessage = 'このメールアドレスは既に使用されています';
          break;
        case 'weak-password':
          errorMessage = 'パスワードは6文字以上で入力してください';
          break;
        case 'invalid-email':
          errorMessage = 'メールアドレスの形式が正しくありません';
          break;
        default:
          errorMessage = '新規登録中にエラーが発生しました: ${e.message}';
      }
    } catch (e) {
      isAuthenticated = false;
      errorMessage = '予期しないエラーが発生しました: $e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // Check if the user is logged in
  Future<bool> isLoggedIn() async {
    final user = _auth.currentUser;
    if (user != null) {
      // Update last seen when checking login status
      await _createOrUpdateUserProfile(user);
      return true;
    }
    return false;
  }

  // Sign out the user
  Future<void> signOut() async {
    await _auth.signOut();
    isAuthenticated = false;
    notifyListeners(); // Notify listeners to update the UI
  }

  // Get the current user
  User? get user => _auth.currentUser;
}