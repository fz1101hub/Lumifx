import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumifx/l10n/generated/app_localizations.dart';
import 'package:lumifx/src/core/effects/effect_event.dart';
import 'package:lumifx/src/features/fun/hot_cold.dart';

void main() {
  final english = lookupAppLocalizations(const Locale('en'));

  test('from icy blue to fiery red, brighter as it gets hotter', () {
    final cold = HotCold.colorOf(0);
    final hot = HotCold.colorOf(HotCold.hottest);
    expect(cold.b, greaterThan(cold.r));
    expect(hot.r, greaterThan(hot.b));
    double brightness(int level) => HotCold.effect(level, 'x')
        .events
        .firstWhere((e) => e.type == EffectEventTypes.ambientPalette)
        .parameters['brightnessMax']! as double;
    expect(brightness(9), greaterThan(brightness(2)));
  });

  test('the words follow the heat', () {
    expect(HotCold.wordOf(english, 0), 'Freezing!');
    expect(HotCold.wordOf(english, HotCold.start), 'Cold');
    expect(HotCold.wordOf(english, 5), 'Warm');
    expect(HotCold.wordOf(english, 8), 'Hot!');
    expect(HotCold.wordOf(english, 10), 'Boiling!');
  });

  test('the game knows its effects, gentle ones', () {
    for (final effect in [HotCold.effect(4, 'x'), HotCold.found('x')]) {
      expect(HotCold.isHotCold(effect), isTrue);
      expect(effect.hasRapidFlashes, isFalse);
      expect(effect.isGenerated, isTrue);
    }
    expect(HotCold.found('x').isLooping, isFalse);
  });
}
