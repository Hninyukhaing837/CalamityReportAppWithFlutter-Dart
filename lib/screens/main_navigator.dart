import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MainNavigator extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MainNavigator({
    super.key,
    required this.navigationShell,
  });

  void _onTap(int index) {
    print('Navigating to index: $index');
    navigationShell.goBranch(
      index,
      initialLocation: false, // Do not reset to the initial location
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _onTap,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'ホーム',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_outlined),
            selectedIcon: Icon(Icons.chat),
            label: 'チャット',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'マップ',
          ),
          NavigationDestination(
            icon: Icon(Icons.photo_library_outlined),
            selectedIcon: Icon(Icons.photo_library),
            label: 'メディア',
          )
        ],
      ),
    );
  }
}