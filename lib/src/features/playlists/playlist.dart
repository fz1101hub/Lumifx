/// Effects played one after the other, each for [each], in a loop.
class Playlist {
  const Playlist({
    required this.id,
    required this.name,
    required this.effectIds,
    this.each = const Duration(minutes: 10),
    this.shuffle = false,
  });

  final String id;
  final String name;
  final List<String> effectIds;
  final Duration each;

  /// Picks the next effect at random (never the same twice in a row)
  /// instead of going in order.
  final bool shuffle;

  /// The durations offered in the editor, in minutes.
  static const durations = [1, 5, 10, 15, 30, 60];

  Playlist copyWith({
    String? name,
    List<String>? effectIds,
    Duration? each,
    bool? shuffle,
  }) =>
      Playlist(
        id: id,
        name: name ?? this.name,
        effectIds: effectIds ?? this.effectIds,
        each: each ?? this.each,
        shuffle: shuffle ?? this.shuffle,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'effects': effectIds,
        'eachSeconds': each.inSeconds,
        'shuffle': shuffle,
      };

  /// Null when [json] is not a playlist (corrupt or from a future version).
  static Playlist? fromJson(Object? json) {
    if (json is! Map) {
      return null;
    }
    final id = json['id'];
    final name = json['name'];
    final effects = json['effects'];
    if (id is! String || name is! String || effects is! List) {
      return null;
    }
    final seconds = (json['eachSeconds'] as num?)?.toInt() ?? 600;
    return Playlist(
      id: id,
      name: name,
      effectIds: effects.whereType<String>().toList(),
      each: Duration(seconds: seconds.clamp(10, 24 * 3600)),
      shuffle: json['shuffle'] as bool? ?? false,
    );
  }
}
