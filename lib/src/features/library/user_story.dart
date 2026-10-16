import '../../core/effects/effect.dart';
import '../../core/effects/effect_event.dart';
import 'user_scene.dart';

/// What happens at a moment of a story of the user's own.
enum StoryMomentKind {
  /// A short flash on one light.
  spark(hasColor: true, defaultColor: '#FFD84D'),

  /// Every light flashes at once.
  spell(hasColor: true, defaultColor: '#FF7AD9'),

  /// A light wanders from lamp to lamp.
  wander(hasColor: true, defaultColor: '#22D763'),

  /// A light rushes across the room.
  whoosh(hasColor: true, defaultColor: '#FF7A1A'),

  /// Little flashes here and there.
  sparkles(hasColor: true, defaultColor: '#FFF4E5'),

  /// The room goes almost dark for a moment.
  darkness(hasColor: false, defaultColor: '#000000'),

  /// A few very short strikes.
  lightning(hasColor: true, defaultColor: '#E8F0FF'),

  /// Steps coming closer from one end of the room.
  footsteps(hasColor: true, defaultColor: '#FFD9A0'),

  /// Only words to read, the lights carry on.
  wordsOnly(hasColor: false, defaultColor: '#000000');

  const StoryMomentKind({required this.hasColor, required this.defaultColor});

  final bool hasColor;
  final String defaultColor;

  /// How long the light of this moment lasts, at most.
  Duration get length => switch (this) {
        spark => const Duration(milliseconds: 700),
        spell => const Duration(milliseconds: 1200),
        wander => const Duration(seconds: 8),
        whoosh => const Duration(seconds: 3),
        sparkles => const Duration(seconds: 4),
        darkness => const Duration(seconds: 3),
        lightning => const Duration(milliseconds: 1500),
        footsteps => const Duration(seconds: 6),
        wordsOnly => Duration.zero,
      };
}

/// One moment of a story: [at] seconds in, a [kind] of light in [color],
/// and optional [words] to read along.
class StoryMoment {
  const StoryMoment({
    required this.at,
    required this.kind,
    String? color,
    this.words = '',
  }) : color = color ?? '';

  final int at;
  final StoryMomentKind kind;

  /// `#RRGGBB`; empty for the kind's own colour.
  final String color;
  final String words;

  String get effectiveColor => color.isEmpty ? kind.defaultColor : color;

  StoryMoment copyWith({
    int? at,
    StoryMomentKind? kind,
    String? color,
    String? words,
  }) =>
      StoryMoment(
        at: at ?? this.at,
        kind: kind ?? this.kind,
        color: color ?? this.color,
        words: words ?? this.words,
      );

  /// The event that plays this moment in a story [length] seconds long, or
  /// null for [StoryMomentKind.wordsOnly].
  EffectEvent? toEvent(int length) {
    final start = Duration(seconds: at);
    final room = Duration(seconds: length) - start;
    final duration = kind.length < room ? kind.length : room;
    final color = effectiveColor;
    final (String type, Map<String, Object> parameters) = switch (kind) {
      StoryMomentKind.spark => (
          EffectEventTypes.magicFlash,
          {'color': color, 'target': 'random_light'},
        ),
      StoryMomentKind.spell => (
          EffectEventTypes.magicFlash,
          {'color': color, 'target': 'all', 'brightness': 0.9},
        ),
      StoryMomentKind.wander => (
          EffectEventTypes.travel,
          {'color': color, 'pattern': 'random_walk', 'stepDuration': 800},
        ),
      StoryMomentKind.whoosh => (
          EffectEventTypes.travel,
          {'color': color, 'pattern': 'sweep', 'width': 1.6, 'brightness': 1.0},
        ),
      StoryMomentKind.sparkles => (
          EffectEventTypes.surprise,
          {'color': color, 'count': 4},
        ),
      StoryMomentKind.darkness => (
          EffectEventTypes.dim,
          {'level': 0.1},
        ),
      StoryMomentKind.lightning => (
          EffectEventTypes.lightning,
          {'color': color, 'strikes': 3, 'target': 'random_lights'},
        ),
      StoryMomentKind.footsteps => (
          EffectEventTypes.footsteps,
          {
            'color': color,
            'interval': 700,
            'steps': 8,
            'crescendo': 0.6,
            'pattern': 'approach',
          },
        ),
      StoryMomentKind.wordsOnly => ('', const <String, Object>{}),
    };
    if (type.isEmpty || duration <= Duration.zero) {
      return null;
    }
    return EffectEvent(
      at: start,
      duration: duration,
      type: type,
      parameters: parameters,
    );
  }

