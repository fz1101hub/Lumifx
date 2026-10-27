import 'package:flutter_test/flutter_test.dart';
import 'package:lumifx/src/core/color/light_color.dart';
import 'package:lumifx/src/core/effects/engine/effect_renderer.dart';
import 'package:lumifx/src/features/calm/feelings.dart';

void main() {
  test('each feeling lights the room in its colour, gently', () {
    for (final feeling in Feeling.values) {
      final effect = feeling.effect('Name');
      expect(effect.hasRapidFlashes, isFalse, reason: feeling.name);
      expect(effect.isLooping, isFalse);
      expect(effect.cycleLength, Feeling.lasts);
      expect(Feeling.of(effect), feeling, reason: 'whatever the name');
    }
    final happy =
        EffectRenderer(Feeling.happy.effect('Happy'), slotCount: 1, seed: 1)
            .render(const Duration(minutes: 1))
            .first;
    expect(happy.color.toHex(), Feeling.happy.color);
    final tired =
        EffectRenderer(Feeling.tired.effect('Tired'), slotCount: 1, seed: 1)
            .render(const Duration(minutes: 1))
            .first;
    expect(tired.brightness, lessThan(0.35), reason: 'a dim light to rest');
  });

  test('anger starts red and cools down to a calm blue', () {
    final renderer =
        EffectRenderer(Feeling.angry.effect('Angry'), slotCount: 1, seed: 1);
    final start = renderer.render(const Duration(seconds: 1)).first.color;
    expect(start.r, greaterThan(start.b));
    final calm = renderer.render(const Duration(minutes: 3)).first.color;
    expect(calm.b, greaterThan(calm.r));
    expect(LightColor.fromHex(Feeling.calmColor).b, greaterThan(0.9));
    expect(Feeling.angry.help, FeelingHelp.breathe);
    expect(Feeling.sad.help, FeelingHelp.story);
  });
}
