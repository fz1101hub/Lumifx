import 'dart:math' as math;

import '../../core/effects/effect.dart';
import '../../core/effects/effect_event.dart';
import '../common/app_text.dart';

/// One part of a breath.
enum BreathPhase { breatheIn, holdIn, breatheOut, holdOut }

/// A way of breathing slowly, in whole seconds per phase.
enum BreathingPattern {
  /// For children: smell the flower (in for 4), blow out the candle (out
  /// for 6).
  flowerCandle([(BreathPhase.breatheIn, 4), (BreathPhase.breatheOut, 6)]),

  /// In, hold, out, hold: four seconds each.
  box([
    (BreathPhase.breatheIn, 4),
    (BreathPhase.holdIn, 4),
    (BreathPhase.breatheOut, 4),
    (BreathPhase.holdOut, 4),
  ]),

  /// In for 4, hold for 7, out for 8: to fall asleep.
  relax478([
    (BreathPhase.breatheIn, 4),
    (BreathPhase.holdIn, 7),
    (BreathPhase.breatheOut, 8),
  ]);

  const BreathingPattern(this.phases);

  final List<(BreathPhase, int)> phases;

  static const minutesChoices = [1, 3, 5, 10];
  static const _prefix = '${LightingEffect.generatedPrefix}breathe:';

  /// Light low and high, and the colours of a full and an empty breath.
  static const low = 0.12;
  static const high = 0.85;
  static const fullColor = '#8FD8FF';
  static const emptyColor = '#B9A6FF';

  /// Seconds in one breath.
  int get cycleSeconds => phases.fold(0, (sum, p) => sum + p.$2);

  /// Breaths in [minutes], rounded up.
  int cyclesIn(int minutes) => (minutes * 60 / cycleSeconds).ceil();

  /// The breathing pattern and minutes of a breathing effect, or null for
  /// any other effect.
  static (BreathingPattern, int)? of(LightingEffect effect) {
    if (!effect.id.startsWith(_prefix)) {
      return null;
    }
    final [name, minutes, ...] = [
      ...effect.id.substring(_prefix.length).split(':'),
      '',
      '',
    ];
    final pattern = BreathingPattern.values.asNameMap()[name];
    final count = int.tryParse(minutes);
    return pattern == null || count == null || count < 1 || count > 60
        ? null
        : (pattern, count);
  }

  /// The lights breathing for [minutes]: up while breathing in, still
  /// while holding, down while breathing out. Plays once.
  LightingEffect effect({required int minutes, required String name}) {
    final events = <EffectEvent>[];
    var at = 0;
    for (var cycle = 0; cycle < cyclesIn(minutes); cycle++) {
      for (final (phase, seconds) in phases) {
        final (from, to, color, toColor) = switch (phase) {
          BreathPhase.breatheIn => (low, high, emptyColor, fullColor),
          BreathPhase.holdIn => (high, high, fullColor, fullColor),
          BreathPhase.breatheOut => (high, low, fullColor, emptyColor),
          BreathPhase.holdOut => (low, low, emptyColor, emptyColor),
        };
        events.add(EffectEvent(
          at: Duration(seconds: at),
          duration: Duration(seconds: seconds),
          type: EffectEventTypes.ramp,
          parameters: {
            'from': from,
            'to': to,
            'color': color,
            'toColor': toColor,
          },
        ));
        at += seconds;
      }
    }
    return LightingEffect(
      id: '$_prefix${this.name}:$minutes',
      name: name,
      kind: EffectKind.interactive,
      isLooping: false,
      loopDuration: Duration(seconds: at),
      events: events,
    );
  }

  /// Where in a breath [position] falls: the phase, how far through it
  /// (0..1), and how full the breath is (0 empty, 1 full).
  (BreathPhase, double, double) at(Duration position) {
    final cycle = cycleSeconds * 1000;
    var ms = position.inMilliseconds % cycle;
    for (final (phase, seconds) in phases) {
      final length = seconds * 1000;
      if (ms < length) {
        final t = ms / length;
        final eased = t * t * (3 - 2 * t);
        final fullness = switch (phase) {
          BreathPhase.breatheIn => eased,
          BreathPhase.holdIn => 1.0,
          BreathPhase.breatheOut => 1 - eased,
          BreathPhase.holdOut => 0.0,
        };
        return (phase, t, fullness);
      }
      ms -= length;
    }
    return (phases.last.$1, 1, 0);
  }

  /// What to do in [phase], in words.
  String callOf(BreathPhase phase, AppLocalizations l10n) =>
      switch ((this, phase)) {
        (BreathingPattern.flowerCandle, BreathPhase.breatheIn) =>
          l10n.breatheSmell,
        (BreathingPattern.flowerCandle, _) => l10n.breatheBlow,
        (_, BreathPhase.breatheIn) => l10n.breatheIn,
        (_, BreathPhase.breatheOut) => l10n.breatheOut,
        _ => l10n.breatheHold,
      };

  /// The calls of every phase for [minutes], read along and read aloud.
  List<(int, String)> narration(int minutes, AppLocalizations l10n) {
    final lines = <(int, String)>[];
    var at = 0;
    for (var cycle = 0; cycle < cyclesIn(minutes); cycle++) {
      for (final (phase, seconds) in phases) {
        lines.add((at, callOf(phase, l10n)));
        at += seconds;
      }
    }
    return lines;
  }

  /// Seconds of [minutes] of this pattern, as played.
  int lengthSeconds(int minutes) =>
      math.max(1, cyclesIn(minutes)) * cycleSeconds;
}
