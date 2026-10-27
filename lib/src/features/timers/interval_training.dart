import '../../core/effects/effect.dart';
import '../../core/effects/effect_event.dart';

/// Ready-made workouts: seconds of work and rest, and the usual rounds.
enum WorkoutPreset {
  hiit(work: 40, rest: 20, rounds: 8),
  tabata(work: 20, rest: 10, rounds: 8),
  stretching(work: 30, rest: 15, rounds: 6);

  const WorkoutPreset({
    required this.work,
    required this.rest,
    required this.rounds,
  });

  final int work;
  final int rest;
  final int rounds;
}

/// What the lights say: get ready, work, rest, or done.
enum IntervalKind { ready, work, rest, done }

/// Interval training shown by the lights: yellow to get ready, bright
/// green while working, calm blue while resting, and three slow pulses in
/// the last three seconds of each part. Tied to the clock on the wall.
class IntervalWorkout {
  IntervalWorkout({
    required this.work,
    required this.rest,
    required this.rounds,
  }) : assert(rounds > 0);

  final Duration work;
  final Duration rest;
  final int rounds;

  static const getReady = Duration(seconds: 10);
  static const roundChoices = [4, 6, 8, 10];

  /// The end, a little party.
  static const ending = Duration(seconds: 6);

  static const ready = '#FFD23F';
  static const workColor = '#3DDC84';
  static const restColor = '#3D7BFF';

  static const _prefix = '${LightingEffect.realTimePrefix}intervals:';

  /// The parts in order: (kind, round from 1, start, length).
  List<(IntervalKind, int, Duration, Duration)> get parts {
    final parts = <(IntervalKind, int, Duration, Duration)>[
      (IntervalKind.ready, 0, Duration.zero, getReady),
    ];
    var at = getReady;
    for (var round = 1; round <= rounds; round++) {
      parts.add((IntervalKind.work, round, at, work));
      at += work;
      if (round < rounds) {
        parts.add((IntervalKind.rest, round, at, rest));
        at += rest;
      }
    }
    return parts;
  }

  /// When the last round ends.
  Duration get length {
    final last = parts.last;
    return last.$3 + last.$4;
  }

  /// The part at [position], with what is left of it.
  ({IntervalKind kind, int round, Duration left}) at(Duration position) {
    for (final (kind, round, start, length) in parts) {
      if (position >= start && position < start + length) {
        return (kind: kind, round: round, left: start + length - position);
      }
    }
    return (kind: IntervalKind.done, round: rounds, left: Duration.zero);
  }

  LightingEffect effect(String name) {
    EffectEvent glow(Duration at, Duration length, String color,
            double brightness, double speed) =>
        EffectEvent(
          at: at,
          duration: length,
          type: EffectEventTypes.ambientPalette,
          parameters: {
            'palette': <String>[color, color],
            'brightnessMin': brightness - 0.05,
            'brightnessMax': brightness + 0.05,
            'speed': speed,
          },
        );
    final end = length;
    return LightingEffect(
      id: '$_prefix$rounds:${work.inSeconds}:${rest.inSeconds}',
      name: name,
      kind: EffectKind.interactive,
      isLooping: false,
      loopDuration: end + ending,
      events: [
        for (final (kind, _, start, length) in parts) ...[
          switch (kind) {
            IntervalKind.ready => glow(start, length, ready, 0.6, 0.02),
            IntervalKind.work => glow(start, length, workColor, 0.9, 0.08),
            _ => glow(start, length, restColor, 0.45, 0.02),
          },
          // The last three seconds, one slow pulse each: never a strobe.
          for (var s = 3; s >= 1; s--)
            if (length > const Duration(seconds: 4))
              EffectEvent(
                at: start + length - Duration(seconds: s),
                duration: const Duration(milliseconds: 500),
                type: EffectEventTypes.magicFlash,
                parameters: const {
                  'color': '#FFFFFF',
                  'target': 'all',
                  'brightness': 0.9,
                },
              ),
        ],
        EffectEvent(
          at: end,
          duration: ending,
          type: EffectEventTypes.ambientPalette,
          parameters: const {
            'palette': <String>[workColor, ready, restColor],
            'brightnessMin': 0.4,
            'brightnessMax': 0.8,
            'speed': 0.2,
          },
        ),
      ],
    );
  }

  /// The workout of an interval training effect, or null for any other.
  static IntervalWorkout? of(LightingEffect effect) {
    if (!effect.id.startsWith(_prefix)) {
      return null;
    }
    final parts = [
      for (final p in effect.id.substring(_prefix.length).split(':'))
        int.tryParse(p),
    ];
    if (parts.length != 3 || parts.contains(null)) {
      return null;
    }
    final [rounds!, work!, rest!] = parts;
    if (rounds < 1 || rounds > 30 || work < 5 || rest < 5) {
      return null;
    }
    return IntervalWorkout(
      work: Duration(seconds: work),
      rest: Duration(seconds: rest),
      rounds: rounds,
    );
  }
}
