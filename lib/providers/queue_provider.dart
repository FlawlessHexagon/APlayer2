import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/track.dart';
import 'audio_provider.dart';

enum PlaybackMode { linear, repeatAll, repeatTrack }

class QueueState {
  final List<Track> currentPlaylist;
  final int currentIndex;
  final PlaybackMode mode;
  final bool isShuffleEnabled;
  final List<int> shuffleIndices;

  QueueState({
    this.currentPlaylist = const [],
    this.currentIndex = -1,
    this.mode = PlaybackMode.linear,
    this.isShuffleEnabled = false,
    this.shuffleIndices = const [],
  });

  Track? get currentTrack {
    if (currentIndex >= 0 && currentIndex < currentPlaylist.length) {
      return currentPlaylist[currentIndex];
    }
    return null;
  }

  QueueState copyWith({
    List<Track>? currentPlaylist,
    int? currentIndex,
    PlaybackMode? mode,
    bool? isShuffleEnabled,
    List<int>? shuffleIndices,
  }) {
    return QueueState(
      currentPlaylist: currentPlaylist ?? this.currentPlaylist,
      currentIndex: currentIndex ?? this.currentIndex,
      mode: mode ?? this.mode,
      isShuffleEnabled: isShuffleEnabled ?? this.isShuffleEnabled,
      shuffleIndices: shuffleIndices ?? this.shuffleIndices,
    );
  }
}

class QueueStateNotifier extends Notifier<QueueState> {
  bool _isTransitioning = false;
  
  @override
  QueueState build() {
    ref.listen<AsyncValue<Duration>>(playbackPositionProvider, (previous, next) {
      final pos = next.value;
      if (pos == null || _isTransitioning) return;
      
      final playbackState = ref.read(playbackStateProvider);
      if (playbackState.status == PlaybackStatus.playing && playbackState.duration.inMilliseconds > 0) {
        if (pos.inMilliseconds >= playbackState.duration.inMilliseconds - 100) {
          _onTrackFinished();
        }
      }
    });
    return QueueState();
  }

  Future<void> _onTrackFinished() async {
    _isTransitioning = true;
    if (state.mode == PlaybackMode.repeatTrack) {
      _playTrack(state.currentIndex);
    } else {
      await playNext(autoAdvance: true);
    }
    await Future.delayed(const Duration(milliseconds: 500));
    _isTransitioning = false;
  }

  void setQueue(List<Track> tracks, {int startIndex = 0}) {
    List<int> shuffleIndices = [];
    if (state.isShuffleEnabled && tracks.isNotEmpty) {
      shuffleIndices = _generateShuffleIndices(tracks.length, startIndex);
    }
    
    state = state.copyWith(
      currentPlaylist: tracks,
      currentIndex: startIndex,
      shuffleIndices: shuffleIndices,
    );
    
    _playTrack(startIndex);
  }

  void toggleShuffle() {
    final newShuffle = !state.isShuffleEnabled;
    List<int> newShuffleIndices = [];
    
    if (newShuffle && state.currentPlaylist.isNotEmpty) {
      newShuffleIndices = _generateShuffleIndices(state.currentPlaylist.length, state.currentIndex);
    }
    
    state = state.copyWith(
      isShuffleEnabled: newShuffle,
      shuffleIndices: newShuffleIndices,
    );
  }

  void toggleRepeatMode() {
    final nextMode = PlaybackMode.values[(state.mode.index + 1) % PlaybackMode.values.length];
    state = state.copyWith(mode: nextMode);
  }

  Future<void> playNext({bool autoAdvance = false}) async {
    if (state.currentPlaylist.isEmpty) return;
    
    int nextIndex = -1;
    
    if (state.isShuffleEnabled) {
      final currentShufflePos = state.shuffleIndices.indexOf(state.currentIndex);
      if (currentShufflePos != -1 && currentShufflePos + 1 < state.shuffleIndices.length) {
        nextIndex = state.shuffleIndices[currentShufflePos + 1];
      } else {
        if (state.mode == PlaybackMode.repeatAll || !autoAdvance) {
          final newIndices = _generateShuffleIndices(state.currentPlaylist.length, -1);
          state = state.copyWith(shuffleIndices: newIndices);
          nextIndex = newIndices[0];
        }
      }
    } else {
      if (state.currentIndex + 1 < state.currentPlaylist.length) {
        nextIndex = state.currentIndex + 1;
      } else {
        if (state.mode == PlaybackMode.repeatAll || !autoAdvance) {
          nextIndex = 0;
        }
      }
    }

    if (nextIndex != -1) {
      state = state.copyWith(currentIndex: nextIndex);
      _playTrack(nextIndex);
    }
  }

  Future<void> playPrevious() async {
    if (state.currentPlaylist.isEmpty) return;

    final pos = ref.read(playbackPositionProvider).value ?? Duration.zero;
    if (pos.inSeconds >= 3) {
      _playTrack(state.currentIndex);
      return;
    }

    int prevIndex = -1;

    if (state.isShuffleEnabled) {
      final currentShufflePos = state.shuffleIndices.indexOf(state.currentIndex);
      if (currentShufflePos > 0) {
        prevIndex = state.shuffleIndices[currentShufflePos - 1];
      } else {
        if (state.mode == PlaybackMode.repeatAll) {
          prevIndex = state.shuffleIndices.last;
        } else {
          prevIndex = state.shuffleIndices.first;
        }
      }
    } else {
      if (state.currentIndex > 0) {
        prevIndex = state.currentIndex - 1;
      } else {
        if (state.mode == PlaybackMode.repeatAll) {
          prevIndex = state.currentPlaylist.length - 1;
        } else {
          prevIndex = 0; 
        }
      }
    }

    if (prevIndex != -1) {
      state = state.copyWith(currentIndex: prevIndex);
      _playTrack(prevIndex);
    }
  }

  void jumpToIndex(int index) {
    if (index >= 0 && index < state.currentPlaylist.length) {
      state = state.copyWith(currentIndex: index);
      _playTrack(index);
    }
  }

  void _playTrack(int index) {
    if (index < 0 || index >= state.currentPlaylist.length) return;
    final track = state.currentPlaylist[index];
    ref.read(playbackStateProvider.notifier).loadTrack(track.filePath);
  }

  List<int> _generateShuffleIndices(int length, int forceFirstIndex) {
    if (length == 0) return [];
    final indices = List<int>.generate(length, (i) => i);
    final random = Random();
    
    for (int i = length - 1; i > 0; i--) {
      int j = random.nextInt(i + 1);
      final temp = indices[i];
      indices[i] = indices[j];
      indices[j] = temp;
    }
    
    if (forceFirstIndex != -1 && forceFirstIndex < length) {
      final currentIndexPos = indices.indexOf(forceFirstIndex);
      if (currentIndexPos != -1 && currentIndexPos != 0) {
        final temp = indices[0];
        indices[0] = indices[currentIndexPos];
        indices[currentIndexPos] = temp;
      }
    }
    
    return indices;
  }
}

final queueStateProvider = NotifierProvider<QueueStateNotifier, QueueState>(() {
  return QueueStateNotifier();
});
