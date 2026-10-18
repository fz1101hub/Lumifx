import 'package:flutter_test/flutter_test.dart';
import 'package:lumifx/src/core/effects/engine/effect_renderer.dart';
import 'package:lumifx/src/features/cinema/cinema.dart';

void main() {
  double brightnessAt(EffectRenderer renderer, Duration at) =>
      renderer.render(at).first.brightness;

  test('the film dims the lights slowly to a faint glow, or to dark', () {
    final glow = EffectRenderer(Cinema.film('Cinema', withGlow: true),
        slotCount: 3, seed: 1);
    expect(brightnessAt(glow, Duration.zero), closeTo(0.6, 0.01));
    final halfway = brightnessAt(glow, Cinema.dimFor ~/ 2);
    expect(halfway, inExclusiveRange(0.1, 0.55));
    expect(brightnessAt(glow, Cinema.dimFor + const Duration(minutes: 30)),
        closeTo(Cinema.glowLevel, 0.01));
    final dark = EffectRenderer(Cinema.film('Cinema', withGlow: false),
        slotCount: 3, seed: 1);
    expect(brightnessAt(dark, Cinema.dimFor + const Duration(minutes: 30)),
        lessThan(0.01));
  });

  test('the intermission rises, the end comes back and then lets go', () {
    final intermission =
        EffectRenderer(Cinema.intermission('Cinema'), slotCount: 2, seed: 1);
    expect(
        brightnessAt(intermission, Cinema.riseFor + const Duration(minutes: 5)),
        closeTo(0.5, 0.01));
    final end = Cinema.end('Cinema');
    expect(end.isLooping, isFalse);
    expect(end.cycleLength, lessThan(const Duration(minutes: 1)));
    expect(
        brightnessAt(EffectRenderer(end, slotCount: 2, seed: 1),
            Cinema.returnFor + const Duration(seconds: 1)),
        closeTo(0.7, 0.01));
  });

  test('every moment is known by its effect', () {
    expect(Cinema.phaseOf(Cinema.film('x', withGlow: false)), CinemaPhase.film);
    expect(Cinema.phaseOf(Cinema.film('x', withGlow: true)), CinemaPhase.film);
    expect(Cinema.phaseOf(Cinema.intermission('x')), CinemaPhase.intermission);
    expect(Cinema.phaseOf(Cinema.end('x')), CinemaPhase.end);
    for (final effect in [Cinema.film('x', withGlow: true), Cinema.end('x')]) {
      expect(effect.isGenerated, isTrue);
      expect(effect.hasRapidFlashes, isFalse);
    }
  });
}
