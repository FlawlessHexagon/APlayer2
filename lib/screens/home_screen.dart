import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import 'library_screen.dart';
import 'playlists_screen.dart';
import 'scanner_test_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  
  final List<Widget> _pages = const [
    LibraryScreen(),
    PlaylistsScreen(),
    ScannerTestScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: AppColors.deepPurple,
        selectedItemColor: AppColors.beige,
        unselectedItemColor: AppColors.midGrey,
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.library_music), label: 'Library'),
          BottomNavigationBarItem(icon: Icon(Icons.queue_music), label: 'Playlists'),
          BottomNavigationBarItem(icon: Icon(Icons.folder), label: 'Scanner'),
        ],
      ),
      floatingActionButton: _currentIndex == 0 ? FloatingActionButton(
        backgroundColor: AppColors.purpleAccent,
        foregroundColor: AppColors.beige,
        onPressed: () => context.push('/now_playing'),
        child: const Icon(Icons.play_arrow),
      ) : null,
    );
  }
}
