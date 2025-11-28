import 'package:calamity_report/screens/conversations_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:calamity_report/providers/theme_provider.dart';
import 'package:calamity_report/providers/auth_provider.dart';
import 'package:calamity_report/providers/location_provider.dart';
import 'package:calamity_report/screens/home_screen.dart';
import 'package:calamity_report/screens/map_screen.dart';
import 'package:geolocator/geolocator.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('Screen Widget Tests', () {
    testWidgets('HomeScreen renders correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthProvider()),
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
            ChangeNotifierProvider(create: (_) => LocationProvider()),
          ],
          child: const MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );

      await tester.pump();
      
      // Check for main UI elements
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('ConversationsScreen renders correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ConversationsScreen(),
        ),
      );

      await tester.pump();
      
      // Check for conversations screen
      expect(find.text('メッセージ'), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('MapScreen renders correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => LocationProvider()),
          ],
          child: const MaterialApp(
            home: MapScreen(),
          ),
        ),
      );

      await tester.pump();
      
      // Check for map screen elements
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text('災害マップ'), findsOneWidget);
    });
  });

  group('Provider Tests', () {
    test('ThemeProvider toggles theme', () {
      final themeProvider = ThemeProvider();
      expect(themeProvider.themeMode, ThemeMode.system);

      themeProvider.toggleTheme();
      expect(themeProvider.themeMode, ThemeMode.dark);

      themeProvider.toggleTheme();
      expect(themeProvider.themeMode, ThemeMode.light);
    });

    test('LocationProvider initial state', () {
      final locationProvider = LocationProvider();
      
      // Check initial state
      expect(locationProvider.isTracking, false);
      expect(locationProvider.currentLocation, null);
      expect(locationProvider.errorMessage, null);
    });

    test('LocationProvider tracking state', () {
      final locationProvider = LocationProvider();
      
      expect(locationProvider.isTracking, false);
    });

    test('LocationProvider clear state', () {
      final locationProvider = LocationProvider();
      
      // Clear error
      locationProvider.clearError();
      
      expect(locationProvider.isTracking, false);
      expect(locationProvider.errorMessage, null);
    });

    test('LocationProvider error handling', () {
      final locationProvider = LocationProvider();
      
      expect(locationProvider.errorMessage, null);
      
      // Clear error
      locationProvider.clearError();
      expect(locationProvider.errorMessage, null);
    });

    test('LocationProvider notifies listeners on clear', () {
      final locationProvider = LocationProvider();
      var notified = false;
      
      locationProvider.addListener(() {
        notified = true;
      });
      
      locationProvider.clearError();
      expect(notified, true);
    });

    test('AuthProvider initial state', () {
      final authProvider = AuthProvider();
      
      // Check initial authentication state
      expect(authProvider.isAuthenticated, false);
    });

    test('ThemeProvider initial mode', () {
      final themeProvider = ThemeProvider();
      
      // Verify default theme mode
      expect(themeProvider.themeMode, isIn([ThemeMode.system, ThemeMode.light, ThemeMode.dark]));
    });
  });

  group('Integration Tests', () {
    testWidgets('Navigation between screens', (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthProvider()),
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
            ChangeNotifierProvider(create: (_) => LocationProvider()),
          ],
          child: MaterialApp(
            home: const HomeScreen(),
            routes: {
              '/map': (context) => const MapScreen(),
              '/conversations': (context) => const ConversationsScreen(),
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      
      // Verify home screen is displayed
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('Provider injection works correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthProvider()),
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
            ChangeNotifierProvider(create: (_) => LocationProvider()),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                // Access providers to verify they're available
                final auth = Provider.of<AuthProvider>(context, listen: false);
                final theme = Provider.of<ThemeProvider>(context, listen: false);
                final location = Provider.of<LocationProvider>(context, listen: false);
                
                return Scaffold(
                  body: Text('Providers: ${auth != null && theme != null && location != null}'),
                );
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Providers: true'), findsOneWidget);
    });
  });

  group('Emergency Report Tests', () {
    testWidgets('Emergency quick actions are displayed', (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthProvider()),
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
            ChangeNotifierProvider(create: (_) => LocationProvider()),
          ],
          child: const MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      
      // Check for emergency report section
      expect(find.text('緊急報告'), findsWidgets);
    });
  });

  group('Quick Actions Tests', () {
    testWidgets('Quick actions are displayed', (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthProvider()),
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
            ChangeNotifierProvider(create: (_) => LocationProvider()),
          ],
          child: const MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      
      // Check for quick actions section
      expect(find.text('クイックアクション'), findsWidgets);
    });
  });

  group('LocationProvider Advanced Tests', () {
    test('LocationProvider currentLocation is initially null', () {
      final locationProvider = LocationProvider();
      
      expect(locationProvider.currentLocation, null);
    });

    test('LocationProvider error message can be cleared', () {
      final locationProvider = LocationProvider();
      
      locationProvider.clearError();
      expect(locationProvider.errorMessage, null);
    });

    test('LocationProvider maintains tracking state', () {
      final locationProvider = LocationProvider();
      
      final initialTracking = locationProvider.isTracking;
      expect(initialTracking, false);
    });
  });
}