import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserEditScreen extends StatefulWidget {
  const UserEditScreen({super.key});

  @override
  State<UserEditScreen> createState() => _UserEditScreenState();
}

class _UserEditScreenState extends State<UserEditScreen> {
  final _usernameFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();
  String? _name;
  String? _password;

  Future<void> _saveUsername() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ユーザーがログインしていません')), // "User is not logged in"
        );
        return;
      }

      final uid = user.uid;

      if (_usernameFormKey.currentState!.validate()) {
        _usernameFormKey.currentState!.save();

        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'name': _name,
        }, SetOptions(merge: true));

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ユーザー名が更新されました')), // "Username updated"
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エラーが発生しました: $e')), // "An error occurred"
      );
    }
  }

  Future<void> _savePassword() async {
    try {
      // Get the current user
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ユーザーがログインしていません')), // "User is not logged in"
        );
        return;
      }

      if (_passwordFormKey.currentState!.validate()) {
        _passwordFormKey.currentState!.save();

        // Update password if provided
        if (_password != null && _password!.isNotEmpty) {
          await user.updatePassword(_password!);

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('パスワードが更新されました')), // "Password updated"
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エラーが発生しました: $e')), // "An error occurred"
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('ユーザー情報編集'), // "Edit User Information"
        ),
        body: const Center(
          child: Text('ログインしてください。'), // "Please log in."
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('ユーザー情報編集'), // "Edit User Information"
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            // Change Username Section
            Card(
              elevation: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _usernameFormKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ユーザー名を変更', // "Change Username"
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: '名前', // "Name"
                          prefixIcon: Icon(Icons.person),
                          border: OutlineInputBorder(),
                        ),
                        onSaved: (value) => _name = value,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return '名前を入力してください'; // "Please enter a name"
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _saveUsername,
                        icon: const Icon(Icons.save),
                        label: const Text('保存'), // "Save"
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Change Password Section
            Card(
              elevation: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _passwordFormKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'パスワードを変更', // "Change Password"
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: '新しいパスワード', // "New Password"
                          prefixIcon: Icon(Icons.lock),
                          border: OutlineInputBorder(),
                        ),
                        onSaved: (value) => _password = value,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'パスワードを入力してください'; // "Please enter a password"
                          } else if (value.length < 6) {
                            return 'パスワードは6文字以上である必要があります'; // "Password must be at least 6 characters"
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _savePassword,
                        icon: const Icon(Icons.save),
                        label: const Text('保存'), // "Save"
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}