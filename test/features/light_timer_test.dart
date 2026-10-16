import 'package:flutter_test/flutter_test.dart';
import 'package:lumifx/src/core/color/light_color.dart';
import 'package:lumifx/src/core/effects/engine/effect_renderer.dart';
import 'package:lumifx/src/features/timers/light_timer.dart';

void main() {
  test('the lights turn from start to end colour one after the other', () {
    final effect = LightTimer.teeth.effect(name: 'Teeth');
    final from = LightColor.fromHex(LightTimer.teeth.from);
    final to = LightColor.fromHex(LightTimer.teeth.to);
    final renderer = EffectRenderer(effect, slotCount: 3, seed: 1);
    final start = renderer.render(Duration.zero);
    expect(start.map((f) => f.color), everyElement(from));
    // Half way: the first light has turned, the second is turning.
    final half = renderer.render(const Duration(minutes: 1));
    expect(half[0].color, to);
    expect(half[1].color, LightColor.lerp(from, to, 0.5));
    expect(half[2].color, from);
    final nearlyDone = renderer
        .render(const Duration(minutes: 2) - const Duration(seconds: 1));
    expect(nearlyDone[0].color, to);
    expect(nearlyDone[2].color, isNot(from));
    for (final frame in half) {
      expect(frame.brightness, inInclusiveRange(0.7, 0.9), reason: 'breathing');
    }

    // A single light fades the whole way.
    final one = EffectRenderer(effect, slotCount: 1, seed: 1)
        .render(const Duration(minutes: 1));
    expect(one.single.color, LightColor.lerp(from, to, 0.5));
  });

  test('timers play once, are made for one use and never flash', () {
    for (final timer in LightTimer.values) {
      final effect = timer.effect(
        name: timer.name,
        length: const Duration(minutes: 3),
      );
      expect(effect.isLooping, isFalse);
      expect(effect.isGenerated, isTrue);
      expect(
          effect.cycleLength, const Duration(minutes: 3) + LightTimer.ending);
      expect(effect.hasRapidFlashes, isFalse);
      // Every instant renders, the ending included.
      final renderer = EffectRenderer(effect, slotCount: 4, seed: 2);
      for (var s = 0; s < 190; s += 3) {
        for (final frame in renderer.render(Duration(seconds: s))) {
          expect(frame.brightness, inInclusiveRange(0, 1));
        }
      }
    }
  });
}
