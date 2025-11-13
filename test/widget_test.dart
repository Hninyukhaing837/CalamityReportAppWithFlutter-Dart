import 'package:calamity_report/screens/conversations_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:calamity_report/providers/theme_provider.dart';
import 'package:calamity_report/providers/auth_provider.dart';
import 'package:calamity_report/providers/media_provider.dart';
import 'package:calamity_report/providers/location_provider.dart';
import 'package:calamity_report/screens/home_screen.dart';
import 'package:calamity_report/screens/map_screen.dart';
import 'package:calamity_report/screens/media_screen.dart';

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
          ],
          child: const MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('Home'), findsOneWidget);
      expect(find.byIcon(Icons.emergency), findsOneWidget);
    });

    testWidgets('ConversationsScreen renders correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ConversationsScreen(),
        ),
      );

      await tester.pump();
      expect(find.text('メッセージ'), findsOneWidget); // "Messages"
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
      expect(find.text('Map'), findsOneWidget);
    });

    testWidgets('MediaScreen renders correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => MediaProvider()),
          ],
          child: const MaterialApp(
            home: MediaScreen(),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('Media'), findsOneWidget);
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

    test('MediaProvider manages media files', () {
      final mediaProvider = MediaProvider();
      expect(mediaProvider.selectedMedia, isEmpty);
      expect(mediaProvider.isUploading, false);
    });

    test('LocationProvider tracks state', () {
      final locationProvider = LocationProvider();
      expect(locationProvider.isTracking, false);
      expect(locationProvider.currentLocation, null);
    });
  });
}