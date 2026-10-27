import '../../core/effects/effect.dart';
import '../../core/effects/effect_event.dart';

/// What helps after naming a feeling.
enum FeelingHelp { none, breathe, story, rest }

/// A feeling a child can name by tapping it: the room takes its colour.
/// Anger and worry start in their colour and slowly cool to a calm blue,
/// while the voice suggests what helps.
enum Feeling {
  happy('#FFD23F', FeelingHelp.none),
  calm('#7FE0B0', FeelingHelp.none),
  sad('#5C8DFF', FeelingHelp.story),
  angry('#FF4D4D', FeelingHelp.breathe),
  worried('#B388FF', FeelingHelp.breathe),
  tired('#7A7AE0', FeelingHelp.rest);

  const Feeling(this.color, this.help);

  final String color;
  final FeelingHelp help;

  /// How long the room keeps the feeling's light, then goes back.
  static const lasts = Duration(minutes: 15);

  /// How long anger and worry take to cool down.
  static const cooling = Duration(seconds: 90);
  static const calmColor = '#8FD8FF';

  static const _prefix = '${LightingEffect.generatedPrefix}feeling:';

  bool get cools => this == angry || this == worried;

  double get _brightness => switch (this) {
        tired => 0.25,
        sad => 0.45,
        happy => 0.8,
        _ => 0.6,
      };

  /// The feeling's light, named [name]; it plays once, for [lasts].
  LightingEffect effect(String name) {
    EffectEvent glow(Duration at, Duration length, String color) => EffectEvent(
          at: at,
          duration: length,
          type: EffectEventTypes.ambientPalette,
          parameters: {
            'palette': <String>[color, color],
            'brightnessMin': _brightness - 0.08,
            'brightnessMax': _brightness + 0.05,
            'speed': this == happy ? 0.06 : 0.015,
          },
        );
    return LightingEffect(
      id: '$_prefix${this.name}',
      name: name,
      kind: EffectKind.scene,
      isLooping: false,
      loopDuration: lasts,
      events: cools
          ? [
              glow(Duration.zero, const Duration(seconds: 5), color),
              EffectEvent(
                at: const Duration(seconds: 5),
                duration: cooling,
                type: EffectEventTypes.ramp,
                parameters: {
                  'color': color,
                  'toColor': calmColor,
                  'from': _brightness,
                  'to': 0.45,
                },
              ),
              EffectEvent(
                at: const Duration(seconds: 5) + cooling,
                duration: lasts - cooling - const Duration(seconds: 5),
                type: EffectEventTypes.ambientPalette,
                parameters: const {
                  'palette': <String>[calmColor, '#A6E3FF'],
                  'brightnessMin': 0.4,
                  'brightnessMax': 0.5,
                  'speed': 0.01,
                },
              ),
            ]
          : [glow(Duration.zero, lasts, color)],
    );
  }

  /// The feeling shown by a feelings effect, or null for any other.
  static Feeling? of(LightingEffect effect) => effect.id.startsWith(_prefix)
      ? Feeling.values.asNameMap()[effect.id.substring(_prefix.length)]
      : null;
}
