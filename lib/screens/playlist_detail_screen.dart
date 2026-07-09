import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/playlist.dart';
import '../models/track.dart';
import '../providers/library_provider.dart';
import '../providers/queue_provider.dart';
import '../theme/app_theme.dart';

final playlistDetailProvider = FutureProvider.family<List<Track>, String>((ref, playlistId) async {
  final playlists = await ref.watch(playlistsProvider.future);
  final playlist = playlists.firstWhere((p) => p.id == playlistId, orElse: () => throw Exception('Playlist not found'));
  final allTracks = await ref.watch(libraryTracksProvider.future);
  
  final trackMap = {for (var t in allTracks) t.id: t};
  List<Track> playlistTracks = [];
  for (var id in playlist.trackIds) {
    if (trackMap.containsKey(id)) {
      playlistTracks.add(trackMap[id]!);
    }
  }
  return playlistTracks;
});

class PlaylistDetailScreen extends ConsumerWidget {
  final String playlistId;

  const PlaylistDetailScreen({super.key, required this.playlistId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracksAsync = ref.watch(playlistDetailProvider(playlistId));
    final playlistsAsync = ref.watch(playlistsProvider);
    
    final playlist = playlistsAsync.value?.where((p) => p.id == playlistId).firstOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text(playlist?.name ?? 'Playlist'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Tracks',
            onPressed: () {
               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add Tracks coming soon')));
            },
          )
        ],
      ),
      body: tracksAsync.when(
        data: (tracks) {
          if (tracks.isEmpty) {
            return const Center(child: Text('Playlist is empty.', style: TextStyle(color: AppColors.midGrey)));
          }
          return ReorderableListView.builder(
            itemCount: tracks.length,
            onReorder: (oldIndex, newIndex) {
              if (oldIndex < newIndex) {
                newIndex -= 1;
              }
              if (playlist != null) {
                final newTrackIds = List<String>.from(playlist.trackIds);
                final item = newTrackIds.removeAt(oldIndex);
                newTrackIds.insert(newIndex, item);
                final newPlaylist = Playlist(
                  id: playlist.id,
                  name: playlist.name,
                  trackIds: newTrackIds,
                  lastModified: DateTime.now().millisecondsSinceEpoch,
                );
                ref.read(playlistsProvider.notifier).updatePlaylist(newPlaylist);
              }
            },
            itemBuilder: (context, index) {
              final track = tracks[index];
              return Card(
                key: ValueKey(track.id + '_$index'),
                color: AppColors.purpleAccent,
                margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                child: ListTile(
                  leading: const Icon(Icons.drag_handle, color: AppColors.beige),
                  title: Text(track.title, style: const TextStyle(color: AppColors.offWhite), maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(track.artist, style: const TextStyle(color: AppColors.midGrey), maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                    onPressed: () {
                      if (playlist != null) {
                        final newTrackIds = List<String>.from(playlist.trackIds);
                        newTrackIds.removeAt(index);
                        final newPlaylist = Playlist(
                          id: playlist.id,
                          name: playlist.name,
                          trackIds: newTrackIds,
                          lastModified: DateTime.now().millisecondsSinceEpoch,
                        );
                        ref.read(playlistsProvider.notifier).updatePlaylist(newPlaylist);
                      }
                    },
                  ),
                  onTap: () {
                    ref.read(queueStateProvider.notifier).setQueue(tracks, startIndex: index);
                    context.push('/now_playing');
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.beige)),
        error: (err, stack) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.red))),
      ),
    );
  }
}
