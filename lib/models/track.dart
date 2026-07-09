class Track {
  final String id;
  final String filePath;
  final String title;
  final String artist;
  final String album;
  final int durationMs;
  final int dateAdded;

  Track({
    required this.id,
    required this.filePath,
    required this.title,
    required this.artist,
    required this.album,
    required this.durationMs,
    required this.dateAdded,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'filePath': filePath,
      'title': title,
      'artist': artist,
      'album': album,
      'durationMs': durationMs,
      'dateAdded': dateAdded,
    };
  }

  factory Track.fromMap(Map<String, dynamic> map) {
    return Track(
      id: map['id'],
      filePath: map['filePath'],
      title: map['title'],
      artist: map['artist'],
      album: map['album'],
      durationMs: map['durationMs'],
      dateAdded: map['dateAdded'],
    );
  }
}
