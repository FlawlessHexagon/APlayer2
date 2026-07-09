import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'audio_provider.dart';

class APlayerAudioHandler extends BaseAudioHandler {
  final ProviderContainer _container;

  APlayerAudioHandler(this._container) {
    // Listen to our Riverpod state and broadcast to audio_service
    _container.listen<AppPlaybackState>(playbackStateProvider, (previous, next) {
      _broadcastState();
    });
    
    // Listen to position stream to broadcast position
    _container.listen<AsyncValue<Duration>>(playbackPositionProvider, (previous, next) {
      if (next.hasValue) {
        _broadcastState();
      }
    });
  }

  void _broadcastState() {
    final state = _container.read(playbackStateProvider);
    final positionAsync = _container.read(playbackPositionProvider);
    final position = positionAsync.value ?? Duration.zero;

    AudioProcessingState processingState;
    bool playing = false;

    switch (state.status) {
      case PlaybackStatus.playing:
        playing = true;
        processingState = AudioProcessingState.ready;
        break;
      case PlaybackStatus.paused:
        playing = false;
        processingState = AudioProcessingState.ready;
        break;
      case PlaybackStatus.loading:
        playing = false;
        processingState = AudioProcessingState.loading;
        break;
      case PlaybackStatus.stopped:
        playing = false;
        processingState = AudioProcessingState.idle;
        break;
    }

    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 3],
      processingState: processingState,
      playing: playing,
      updatePosition: position,
      bufferedPosition: position,
      speed: 1.0,
    ));
    
    // Broadcast metadata with duration
    mediaItem.add(MediaItem(
      id: 'dummy_id',
      title: 'Validation Track',
      artist: 'APlayer',
      duration: state.duration,
    ));
  }

  @override
  Future<void> play() async {
    _container.read(playbackStateProvider.notifier).play();
  }

  @override
  Future<void> pause() async {
    _container.read(playbackStateProvider.notifier).pause();
  }

  @override
  Future<void> seek(Duration position) async {
    _container.read(playbackStateProvider.notifier).seek(position);
  }

  @override
  Future<void> stop() async {
    _container.read(playbackStateProvider.notifier).pause();
    _container.read(playbackStateProvider.notifier).seek(Duration.zero);
  }
}
