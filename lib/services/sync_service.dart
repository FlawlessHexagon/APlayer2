import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/playlist.dart';
import '../repositories/database_repository.dart';
import '../providers/database_provider.dart';
import '../providers/scanner_provider.dart';
import 'library_scanner.dart';

// 1. Google HTTP Client Extension
class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }
}

// 2. Sync Service
class SyncService {
  final DatabaseRepository _dbRepo;
  final LibraryScanner _scanner;
  
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [drive.DriveApi.driveFileScope],
  );

  GoogleSignInAccount? _currentUser;
  drive.DriveApi? _driveApi;
  String? _syncFolderId;

  SyncService(this._dbRepo, this._scanner) {
    _googleSignIn.onCurrentUserChanged.listen((account) {
      _currentUser = account;
    });
    _googleSignIn.signInSilently();
  }

  bool get isSignedIn => _currentUser != null;
  String? get userEmail => _currentUser?.email;

  Future<void> signIn() async {
    _currentUser = await _googleSignIn.signIn();
  }

  Future<void> signOut() async {
    await _googleSignIn.disconnect();
    _currentUser = null;
    _driveApi = null;
    _syncFolderId = null;
  }

  Future<void> _initDriveApi() async {
    if (_currentUser == null) throw Exception("Not signed in");
    final headers = await _currentUser!.authHeaders;
    final client = GoogleAuthClient(headers);
    _driveApi = drive.DriveApi(client);
  }

  Future<String> _getOrCreateSyncFolder() async {
    if (_syncFolderId != null) return _syncFolderId!;
    
    final query = "mimeType='application/vnd.google-apps.folder' and name='APlayer2_Sync' and trashed=false";
    final fileList = await _driveApi!.files.list(q: query, spaces: 'drive');
    
    if (fileList.files != null && fileList.files!.isNotEmpty) {
      _syncFolderId = fileList.files!.first.id;
      return _syncFolderId!;
    }
    
    final folder = drive.File()
      ..name = 'APlayer2_Sync'
      ..mimeType = 'application/vnd.google-apps.folder';
      
    final created = await _driveApi!.files.create(folder);
    _syncFolderId = created.id;
    return _syncFolderId!;
  }

  // --- SYNC ENGINE --- //

  Future<void> performSync(Function(String) onProgress) async {
    if (_currentUser == null) throw Exception("Must sign in before syncing");
    await _initDriveApi();
    
    onProgress("Initializing Sync Folder...");
    final folderId = await _getOrCreateSyncFolder();

    onProgress("Syncing Playlists...");
    await _syncPlaylists(folderId);

    onProgress("Mirroring Audio Files...");
    await _mirrorAudioFiles(folderId, onProgress);

    onProgress("Sync Complete!");
  }

  Future<void> _syncPlaylists(String folderId) async {
    // Fetch Remote Playlists
    final query = "'$folderId' in parents and mimeType='application/json' and trashed=false";
    final fileList = await _driveApi!.files.list(q: query, spaces: 'drive', $fields: 'files(id, name, modifiedTime)');
    final remoteFiles = fileList.files ?? [];
    
    // Fetch Local Playlists
    final localPlaylists = await _dbRepo.getAllPlaylists();
    final localMap = {for (var p in localPlaylists) p.id: p};
    
    // Remote to Local (or Overwrite Remote)
    for (var remoteFile in remoteFiles) {
      final playlistId = remoteFile.name!.replaceAll('.json', '');
      final remoteTime = remoteFile.modifiedTime?.millisecondsSinceEpoch ?? 0;
      
      if (localMap.containsKey(playlistId)) {
        final localP = localMap[playlistId]!;
        if (localP.lastModified > remoteTime) {
          // Local is newer -> Overwrite Remote
          await _uploadPlaylist(localP, remoteFile.id);
        } else if (remoteTime > localP.lastModified) {
          // Remote is newer -> Download to Local
          await _downloadAndSavePlaylist(remoteFile.id!);
        }
        localMap.remove(playlistId);
      } else {
        // Exists on Remote, missing locally -> Download
        await _downloadAndSavePlaylist(remoteFile.id!);
      }
    }
    
    // Upload remaining local-only playlists
    for (var localP in localMap.values) {
      await _uploadPlaylist(localP, null, folderId);
    }
  }

  Future<void> _uploadPlaylist(Playlist playlist, String? existingFileId, [String? parentFolderId]) async {
    final content = jsonEncode(playlist.toMap());
    final media = drive.Media(Stream.value(utf8.encode(content)), content.length);
    
    final driveFile = drive.File()
      ..name = '${playlist.id}.json'
      ..mimeType = 'application/json';
      
    if (existingFileId != null) {
      await _driveApi!.files.update(driveFile, existingFileId, uploadMedia: media);
    } else {
      driveFile.parents = [parentFolderId!];
      await _driveApi!.files.create(driveFile, uploadMedia: media);
    }
  }

  Future<void> _downloadAndSavePlaylist(String fileId) async {
    final drive.Media file = await _driveApi!.files.get(fileId, downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;
    final stream = file.stream;
    
    final bytes = await stream.expand((x) => x).toList();
    final content = utf8.decode(bytes);
    final map = jsonDecode(content);
    
    final playlist = Playlist.fromMap(map);
    await _dbRepo.insertPlaylist(playlist);
  }

  Future<void> _mirrorAudioFiles(String folderId, Function(String) onProgress) async {
    // Only download files, do NOT stream
    final query = "'$folderId' in parents and mimeType contains 'audio/' and trashed=false";
    final fileList = await _driveApi!.files.list(q: query, spaces: 'drive', $fields: 'files(id, name, modifiedTime)');
    final remoteFiles = fileList.files ?? [];
    
    if (remoteFiles.isEmpty) return;

    final appDocDir = await getApplicationDocumentsDirectory();
    final syncDir = Directory(p.join(appDocDir.path, 'APlayer2_Sync'));
    if (!await syncDir.exists()) {
      await syncDir.create(recursive: true);
    }

    bool downloadedAny = false;

    for (var i = 0; i < remoteFiles.length; i++) {
      final remoteFile = remoteFiles[i];
      final localPath = p.join(syncDir.path, remoteFile.name);
      final localFile = File(localPath);
      
      if (!await localFile.exists()) {
        onProgress("Downloading ${remoteFile.name} (${i + 1}/${remoteFiles.length})...");
        final drive.Media media = await _driveApi!.files.get(remoteFile.id!, downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;
        
        final sink = localFile.openWrite();
        await media.stream.forEach((chunk) {
          sink.add(chunk);
        });
        await sink.flush();
        await sink.close();
        downloadedAny = true;
      }
    }
    
    // Trigger Library Scanner if we downloaded new files
    if (downloadedAny) {
      onProgress("Scanning newly downloaded files...");
      await _scanner.scanDirectory(syncDir.path);
    }
  }
}

// Riverpod Provider
final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(
    ref.watch(databaseRepositoryProvider),
    ref.watch(libraryScannerProvider),
  );
});
