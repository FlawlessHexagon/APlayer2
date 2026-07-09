import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/database_provider.dart';
import '../models/track.dart';
import '../models/playlist.dart';

class DbTestScreen extends ConsumerStatefulWidget {
  const DbTestScreen({super.key});

  @override
  ConsumerState<DbTestScreen> createState() => _DbTestScreenState();
}

class _DbTestScreenState extends ConsumerState<DbTestScreen> {
  List<Track> _tracks = [];
  List<Playlist> _playlists = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    final repo = ref.read(databaseRepositoryProvider);
    final tracks = await repo.getAllTracks();
    final playlists = await repo.getAllPlaylists();
    setState(() {
      _tracks = tracks;
      _playlists = playlists;
    });
  }

  Future<void> _insertDummyTrack() async {
    final repo = ref.read(databaseRepositoryProvider);
    final track = Track(
      id: 'dummy_track_${DateTime.now().millisecondsSinceEpoch}',
      filePath: '/path/to/dummy.mp3',
      title: 'Dummy Title',
      artist: 'Dummy Artist',
      album: 'Dummy Album',
      durationMs: 240000,
      dateAdded: DateTime.now().millisecondsSinceEpoch,
    );
    await repo.insertTrack(track);
    await _fetchData();
  }

  Future<void> _insertDummyPlaylist() async {
    final repo = ref.read(databaseRepositoryProvider);
    final playlist = Playlist(
      id: 'dummy_playlist_${DateTime.now().millisecondsSinceEpoch}',
      name: 'My Dummy Playlist',
      trackIds: ['track_1', 'track_2'],
      lastModified: DateTime.now().millisecondsSinceEpoch,
    );
    await repo.insertPlaylist(playlist);
    await _fetchData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Database Validation')),
      body: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: _insertDummyTrack,
                child: const Text('Insert Dummy Track'),
              ),
              ElevatedButton(
                onPressed: _insertDummyPlaylist,
                child: const Text('Insert Dummy Playlist'),
              ),
            ],
          ),
          ElevatedButton(
            onPressed: _fetchData,
            child: const Text('Fetch Data'),
          ),
          const Divider(),
          const Text('Tracks:'),
          Expanded(
            child: ListView.builder(
              itemCount: _tracks.length,
              itemBuilder: (context, index) {
                final t = _tracks[index];
                return ListTile(
                  title: Text(t.title),
                  subtitle: Text('${t.id} - ${t.artist}'),
                );
              },
            ),
          ),
          const Divider(),
          const Text('Playlists:'),
          Expanded(
            child: ListView.builder(
              itemCount: _playlists.length,
              itemBuilder: (context, index) {
                final p = _playlists[index];
                return ListTile(
                  title: Text(p.name),
                  subtitle: Text('${p.id} - ${p.trackIds.length} tracks'),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
