import 'package:flutter_test/flutter_test.dart';
import 'package:lumifx/src/core/effects/engine/effect_renderer.dart';
import 'package:lumifx/src/features/bedtime/moon.dart';

void main() {
  test('the phase follows the real moon', () {
    expect(Moon.phaseOf(DateTime.utc(2026, 10, 26, 4, 12)), MoonPhase.full);
    expect(Moon.phaseOf(DateTime.utc(2026, 11, 9, 7)), MoonPhase.newMoon);
    expect(
        Moon.phaseOf(DateTime.utc(2026, 11, 17, 12)), MoonPhase.firstQuarter);
    expect(Moon.phaseOf(DateTime.utc(2026, 11, 1, 20)), MoonPhase.lastQuarter);
    expect(Moon.litOf(DateTime.utc(2026, 10, 26, 4, 12)), greaterThan(0.99));
    expect(Moon.litOf(DateTime.utc(2026, 11, 9, 7)), lessThan(0.01));
    expect(Moon.daysToFull(DateTime.utc(2026, 11, 17, 12)), 7);
    expect(Moon.daysToFull(DateTime.utc(2026, 10, 26, 4)), 0);
  });

  test('the lamps show the lit part on the side it is lit from', () {
    // First quarter: lit on the right, so the last lamps are bright.
    final waxing = EffectRenderer(
            Moon.effect('Moon', DateTime.utc(2026, 11, 17, 12)),
            slotCount: 4,
            seed: 1)
        .render(const Duration(minutes: 1));
    expect(waxing.last.brightness, greaterThan(waxing.first.brightness * 2));
    // Last quarter: lit on the left.
    final waning = EffectRenderer(
            Moon.effect('Moon', DateTime.utc(2026, 11, 1, 20)),
            slotCount: 4,
            seed: 1)
        .render(const Duration(minutes: 1));
    expect(waning.first.brightness, greaterThan(waning.last.brightness * 2));
    final effect = Moon.effect('Moon', DateTime.utc(2026, 11, 1, 20));
    expect(effect.hasRapidFlashes, isFalse);
    expect(Moon.of(effect), MoonPhase.lastQuarter);
  });
}
