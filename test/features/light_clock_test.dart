import 'package:flutter_test/flutter_test.dart';
import 'package:lumifx/src/core/effects/engine/effect_renderer.dart';
import 'package:lumifx/src/features/timers/light_clock.dart';

void main() {
  final now = DateTime(2026, 10, 27, 7, 30);

  test('green, then yellow, then red, then a red glow at the time', () {
    final at = DateTime(2026, 10, 27, 7, 50);
    final effect = LightClock.effect('Leave',
        now: now, at: at, warnMinutes: 10, occasion: ClockOccasion.leave);
    expect(effect.isLooping, isFalse);
    expect(effect.hasRapidFlashes, isFalse);
    expect(effect.keepsRealTime, isTrue, reason: 'the speed set is ignored');
    expect(effect.cycleLength, const Duration(minutes: 20) + LightClock.after);
    final renderer = EffectRenderer(effect, slotCount: 2, seed: 1);
    String colourAt(Duration t) => renderer.render(t).first.color.toHex();

    expect(colourAt(const Duration(minutes: 5)), LightClock.green);
    expect(colourAt(const Duration(minutes: 13)), LightClock.yellow);
    expect(colourAt(const Duration(minutes: 19)), LightClock.red);
    final glow = renderer.render(const Duration(minutes: 21)).first;
    expect(glow.color.r, greaterThan(glow.color.g * 2));
  });

  test('a time sooner than the warning starts yellow', () {
    final effect = LightClock.effect('Meal',
        now: now, at: now.add(const Duration(minutes: 6)), warnMinutes: 10);
    final renderer = EffectRenderer(effect, slotCount: 1, seed: 1);
    expect(renderer.render(const Duration(minutes: 1)).first.color.toHex(),
        LightClock.yellow);
  });

  test('the phase follows the clock on the wall', () {
    final at = DateTime(2026, 10, 27, 8);
    ClockPhase phase(int minutesBefore) => LightClock.phaseAt(
        at.subtract(Duration(minutes: minutesBefore)), at, 10);
    expect(phase(30), ClockPhase.green);
    expect(phase(10), ClockPhase.yellow);
    expect(phase(2), ClockPhase.red);
    expect(phase(0), ClockPhase.now);
    expect(phase(-1), ClockPhase.now);
  });

  test('the time is today, or tomorrow when it has passed', () {
    expect(LightClock.nextAt(now, 7, 50), DateTime(2026, 10, 27, 7, 50));
    expect(LightClock.nextAt(now, 7, 0), DateTime(2026, 10, 28, 7, 0));
  });

  test('what it counts down to is read back from the effect', () {
    final at = DateTime(2026, 10, 27, 19, 30);
    final clock = LightClock.of(LightClock.effect('Bed',
        now: now, at: at, warnMinutes: 15, occasion: ClockOccasion.bed))!;
    expect(clock.occasion, ClockOccasion.bed);
    expect(clock.at, at);
    expect(clock.warnMinutes, 15);
  });
}
