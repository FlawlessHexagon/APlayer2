import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:io';
import 'theme/app_theme.dart';
import 'providers/audio_provider.dart';

void main() {
  runApp(const ProviderScope(child: APlayerApp()));
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

class NowPlayingScreen extends ConsumerStatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  ConsumerState<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends ConsumerState<NowPlayingScreen> {
  Future<void> _loadTestTrack() async {
    final byteData = await rootBundle.load('assets/sample.wav');
    final file = File('${Directory.systemTemp.path}/sample.wav');
    await file.writeAsBytes(byteData.buffer.asUint8List());
    ref.read(playbackStateProvider.notifier).loadTrack(file.path);
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(d.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(d.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    final playbackState = ref.watch(playbackStateProvider);
    final positionAsync = ref.watch(playbackPositionProvider);
    
    final currentPosition = positionAsync.value ?? Duration.zero;
    final formattedPos = _formatDuration(currentPosition);
    final formattedDur = _formatDuration(playbackState.duration);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Now Playing'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Status: ${playbackState.status.name}',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 20),
            Text(
              '$formattedPos / $formattedDur',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _loadTestTrack,
                  child: const Text('Load Test Audio'),
                ),
                const SizedBox(width: 10),
                if (playbackState.status == PlaybackStatus.playing)
                  ElevatedButton(
                    onPressed: () => ref.read(playbackStateProvider.notifier).pause(),
                    child: const Text('Pause'),
                  )
                else
                  ElevatedButton(
                    onPressed: () => ref.read(playbackStateProvider.notifier).play(),
                    child: const Text('Play'),
                  ),
              ],
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () => context.pop(),
              child: const Text('Back to Home'),
            ),
          ],
        ),
      ),
    );
  }
}
