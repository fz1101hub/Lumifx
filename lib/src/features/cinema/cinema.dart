import '../../core/effects/effect.dart';
import '../../core/effects/effect_event.dart';

/// The moments of a film night.
enum CinemaPhase { film, intermission, end }

/// Lights for a film: they dim slowly when it starts, rise for the
/// intermission and come back little by little at the end, like at the
/// cinema.
abstract final class Cinema {
  static const _prefix = '${LightingEffect.generatedPrefix}cinema:';

  /// The warm light of the room before and after the film.
  static const warm = '#FFC870';

  /// A faint cool light behind the screen, easier on the eyes than the
  /// dark.
  static const glow = '#DCE6FF';
  static const glowLevel = 0.06;

  /// How long the lights take to dim, rise and come back.
  static const dimFor = Duration(seconds: 30);
  static const riseFor = Duration(seconds: 8);
  static const returnFor = Duration(seconds: 45);

  /// How long the film and the intermission hold before the lights go
  /// back to how they were by themselves.
  static const filmHold = Duration(hours: 4);
  static const intermissionHold = Duration(minutes: 20);

  /// The film starts: the lights dim to a faint glow, or to dark.
  static LightingEffect film(String name, {required bool withGlow}) {
    final level = withGlow ? glowLevel : 0.0;
    return _effect(
      '${CinemaPhase.film.name}:${withGlow ? 'glow' : 'dark'}',
      name,
      length: dimFor + filmHold,
      events: [
        _ramp(Duration.zero, dimFor, 0.6, level, warm, glow),
        _hold(dimFor, filmHold, glow, level),
      ],
    );
  }

  /// The intermission: the lights rise gently, warm and soft.
  static LightingEffect intermission(String name) => _effect(
        CinemaPhase.intermission.name,
        name,
        length: riseFor + intermissionHold,
        events: [
          _ramp(Duration.zero, riseFor, glowLevel, 0.5, glow, warm),
          _hold(riseFor, intermissionHold, warm, 0.5),
        ],
      );

  /// The end: the lights come back slowly, then the room returns to how
  /// it was.
  static LightingEffect end(String name) => _effect(
        CinemaPhase.end.name,
        name,
        length: returnFor + const Duration(seconds: 2),
        events: [
          _ramp(Duration.zero, returnFor, glowLevel, 0.7, glow, warm),
          _hold(returnFor, const Duration(seconds: 2), warm, 0.7),
        ],
      );

  /// The moment an effect belongs to, or null for any other effect.
  static CinemaPhase? phaseOf(LightingEffect effect) {
    if (!effect.id.startsWith(_prefix)) {
      return null;
    }
    final name = effect.id.substring(_prefix.length).split(':').first;
    return CinemaPhase.values.asNameMap()[name];
  }

  static LightingEffect _effect(
    String id,
    String name, {
    required Duration length,
    required List<EffectEvent> events,
  }) =>
      LightingEffect(
        id: '$_prefix$id',
        name: name,
        kind: EffectKind.scene,
        isLooping: false,
        loopDuration: length,
        events: events,
      );

  static EffectEvent _ramp(Duration at, Duration length, double from, double to,
          String color, String toColor) =>
      EffectEvent(
        at: at,
        duration: length,
        type: EffectEventTypes.ramp,
        parameters: {
          'from': from,
          'to': to,
          'color': color,
          'toColor': toColor,
        },
      );

  static EffectEvent _hold(
          Duration at, Duration length, String color, double level) =>
      EffectEvent(
        at: at,
        duration: length,
        type: EffectEventTypes.ambientPalette,
        parameters: {
          'palette': [color, color],
          'brightnessMin': level,
          'brightnessMax': level,
          'speed': 0.01,
        },
      );
}
