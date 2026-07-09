import 'dart:io';
import 'dart:async';
import 'dart:isolate';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:audiotags/audiotags.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/track.dart';
import '../repositories/database_repository.dart';

class LibraryScanner {
  final DatabaseRepository dbRepo;
  
  LibraryScanner(this.dbRepo);

  final _progressController = StreamController<String>.broadcast();
  Stream<String> get progressStream => _progressController.stream;

  Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      if (await Permission.audio.request().isGranted) {
        return true;
      }
      if (await Permission.storage.request().isGranted) {
        return true;
      }
      return false;
    }
    return true;
  }

  Future<void> scanDirectory(String rootPath) async {
    final hasPermission = await requestPermissions();
    if (!hasPermission) {
      _progressController.add("Permission denied.");
      return;
    }

    _progressController.add("Scanning directory...");
    
    final dir = Directory(rootPath);
    if (!await dir.exists()) {
      _progressController.add("Directory does not exist.");
      return;
    }

    final List<String> audioFiles = [];
    final allowedExtensions = {'.mp3', '.wav', '.flac', '.m4a', '.aac'};

    try {
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          final ext = p.extension(entity.path).toLowerCase();
          if (allowedExtensions.contains(ext)) {
            audioFiles.add(entity.path);
          }
        }
      }
    } catch (e) {
      _progressController.add("Error reading directory: $e");
    }

    final total = audioFiles.length;
    _progressController.add("Found $total audio files. Extracting metadata...");

    if (total == 0) return;

    final token = RootIsolateToken.instance;
    final appDir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory(p.join(appDir.path, 'album_art'));
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }

    const batchSize = 50;
    for (var i = 0; i < total; i += batchSize) {
      final end = (i + batchSize < total) ? i + batchSize : total;
      final batch = audioFiles.sublist(i, end);

      _progressController.add("Parsing metadata: $i to $end of $total...");

      List<Track> tracks;
      try {
        if (token != null) {
          // Offload to background isolate to prevent UI frame drops
          tracks = await Isolate.run(() => _processBatch(batch, token, cacheDir.path));
        } else {
          tracks = await _processBatch(batch, null, cacheDir.path);
        }
      } catch (e) {
        // Fallback to main thread if Isolate platform channels crash
        tracks = await _processBatch(batch, null, cacheDir.path);
      }

      for (final track in tracks) {
        await dbRepo.insertTrack(track);
      }
    }

    _progressController.add("Scan complete! Added $total tracks.");
  }

  static Future<List<Track>> _processBatch(List<String> paths, RootIsolateToken? token, String cacheDirPath) async {
    if (token != null) {
      BackgroundIsolateBinaryMessenger.ensureInitialized(token);
    }
    
    final List<Track> results = [];

    for (final path in paths) {
      String title = p.basenameWithoutExtension(path);
      String artist = "Unknown";
      String album = "Unknown";
      int durationMs = 0;

      try {
        final tag = await AudioTags.read(path);
        if (tag != null) {
          title = tag.title ?? title;
          artist = tag.trackArtist ?? tag.albumArtist ?? "Unknown";
          album = tag.album ?? "Unknown";
          durationMs = (tag.duration != null) ? (tag.duration! * 1000).toInt() : 0;

          if (tag.pictures.isNotEmpty) {
            final pic = tag.pictures.first;
            if (pic.bytes.isNotEmpty) {
              final hash = md5.convert(pic.bytes).toString();
              final artPath = p.join(cacheDirPath, '$hash.jpg');
              final artFile = File(artPath);
              if (!await artFile.exists()) {
                await artFile.writeAsBytes(pic.bytes);
              }
            }
          }
        }
      } catch (e) {
        // Tag parsing failed, fallback to filename
      }

      final trackHash = md5.convert(utf8.encode(path)).toString();
      
      results.add(Track(
        id: trackHash,
        filePath: path,
        title: title,
        artist: artist,
        album: album,
        durationMs: durationMs,
        dateAdded: DateTime.now().millisecondsSinceEpoch,
      ));
    }

    return results;
  }
}
