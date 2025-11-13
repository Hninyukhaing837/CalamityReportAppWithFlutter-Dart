import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/auth_provider.dart';
import 'package:go_router/go_router.dart';
import '../screens/settings_screen.dart';
import '../screens/notification_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<String?> _fetchUsername(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists) {
        return doc['name']; // Retrieve the 'name' field
      }
    } catch (e) {
      debugPrint('Error fetching username: $e');
    }
    return null;
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ホーム'), // "Home"
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // User Profile Header
            FutureBuilder<String?>(
              future: user != null ? _fetchUsername(user.uid) : null,
              builder: (context, snapshot) {
                final userName = snapshot.data ?? user?.displayName ?? user?.email?.split('@')[0] ?? 'ユーザー';
                final userEmail = user?.email ?? '';
                
                return UserAccountsDrawerHeader(
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                  ),
                  currentAccountPicture: CircleAvatar(
                    backgroundColor: Colors.white,
                    child: Text(
                      _getInitials(userName),
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                  accountName: Text(
                    userName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  accountEmail: Text(userEmail),
                );
              },
            ),
            
            // Existing Menu Items
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('設定'), // "Settings"
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.notifications),
              title: const Text('通知'), // "Notifications"
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const NotificationScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('ログアウト'), // "Logout"
              onTap: () async {
                await authProvider.signOut();
                if (context.mounted) {
                  context.go('/login');
                }
              },
            ),
          ],
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.emergency, size: 100),
            const SizedBox(height: 24),
            Text(
              '緊急報告ダッシュボード', // "Emergency Report Dashboard"
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            FutureBuilder<String?>(
              future: _fetchUsername(user?.uid ?? ''),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Text('ユーザー名を取得中...'); // "Fetching username..."
                } else if (snapshot.hasError) {
                  return const Text('ユーザー名の取得に失敗しました'); // "Failed to fetch username"
                } else if (snapshot.hasData && snapshot.data != null) {
                  return Text(
                    'ようこそ、${snapshot.data}さん', // "Welcome, [username]"
                    style: Theme.of(context).textTheme.bodyLarge,
                  );
                } else {
                  return const Text('ようこそ、ユーザー'); // "Welcome, User"
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}