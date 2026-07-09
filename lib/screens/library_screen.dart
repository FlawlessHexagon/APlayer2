import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/library_provider.dart';
import '../providers/queue_provider.dart';
import '../theme/app_theme.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracksAsync = ref.watch(libraryTracksProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Library'),
        actions: [
          PopupMenuButton<TrackSortType>(
            icon: const Icon(Icons.sort, color: AppColors.offWhite),
            color: AppColors.purpleAccent,
            onSelected: (sort) {
              ref.read(trackSortProvider.notifier).setSort(sort);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: TrackSortType.dateAdded, child: Text('Sort by Date Added', style: TextStyle(color: AppColors.offWhite))),
              const PopupMenuItem(value: TrackSortType.title, child: Text('Sort by Title', style: TextStyle(color: AppColors.offWhite))),
              const PopupMenuItem(value: TrackSortType.artist, child: Text('Sort by Artist', style: TextStyle(color: AppColors.offWhite))),
            ],
          ),
        ],
      ),
      body: tracksAsync.when(
        data: (tracks) {
          if (tracks.isEmpty) {
            return const Center(child: Text('No tracks found.', style: TextStyle(color: AppColors.midGrey)));
          }
          return ListView.builder(
            itemCount: tracks.length,
            itemBuilder: (context, index) {
              final track = tracks[index];
              return Card(
                color: AppColors.purpleAccent,
                margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                child: ListTile(
                  leading: const Icon(Icons.music_note, color: AppColors.beige),
                  title: Text(track.title, style: const TextStyle(color: AppColors.offWhite), maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(track.artist, style: const TextStyle(color: AppColors.midGrey), maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: Text(
                    _formatDuration(Duration(milliseconds: track.durationMs)),
                    style: const TextStyle(color: AppColors.midGrey),
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

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(d.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(d.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }
}
