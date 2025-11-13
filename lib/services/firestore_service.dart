import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  static Future<void> saveUserData(String uid, Map<String, dynamic> data) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).set(data);
  }

  static Future<Map<String, dynamic>?> getUserData(String uid) async {
    DocumentSnapshot doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    return doc.data() as Map<String, dynamic>?;
  }

  static Future<void> updateUserData(String uid, Map<String, dynamic> data) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).update(data);
  }
}