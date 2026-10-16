import '../../core/effects/effect.dart';
import '../../core/effects/effect_event.dart';

/// How a scene of the user's own moves.
enum SceneMotion {
  /// Colours change very slowly; brightness barely moves.
  calm,

  /// Colours drift from light to light.
  drift,

  /// Faster colour changes and deeper waves.
  lively,

  /// Restless, like flames or candles.
  flicker,
}

/// A scene the user made: two to five colours and a motion.
class UserScene {
  const UserScene({
    required this.id,
    required this.name,
    required this.colors,
    this.motion = SceneMotion.drift,
  });

  /// Always starts with [idPrefix], so it never collides with a built-in
  /// effect.
  final String id;
  final String name;

  /// `#RRGGBB` colours, in the order they travel.
  final List<String> colors;
  final SceneMotion motion;

  static const idPrefix = 'user:';
  static const minColors = 2;
  static const maxColors = 5;
  static const maxName = 60;
  static const maxId = 80;

  static String newId() => '$idPrefix${DateTime.now().microsecondsSinceEpoch}';

  /// The effect the player plays: an ambient palette like the built-in
  /// scenes, tuned by [motion].
  LightingEffect toEffect() {
    final (speed, low, high, flicker) = switch (motion) {
      SceneMotion.calm => (0.015, 0.45, 0.70, 0.0),
      SceneMotion.drift => (0.04, 0.30, 0.80, 0.0),
      SceneMotion.lively => (0.12, 0.25, 0.90, 0.0),
      SceneMotion.flicker => (0.08, 0.30, 0.85, 0.9),
    };
    return LightingEffect(
      id: id,
      name: name,
      kind: EffectKind.scene,
      loopDuration: const Duration(minutes: 5),
      events: [
        EffectEvent(
          at: Duration.zero,
          duration: const Duration(minutes: 5),
          type: EffectEventTypes.ambientPalette,
          parameters: {
            'palette': colors,
            'brightnessMin': low,
            'brightnessMax': high,
            'speed': speed,
            if (flicker > 0) 'flicker': flicker,
          },
        ),
      ],
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'colors': colors,
        'motion': motion.name,
      };

  static final _hex = RegExp(r'^#[0-9A-Fa-f]{6}$');

  /// Null when [json] is not a usable scene.
  static UserScene? fromJson(Object? json) {
    if (json is! Map) {
      return null;
    }
    final id = json['id'];
    final name = json['name'];
    final colors = json['colors'];
    if (id is! String ||
        !id.startsWith(idPrefix) ||
        id.length > maxId ||
        name is! String ||
        name.trim().isEmpty) {
      return null;
    }
    final palette = colors is List
        ? colors.whereType<String>().where(_hex.hasMatch).toList()
        : const <String>[];
    if (palette.length < minColors) {
      return null;
    }
    final trimmed = name.trim();
    return UserScene(
      id: id,
      name: trimmed.length > maxName
          ? String.fromCharCodes(trimmed.runes.take(maxName)).trim()
          : trimmed,
      colors: palette.take(maxColors).toList(),
      motion:
          SceneMotion.values.asNameMap()[json['motion']] ?? SceneMotion.drift,
    );
  }
}
