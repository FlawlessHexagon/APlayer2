import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/track.dart';
import '../models/playlist.dart';
import 'database_provider.dart';

enum TrackSortType { title, artist, dateAdded }

class TrackSortNotifier extends Notifier<TrackSortType> {
  @override
  TrackSortType build() => TrackSortType.dateAdded;
  void setSort(TrackSortType sort) => state = sort;
}

final trackSortProvider = NotifierProvider<TrackSortNotifier, TrackSortType>(() => TrackSortNotifier());

final libraryTracksProvider = FutureProvider<List<Track>>((ref) async {
  final repo = ref.watch(databaseRepositoryProvider);
  final tracks = await repo.getAllTracks();
  final sortType = ref.watch(trackSortProvider);
  
  switch (sortType) {
    case TrackSortType.title:
      tracks.sort((a, b) => a.title.compareTo(b.title));
      break;
    case TrackSortType.artist:
      tracks.sort((a, b) => a.artist.compareTo(b.artist));
      break;
    case TrackSortType.dateAdded:
      tracks.sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
      break;
  }
  return tracks;
});

class PlaylistsNotifier extends AsyncNotifier<List<Playlist>> {
  @override
  Future<List<Playlist>> build() async {
    return ref.watch(databaseRepositoryProvider).getAllPlaylists();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => ref.read(databaseRepositoryProvider).getAllPlaylists());
  }

  Future<void> createPlaylist(String name) async {
    final repo = ref.read(databaseRepositoryProvider);
    final playlist = Playlist(
      id: 'pl_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      trackIds: [],
      lastModified: DateTime.now().millisecondsSinceEpoch,
    );
    await repo.insertPlaylist(playlist);
    await refresh();
  }

  Future<void> updatePlaylist(Playlist playlist) async {
    final repo = ref.read(databaseRepositoryProvider);
    final updated = Playlist(
      id: playlist.id,
      name: playlist.name,
      trackIds: playlist.trackIds,
      lastModified: DateTime.now().millisecondsSinceEpoch,
    );
    await repo.insertPlaylist(updated);
    await refresh();
  }

  Future<void> deletePlaylist(String id) async {
    final repo = ref.read(databaseRepositoryProvider);
    await repo.deletePlaylist(id);
    await refresh();
  }
}

final playlistsProvider = AsyncNotifierProvider<PlaylistsNotifier, List<Playlist>>(() {
  return PlaylistsNotifier();
});
