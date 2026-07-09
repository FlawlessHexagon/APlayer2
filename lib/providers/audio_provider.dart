import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_dsp/audio_dsp.dart';

// 1. Engine Provider Initialization
final audioEngineProvider = Provider<AudioEngineController>((ref) {
  final controller = AudioEngineController();
  ref.onDispose(() {
    controller.dispose();
  });
  return controller;
});

// Playback Status Enum
enum PlaybackStatus { stopped, loading, playing, paused }

// Playback State Data Class
class PlaybackState {
  final PlaybackStatus status;
  final Duration duration;

  PlaybackState({
    this.status = PlaybackStatus.stopped,
    this.duration = Duration.zero,
  });

  PlaybackState copyWith({
    PlaybackStatus? status,
    Duration? duration,
  }) {
    return PlaybackState(
      status: status ?? this.status,
      duration: duration ?? this.duration,
    );
  }
}

// 2. Playback State Provider
class PlaybackStateNotifier extends Notifier<PlaybackState> {
  @override
  PlaybackState build() {
    _initEngine();
    return PlaybackState();
  }
  
  AudioEngineController get _engine => ref.read(audioEngineProvider);

  Future<void> _initEngine() async {
    if (!_engine.isInitialized) {
      await _engine.init();
    }
  }

  Future<void> loadTrack(String path) async {
    state = state.copyWith(status: PlaybackStatus.loading);
    try {
      await _initEngine();
      await _engine.load(path);
      state = state.copyWith(
        status: PlaybackStatus.playing,
        duration: _engine.duration,
      );
      _engine.play();
    } catch (e) {
      state = state.copyWith(status: PlaybackStatus.stopped);
    }
  }

  void play() {
    _engine.play();
    state = state.copyWith(status: PlaybackStatus.playing);
  }

  void pause() {
    _engine.pause();
    state = state.copyWith(status: PlaybackStatus.paused);
  }

  void seek(Duration position) {
    _engine.seek(position);
  }
}

final playbackStateProvider = NotifierProvider<PlaybackStateNotifier, PlaybackState>(() {
  return PlaybackStateNotifier();
});

// 3. High-Frequency Position Polling/Streaming
final playbackPositionProvider = StreamProvider<Duration>((ref) {
  final engine = ref.watch(audioEngineProvider);
  
  return Stream.periodic(const Duration(milliseconds: 33), (_) {
    return engine.position;
  }).distinct(); // Prevent unnecessary rebuilds when position is stagnant (e.g. paused)
});
