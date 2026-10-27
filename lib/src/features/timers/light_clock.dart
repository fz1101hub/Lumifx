import '../../core/effects/effect.dart';
import '../../core/effects/effect_event.dart';

/// What the light clock counts down to; it picks what the voice says.
enum ClockOccasion { leave, meal, bed, other }

/// Where the light clock is: plenty of time, getting ready, the last
/// minutes, or time.
enum ClockPhase { green, yellow, red, now }

/// A clock for children who cannot read the time yet: the lamps stay
/// green, turn yellow a few minutes before a set time ("we leave at
/// 7:50"), red for the last two minutes, and pulse red when it is time.
/// Tied to the clock on the wall, so it ignores the speed set.
abstract final class LightClock {
  /// How long before the time the lamps turn yellow, in minutes.
  static const warnChoices = [5, 10, 15];

  /// Red for this long before the time.
  static const lastCall = Duration(minutes: 2);

  /// Pulsing red for this long after the time, then the lamps go back.
  static const after = Duration(minutes: 3);

  /// How long the lamps take to turn from one colour to the next.
  static const turning = Duration(seconds: 15);

  static const green = '#3DDC84';
  static const yellow = '#FFD23F';
  static const red = '#FF4D4D';

  static const _prefix = '${LightingEffect.realTimePrefix}clock:';

  /// The next time the clock shows [hour]:[minute] after [now]: today, or
  /// tomorrow when it has passed.
  static DateTime nextAt(DateTime now, int hour, int minute) {
    final today = DateTime(now.year, now.month, now.day, hour, minute);
    return today.isAfter(now) ? today : today.add(const Duration(days: 1));
  }

  /// Where the clock is at [now], counting down to [at].
  static ClockPhase phaseAt(DateTime now, DateTime at, int warnMinutes) {
    final left = at.difference(now);
    if (left <= Duration.zero) {
      return ClockPhase.now;
    }
    if (left <= lastCall) {
      return ClockPhase.red;
    }
    return left <= Duration(minutes: warnMinutes)
        ? ClockPhase.yellow
        : ClockPhase.green;
  }

  /// The effect from [now] until [after] past [at], named [name]; it
  /// plays once.
  static LightingEffect effect(
    String name, {
    required DateTime now,
    required DateTime at,
    required int warnMinutes,
    ClockOccasion occasion = ClockOccasion.other,
  }) {
    final total = at.isAfter(now) ? at.difference(now) : Duration.zero;
    final warn = Duration(minutes: warnMinutes);
    final yellowFrom = total > warn ? total - warn : Duration.zero;
    final redFrom = total > lastCall ? total - lastCall : Duration.zero;
    EffectEvent glow(Duration from, Duration until, String color,
            {double brightness = 0.7, double speed = 0.01}) =>
        EffectEvent(
          at: from,
          duration: until - from,
          type: EffectEventTypes.ambientPalette,
          parameters: {
            'palette': <String>[color, color],
            'brightnessMin': brightness - 0.05,
            'brightnessMax': brightness + 0.05,
            'speed': speed,
          },
        );
    EffectEvent turn(Duration at, String from, String to) => EffectEvent(
          at: at,
          duration: turning,
          type: EffectEventTypes.ramp,
          parameters: {'color': from, 'toColor': to, 'from': 0.7, 'to': 0.7},
        );
    return LightingEffect(
      id: '$_prefix${occasion.name}:'
          '${at.millisecondsSinceEpoch ~/ Duration.millisecondsPerMinute}:'
          '$warnMinutes',
      name: name,
      kind: EffectKind.interactive,
      isLooping: false,
      loopDuration: total + after,
      events: [
        if (yellowFrom > Duration.zero) glow(Duration.zero, yellowFrom, green),
        if (redFrom > yellowFrom) glow(yellowFrom, redFrom, yellow),
        if (total > redFrom) glow(redFrom, total, red),
        if (yellowFrom > Duration.zero) turn(yellowFrom, green, yellow),
        if (redFrom > yellowFrom && redFrom > Duration.zero)
          turn(redFrom, yellow, red),
        // Time: a slow, bright red breath, never a flash.
        EffectEvent(
          at: total,
          duration: after,
          type: EffectEventTypes.ambientPalette,
          parameters: const {
            'palette': <String>[red, '#FF2E2E'],
            'brightnessMin': 0.35,
            'brightnessMax': 0.95,
            'speed': 0.25,
          },
        ),
      ],
    );
  }

  /// What a light clock counts down to, or null for any other effect.
  static ({ClockOccasion occasion, DateTime at, int warnMinutes})? of(
      LightingEffect effect) {
    if (!effect.id.startsWith(_prefix)) {
      return null;
    }
    final parts = effect.id.substring(_prefix.length).split(':');
    if (parts.length != 3) {
      return null;
    }
    final occasion = ClockOccasion.values.asNameMap()[parts[0]];
    final minutes = int.tryParse(parts[1]);
    final warn = int.tryParse(parts[2]);
    if (occasion == null || minutes == null || warn == null || warn <= 0) {
      return null;
    }
    return (
      occasion: occasion,
      at: DateTime.fromMillisecondsSinceEpoch(
          minutes * Duration.millisecondsPerMinute),
      warnMinutes: warn,
    );
  }
}
