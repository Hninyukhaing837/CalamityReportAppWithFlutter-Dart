import 'package:calamity_report/screens/conversations_screen.dart';
import 'package:calamity_report/screens/direct_chat_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import '../screens/splash_screen.dart';
import '../screens/login_screen.dart';
import '../screens/main_navigator.dart';
import '../screens/home_screen.dart';
import '../screens/map_screen.dart';
import '../screens/media_upload_screen.dart';
import '../screens/notification_screen.dart';
import '../screens/settings_screen.dart'; 
import '../screens/theme_screen.dart'; 

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainNavigator(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            // routes: [
            //   GoRoute(
            //     path: '/chat',
            //     builder: (context, state) => const ChatScreen(),
            //   ),
            // ],
            routes: [
              GoRoute(
                path: '/chat',
                builder: (context, state) => const ConversationsScreen(), // List of users
              ),
              // Direct chat with specific user (optional - can use Navigator.push instead)
              GoRoute(
                path: '/chat/:userId',
                builder: (context, state) {
                  final userId = state.pathParameters['userId']!;
                  final userName = state.uri.queryParameters['name'] ?? 'User';
                  // Note: Color needs to be passed differently or generated
                  return DirectChatScreen(
                    otherUserId: userId,
                    otherUserName: userName,
                    otherUserColor: Colors.blue, // Default color
                  );
                },
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/map',
                builder: (context, state) => const MapScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/media',
                builder: (context, state) => const MediaUploadScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/theme',
                builder: (context, state) => const ThemeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/notifications',
                builder: (context, state) => const NotificationScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}