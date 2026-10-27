import '../../core/effects/effect.dart';
import '../library/sentence_scene.dart';
import '../library/user_scene.dart';

/// A dream told in the morning: its words (and maybe the child's voice),
/// and the colours they paint, to show in the room.
class Dream {
  const Dream({
    required this.id,
    required this.child,
    required this.date,
    required this.words,
    required this.colors,
    required this.motion,
  });

  /// From the words told: the colours of what they name, or a dreamy
  /// palette when no word is known.
  factory Dream.told({
    required String id,
    required String child,
    required DateTime date,
    required String words,
  }) {
    final scene = sceneFromSentence(words);
    return Dream(
      id: id,
      child: child,
      date: date,
      words: words.trim(),
      colors: scene?.colors ?? dreamy,
      motion: scene?.motion ?? SceneMotion.calm,
    );
  }

  final String id;

  /// The child's id ('' for the first child or without profiles).
  final String child;
  final DateTime date;
  final String words;
  final List<String> colors;
  final SceneMotion motion;

  static const maxWords = 500;
  static const maxDreams = 60;

  /// The colours of a dream with no word the app knows.
  static const dreamy = ['#9B30FF', '#5B2EFF', '#FF6F91', '#8FD3FF'];

  static String newId() => 'd${DateTime.now().microsecondsSinceEpoch}';

  /// Where the child's voice telling it is kept.
  String get recordingKey => recordingKeyOf(id);

  static String recordingKeyOf(String id) => 'dream-$id';

  static const _prefix = '${LightingEffect.generatedPrefix}dream:';

  /// The dream in the room.
  LightingEffect effect(String name) {
    final scene = UserScene(
      id: '$_prefix$id',
      name: name,
      colors: colors,
      motion: motion,
    ).toEffect();
    return LightingEffect(
      id: scene.id,
      name: scene.name,
      kind: EffectKind.scene,
      loopDuration: scene.loopDuration,
      events: scene.events,
    );
  }

  /// Whether [effect] is a dream shown.
  static bool isDream(LightingEffect effect) => effect.id.startsWith(_prefix);

  Map<String, Object?> toJson() => {
        'id': id,
        'child': child,
        'date': date.millisecondsSinceEpoch,
        'words': words,
        'colors': colors,
        'motion': motion.name,
      };

  static final _hex = RegExp(r'^#[0-9A-Fa-f]{6}$');

  /// Null when [json] is not a usable dream.
  static Dream? fromJson(Object? json) {
    if (json is! Map) {
      return null;
    }
    final id = json['id'];
    final child = json['child'];
    final date = json['date'];
    final words = json['words'];
    final colors = json['colors'];
    if (id is! String ||
        id.isEmpty ||
        id.length > 40 ||
        child is! String ||
        child.length > 40 ||
        date is! int ||
        words is! String ||
        words.length > maxWords ||
        colors is! List ||
        colors.length < UserScene.minColors ||
        colors.length > UserScene.maxColors ||
        colors.any((c) => c is! String || !_hex.hasMatch(c))) {
      return null;
    }
    return Dream(
      id: id,
      child: child,
      date: DateTime.fromMillisecondsSinceEpoch(date),
      words: words,
      colors: colors.cast<String>(),
      motion:
          SceneMotion.values.asNameMap()[json['motion']] ?? SceneMotion.calm,
    );
  }
}