  Map<String, Object?> toJson() => {
        'at': at,
        'kind': kind.name,
        if (color.isNotEmpty) 'color': color,
        if (words.isNotEmpty) 'words': words,
      };

  /// Null when [json] is not a usable moment of a story [length] seconds
  /// long.
  static StoryMoment? fromJson(Object? json, int length) {
    if (json is! Map) {
      return null;
    }
    final at = json['at'];
    final kind = StoryMomentKind.values.asNameMap()[json['kind']];
    if (at is! int || at < 0 || at >= length || kind == null) {
      return null;
    }
    final color = json['color'];
    final words = json['words'];
    return StoryMoment(
      at: at,
      kind: kind,
      color: color is String && UserStory.isColor(color) ? color : '',
      words: words is String ? UserStory.clip(words, UserStory.maxWords) : '',
    );
  }
}

/// A story the user made: background colours that move like a scene, and
/// moments on a timeline (sparks, footsteps, darkness...), each with words
/// to read along if they like.
class UserStory {
  UserStory({
    required this.id,
    required this.name,
    required this.colors,
    this.motion = SceneMotion.drift,
    this.length = defaultLength,
    List<StoryMoment> moments = const [],
  }) : moments = [...moments]..sort((a, b) => a.at.compareTo(b.at));

  /// Always starts with [idPrefix], so it never collides with a built-in
  /// effect or a scene.
  final String id;
  final String name;

  /// `#RRGGBB` background colours.
  final List<String> colors;
  final SceneMotion motion;

  /// Seconds before the story starts over.
  final int length;

  /// In time order.
  final List<StoryMoment> moments;

  static const idPrefix = 'story:';
  static const minLength = 20;
  static const maxLength = 300;
  static const defaultLength = 60;
  static const maxMoments = 20;
  static const maxName = 60;
  static const maxWords = 160;

  static String newId() => '$idPrefix${DateTime.now().microsecondsSinceEpoch}';

  static final _hex = RegExp(r'^#[0-9A-Fa-f]{6}$');
  static bool isColor(String value) => _hex.hasMatch(value);

  /// [text] trimmed and cut to [max] characters.
  static String clip(String text, int max) {
    final trimmed = text.trim();
    final runes = trimmed.runes;
    return runes.length <= max
        ? trimmed
        : String.fromCharCodes(runes.take(max)).trim();
  }

  /// The words to read along, with the second each one appears.
  List<(int, String)> get narration => [
        for (final moment in moments)
          if (moment.words.isNotEmpty) (moment.at, moment.words),
      ];

  /// The effect the player plays: the background as a scene, the moments
  /// on top, starting over every [length] seconds.
  LightingEffect toEffect() {
    final background = UserScene(
      id: id,
      name: name,
      colors: colors,
      motion: motion,
    ).toEffect().events.single;
    final loop = Duration(seconds: length);
    return LightingEffect(
      id: id,
      name: name,
      kind: EffectKind.story,
      loopDuration: loop,
      events: [
        EffectEvent(
          at: Duration.zero,
          duration: loop,
          type: background.type,
          // Dimmer than a scene, so the moments stand out.
          parameters: {
            ...background.parameters,
            'brightnessMin':
                (background.parameters['brightnessMin']! as double) * 0.6,
            'brightnessMax':
                (background.parameters['brightnessMax']! as double) * 0.7,
          },
        ),
        for (final moment in moments)
          if (moment.toEvent(length) case final event?) event,
      ],
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'colors': colors,
        'motion': motion.name,
        'length': length,
        'moments': [for (final m in moments) m.toJson()],
      };

  /// Null when [json] is not a usable story.
  static UserStory? fromJson(Object? json) {
    if (json is! Map) {
      return null;
    }
    final id = json['id'];
    final name = json['name'];
    final colors = json['colors'];
    if (id is! String ||
        !id.startsWith(idPrefix) ||
        id.length > 80 ||
        name is! String ||
        name.trim().isEmpty) {
      return null;
    }
    final palette = colors is List
        ? colors.whereType<String>().where(isColor).toList()
        : const <String>[];
    if (palette.length < UserScene.minColors) {
      return null;
    }
    final rawLength = json['length'];
    final length = rawLength is int
        ? rawLength.clamp(minLength, maxLength)
        : defaultLength;
    final moments = json['moments'];
    return UserStory(
      id: id,
      name: clip(name, maxName),
      colors: palette.take(UserScene.maxColors).toList(),
      motion:
          SceneMotion.values.asNameMap()[json['motion']] ?? SceneMotion.drift,
      length: length,
      moments: [
        if (moments is List)
          for (final item in moments.take(maxMoments))
            if (StoryMoment.fromJson(item, length) case final moment?) moment,
      ],
    );
  }
}
