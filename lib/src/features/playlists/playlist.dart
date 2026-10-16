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
  static const maxName = 60;
  static const maxEffects = 200;

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
    if (id is! String ||
        id.length > 80 ||
        name is! String ||
        name.trim().isEmpty ||
        effects is! List) {
      return null;
    }
    final each = json['eachSeconds'];
    final seconds = each is num && each.isFinite ? each.toInt() : 600;
    final trimmed = name.trim();
    return Playlist(
      id: id,
      name: trimmed.length > maxName
          ? String.fromCharCodes(trimmed.runes.take(maxName)).trim()
          : trimmed,
      effectIds: [
        for (final e in effects.whereType<String>().take(maxEffects))
          if (e.length <= 80) e,
      ],
      each: Duration(seconds: seconds.clamp(10, 24 * 3600)),
      shuffle: json['shuffle'] == true,
    );
  }
}
