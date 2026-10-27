import 'dart:math' as math;

import '../../core/effects/effect.dart';
import '../../core/effects/effect_event.dart';

/// The eight phases of the moon, from new to waning crescent.
enum MoonPhase {
  newMoon,
  waxingCrescent,
  firstQuarter,
  waxingGibbous,
  full,
  waningGibbous,
  lastQuarter,
  waningCrescent,
}

/// Tonight's moon, worked out on the phone (no internet): its phase, how
/// much of it is lit, and the lamps showing it, the lit part on the side
/// it is lit from (as seen from the northern hemisphere).
abstract final class Moon {
  /// Days from one new moon to the next.
  static const synodicMonth = 29.530588853;

  /// A new moon, the count starts from.
  static final _newMoon = DateTime.utc(2000, 1, 6, 18, 14);

  static const night = '#0B1A40';
  static const moonlight = '#DDE8FF';

  /// How long the lamps show the moon, then go back.
  static const lasts = Duration(minutes: 10);

  static const _prefix = '${LightingEffect.generatedPrefix}moon:';

  /// The moon's age at [when]: days since the last new moon.
  static double ageOf(DateTime when) {
    final days = when.toUtc().difference(_newMoon).inSeconds / 86400;
    final age = days % synodicMonth;
    return age < 0 ? age + synodicMonth : age;
  }

  /// How much of the moon is lit at [when], 0 (new) to 1 (full).
  static double litOf(DateTime when) =>
      (1 - math.cos(2 * math.pi * ageOf(when) / synodicMonth)) / 2;

  static bool isWaxing(DateTime when) => ageOf(when) < synodicMonth / 2;

  static MoonPhase phaseOf(DateTime when) =>
      MoonPhase.values[((ageOf(when) / synodicMonth) * 8 + 0.5).floor() % 8];

  /// Whole days until the next full moon (0 tonight).
  static int daysToFull(DateTime when) {
    final until = (synodicMonth / 2 - ageOf(when)) % synodicMonth;
    final days = until.round();
    return days >= synodicMonth.round() ? 0 : days;
  }

  /// The lamps showing the moon at [when]: deep night blue, the lit part
  /// in moonlight across the room.
  static LightingEffect effect(String name, DateTime when) {
    final lit = litOf(when);
    return LightingEffect(
      id: '$_prefix${phaseOf(when).name}:${(lit * 100).round()}',
      name: name,
      kind: EffectKind.scene,
      isLooping: false,
      loopDuration: lasts,
      events: [
        const EffectEvent(
          at: Duration.zero,
          duration: lasts,
          type: EffectEventTypes.ambientPalette,
          parameters: {
            'palette': <String>[night, night],
            'brightnessMin': 0.05,
            'brightnessMax': 0.08,
            'speed': 0.01,
          },
        ),
        EffectEvent(
          at: Duration.zero,
          duration: lasts,
          type: EffectEventTypes.progress,
          parameters: {
            'value': lit,
            'from': night,
            'to': moonlight,
            'brightness': 0.6,
            'fromEnd': isWaxing(when),
          },
        ),
      ],
    );
  }

  /// The phase shown by a moon effect, or null for any other effect.
  static MoonPhase? of(LightingEffect effect) => effect.id.startsWith(_prefix)
      ? MoonPhase.values
          .asNameMap()[effect.id.substring(_prefix.length).split(':').first]
      : null;
}
