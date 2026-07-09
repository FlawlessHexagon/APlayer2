import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/track.dart';
import '../models/playlist.dart';

class DatabaseRepository {
  static const String _dbName = 'aplayer2.db';
  static const int _dbVersion = 1;
  
  Database? _db;

  Future<void> init() async {
    if (_db != null) return;
    
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    _db = await openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE tracks (
            id TEXT PRIMARY KEY,
            filePath TEXT NOT NULL,
            title TEXT NOT NULL,
            artist TEXT NOT NULL,
            album TEXT NOT NULL,
            durationMs INTEGER NOT NULL,
            dateAdded INTEGER NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE playlists (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            trackIds TEXT NOT NULL,
            lastModified INTEGER NOT NULL
          )
        ''');
      },
    );
  }

  // --- Track Operations ---

  Future<void> insertTrack(Track track) async {
    await _db!.insert(
      'tracks',
      track.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Track>> getAllTracks() async {
    final maps = await _db!.query('tracks', orderBy: 'dateAdded DESC');
    return maps.map((map) => Track.fromMap(map)).toList();
  }

  Future<void> deleteTrack(String id) async {
    await _db!.delete('tracks', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearAllTracks() async {
    await _db!.delete('tracks');
  }

  // --- Playlist Operations ---

  Future<void> insertPlaylist(Playlist playlist) async {
    await _db!.insert(
      'playlists',
      playlist.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Playlist>> getAllPlaylists() async {
    final maps = await _db!.query('playlists', orderBy: 'lastModified DESC');
    return maps.map((map) => Playlist.fromMap(map)).toList();
  }

  Future<void> deletePlaylist(String id) async {
    await _db!.delete('playlists', where: 'id = ?', whereArgs: [id]);
  }
}
