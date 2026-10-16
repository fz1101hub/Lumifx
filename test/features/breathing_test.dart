import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumifx/l10n/generated/app_localizations.dart';
import 'package:lumifx/src/core/color/light_color.dart';
import 'package:lumifx/src/core/effects/engine/effect_renderer.dart';
import 'package:lumifx/src/features/calm/breathing.dart';
import 'package:lumifx/src/features/effects/read_along.dart';
import 'package:lumifx/src/features/library/effect_library.dart';
import 'package:lumifx/src/features/library/preferences_controller.dart';

void main() {
  final english = lookupAppLocalizations(const Locale('en'));

  test('breaths of whole seconds; enough of them to fill the minutes', () {
    expect(BreathingPattern.flowerCandle.cycleSeconds, 10);
    expect(BreathingPattern.box.cycleSeconds, 16);
    expect(BreathingPattern.relax478.cycleSeconds, 19);
    expect(BreathingPattern.box.cyclesIn(1), 4);
    expect(BreathingPattern.relax478.lengthSeconds(3), 10 * 19);
  });

  test('the lights rise breathing in, stay, and fall breathing out', () {
    final effect =
        BreathingPattern.box.effect(minutes: 1, name: 'Square breathing');
    expect(effect.isGenerated, isTrue);
    expect(effect.isLooping, isFalse);
    expect(effect.hasRapidFlashes, isFalse);
    expect(effect.cycleLength, const Duration(seconds: 64));
    final renderer = EffectRenderer(effect, slotCount: 3, seed: 1);
    double at(int ms) =>
        renderer.render(Duration(milliseconds: ms))[0].brightness;
    expect(at(0), closeTo(BreathingPattern.low, 0.01));
    expect(at(2000),
        closeTo((BreathingPattern.low + BreathingPattern.high) / 2, 0.01));
    expect(at(3999), closeTo(BreathingPattern.high, 0.01));
    expect(at(6000), closeTo(BreathingPattern.high, 0.001), reason: 'hold');
    expect(at(10000), lessThan(BreathingPattern.high));
    expect(at(14000), closeTo(BreathingPattern.low, 0.001), reason: 'hold');
    // Every light breathes together, from lavender to sky blue.
    final full = renderer.render(const Duration(seconds: 6));
    expect(full.map((f) => f.color).toSet(), hasLength(1));
    expect(full.first.color.toHex(),
        LightColor.fromHex(BreathingPattern.fullColor).toHex());
  });

  test('where in a breath: phase and how full', () {
    const pattern = BreathingPattern.flowerCandle;
    final (phase0, _, empty) = pattern.at(Duration.zero);
    expect(phase0, BreathPhase.breatheIn);
    expect(empty, 0);
    final (phase1, progress, full) = pattern.at(const Duration(seconds: 4));
    expect(phase1, BreathPhase.breatheOut);
    expect(progress, 0);
    expect(full, 1);
    final (phase2, _, _) = pattern.at(const Duration(seconds: 12));
    expect(phase2, BreathPhase.breatheIn, reason: 'the next breath');
  });

  test('the calls, for children and grown-ups, read along', () {
    final library =
        EffectLibrary(PreferencesController(store: InMemoryKeyValueStore()));
    final kids = BreathingPattern.flowerCandle
        .effect(minutes: 1, name: 'Flower and candle');
    final lines = narrationOf(kids, english, library);
    expect(lines.take(3).map((l) => l.$2),
        ['Smell the flower…', 'Blow out the candle…', 'Smell the flower…']);
    expect(lines.map((l) => l.$1).take(3), [0, 4, 10]);
    expect(lines, hasLength(12));

    final box = BreathingPattern.box.effect(minutes: 1, name: 'Square');
    expect(narrationOf(box, english, library).take(4).map((l) => l.$2),
        ['Breathe in…', 'Hold…', 'Breathe out…', 'Hold…']);
    expect(BreathingPattern.of(box), (BreathingPattern.box, 1));
  });
}
