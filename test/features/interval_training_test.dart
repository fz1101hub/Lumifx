import 'package:flutter_test/flutter_test.dart';
import 'package:lumifx/src/core/effects/engine/effect_renderer.dart';
import 'package:lumifx/src/features/timers/interval_training.dart';

void main() {
  final workout = IntervalWorkout(
    work: const Duration(seconds: 40),
    rest: const Duration(seconds: 20),
    rounds: 3,
  );

  test('get ready, then work and rest in turn, no rest after the last', () {
    expect(workout.length,
        IntervalWorkout.getReady + const Duration(seconds: 40 * 3 + 20 * 2));
    expect(workout.at(const Duration(seconds: 5)).kind, IntervalKind.ready);
    final work = workout.at(const Duration(seconds: 15));
    expect((work.kind, work.round), (IntervalKind.work, 1));
    expect(work.left, const Duration(seconds: 35));
    final rest = workout.at(const Duration(seconds: 55));
    expect((rest.kind, rest.round), (IntervalKind.rest, 1));
    expect(workout.at(workout.length).kind, IntervalKind.done);
  });

  test('the lights: yellow, green, blue, slow pulses, never a strobe', () {
    final effect = workout.effect('HIIT');
    expect(effect.keepsRealTime, isTrue);
    expect(effect.hasRapidFlashes, isFalse);
    final renderer = EffectRenderer(effect, slotCount: 1, seed: 1);
    String colourAt(int seconds) =>
        renderer.render(Duration(seconds: seconds)).first.color.toHex();
    expect(colourAt(2), IntervalWorkout.ready);
    expect(colourAt(20), IntervalWorkout.workColor);
    expect(colourAt(55), IntervalWorkout.restColor);
    // Two seconds before the end of the first work: a white pulse.
    final pulse =
        renderer.render(const Duration(seconds: 48, milliseconds: 100)).first;
    expect(pulse.color.b, greaterThan(0.6));
  });

  test('the workout is read back from the effect', () {
    final back = IntervalWorkout.of(workout.effect('HIIT'))!;
    expect((back.work, back.rest, back.rounds),
        (workout.work, workout.rest, workout.rounds));
  });
}
