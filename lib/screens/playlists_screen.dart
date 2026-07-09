import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/library_provider.dart';
import '../theme/app_theme.dart';

class PlaylistsScreen extends ConsumerWidget {
  const PlaylistsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlistsAsync = ref.watch(playlistsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Playlists'),
      ),
      body: playlistsAsync.when(
        data: (playlists) {
          if (playlists.isEmpty) {
            return const Center(child: Text('No playlists found.', style: TextStyle(color: AppColors.midGrey)));
          }
          return ListView.builder(
            itemCount: playlists.length,
            itemBuilder: (context, index) {
              final playlist = playlists[index];
              return Card(
                color: AppColors.purpleAccent,
                margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                child: ListTile(
                  leading: const Icon(Icons.playlist_play, color: AppColors.beige),
                  title: Text(playlist.name, style: const TextStyle(color: AppColors.offWhite)),
                  subtitle: Text('${playlist.trackIds.length} tracks', style: const TextStyle(color: AppColors.midGrey)),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: AppColors.midGrey),
                    onPressed: () {
                      ref.read(playlistsProvider.notifier).deletePlaylist(playlist.id);
                    },
                  ),
                  onTap: () {
                    context.push('/playlist/${playlist.id}');
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.beige)),
        error: (err, stack) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.red))),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.beige,
        foregroundColor: AppColors.nearBlack,
        onPressed: () {
          _showCreateDialog(context, ref);
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.deepPurple,
          title: const Text('Create Playlist', style: TextStyle(color: AppColors.offWhite)),
          content: TextField(
            controller: controller,
            style: const TextStyle(color: AppColors.offWhite),
            decoration: const InputDecoration(
              hintText: 'Playlist Name',
              hintStyle: TextStyle(color: AppColors.midGrey),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.midGrey)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.beige)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: AppColors.midGrey)),
            ),
            TextButton(
              onPressed: () {
                final text = controller.text.trim();
                if (text.isNotEmpty) {
                  ref.read(playlistsProvider.notifier).createPlaylist(text);
                }
                Navigator.pop(context);
              },
              child: const Text('Create', style: TextStyle(color: AppColors.beige)),
            ),
          ],
        );
      },
    );
  }
}
