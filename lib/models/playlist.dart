import 'dart:convert';

class Playlist {
  final String id;
  final String name;
  final List<String> trackIds;
  final int lastModified;

  Playlist({
    required this.id,
    required this.name,
    required this.trackIds,
    required this.lastModified,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'trackIds': jsonEncode(trackIds),
      'lastModified': lastModified,
    };
  }

  factory Playlist.fromMap(Map<String, dynamic> map) {
    return Playlist(
      id: map['id'],
      name: map['name'],
      trackIds: List<String>.from(jsonDecode(map['trackIds'])),
      lastModified: map['lastModified'],
    );
  }
}
