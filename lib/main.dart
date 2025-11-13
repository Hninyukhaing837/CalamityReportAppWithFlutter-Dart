import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/media_provider.dart';
import 'providers/location_provider.dart';
import 'providers/notification_provider.dart';
import 'routes/app_router.dart';
import 'services/notification_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Initialize Firebase Messaging
Future<void> initializeFirebaseMessaging() async {
  if (kIsWeb) {
    try {
      await FirebaseMessaging.instance.getToken(
        vapidKey: 'YOUR_VAPID_KEY', // Replace with your actual VAPID key from Firebase Console
      );
    } catch (e) {
      print('Firebase Messaging not available: $e');
      // Handle gracefully - continue without push notifications
    }
  } else {
    // For mobile platforms
    try {
      await FirebaseMessaging.instance.requestPermission();
      String? token = await FirebaseMessaging.instance.getToken();
      print('FCM Token: $token');
    } catch (e) {
      print('Error initializing Firebase Messaging: $e');
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await NotificationService.initializeFCM();
  
  if (!kIsWeb) {
    // Mobile-specific Firebase Messaging logic
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    // Request permission for notifications (iOS-specific)
    await messaging.requestPermission();

    // Listen for foreground notifications
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Notification received: ${message.notification?.title}');

      // Add the notification to the provider
      final notificationProvider = Provider.of<NotificationProvider>(
        navigatorKey.currentContext!,
        listen: false,
      );

      notificationProvider.addNotification({
        'title': message.notification?.title ?? 'No Title',
        'body': message.notification?.body ?? 'No Body',
      });
    });

    // Listen for background notifications
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } else {
    // Web-specific Firebase Messaging logic
    print('Running on Web: Firebase Messaging initialized for web.');
  }

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

// Background message handler for mobile
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Background message received: ${message.notification?.title}');
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => MediaProvider()),
        ChangeNotifierProvider(create: (_) => LocationProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp.router(
            title: 'Calamity Report',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.red,
                brightness: Brightness.light,
              ),
              useMaterial3: true,
            ),
            darkTheme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.red,
                brightness: Brightness.dark,
              ),
              useMaterial3: true,
            ),
            themeMode: themeProvider.themeMode,
            routerConfig: AppRouter.router,
          );
        },
      ),
    );
  }
}
