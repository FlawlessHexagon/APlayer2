import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'theme/app_theme.dart';
import 'providers/audio_provider.dart';
import 'providers/audio_handler.dart';
import 'screens/now_playing_screen.dart';
import 'screens/dsp_control_screen.dart';

late APlayerAudioHandler audioHandler;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final session = await AudioSession.instance;
  await session.configure(const AudioSessionConfiguration.music());

  final container = ProviderContainer();
  
  audioHandler = await AudioService.init(
    builder: () => APlayerAudioHandler(container),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.aplayer2.audio',
      androidNotificationChannelName: 'APlayer2 Playback',
      androidNotificationOngoing: true,
    ),
  );

  runApp(UncontrolledProviderScope(
    container: container,
    child: const APlayerApp(),
  ));
}

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/now_playing',
      builder: (context, state) => const NowPlayingScreen(),
    ),
    GoRoute(
      path: '/dsp',
      builder: (context, state) => const DspControlScreen(),
    ),
  ],
);

class APlayerApp extends StatelessWidget {
  const APlayerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'APlayer2',
      theme: AppTheme.darkTheme,
      routerConfig: _router,
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Library (Home)'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Home Screen / Library Dummy',
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => context.push('/now_playing'),
              child: const Text('Go to Now Playing'),
            ),
          ],
        ),
      ),
    );
  }
}

// NowPlayingScreen has been moved to lib/screens/now_playing_screen.dart
