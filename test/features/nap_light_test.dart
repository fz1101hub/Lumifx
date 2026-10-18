import 'package:flutter_test/flutter_test.dart';
import 'package:lumifx/src/core/color/light_color.dart';
import 'package:lumifx/src/core/effects/engine/effect_renderer.dart';
import 'package:lumifx/src/features/bedtime/nap_light.dart';
import 'package:lumifx/src/features/learn/colour_words.dart';

void main() {
  test('a faint amber glow while resting, then green for a while', () {
    const rest = Duration(minutes: 45);
    final effect = NapLight.effect('Nap light', rest);
    expect(effect.isLooping, isFalse);
    expect(effect.hasRapidFlashes, isFalse);
    expect(effect.cycleLength, rest + NapLight.greenFor);
    final renderer = EffectRenderer(effect, slotCount: 3, seed: 1);

    for (final frame in renderer.render(const Duration(minutes: 20))) {
      expect(frame.brightness, lessThan(0.15));
      expect(frame.color.r, greaterThan(frame.color.g));
      expect(frame.color.g, greaterThan(frame.color.b));
    }
    // Turning slowly, not switching.
    final turning =
        renderer.render(rest + NapLight.turning ~/ 2).first.brightness;
    expect(turning, inExclusiveRange(0.15, 0.55));
    for (final frame in renderer.render(rest + const Duration(minutes: 5))) {
      expect(frame.color.toHex(), NapLight.green);
      expect(frame.brightness, greaterThan(0.5));
    }
  });

  test('the rest is read back from the effect, and only from a nap light', () {
    expect(NapLight.restOf(NapLight.effect('Nap', const Duration(minutes: 90))),
        const Duration(minutes: 90));
    expect(NapLight.restOf(LearnColour.green.effect('Green')), isNull);
    expect(LightColor.fromHex(NapLight.green).toHex(), NapLight.green);
  });
}
