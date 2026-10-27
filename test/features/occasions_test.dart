import 'package:flutter_test/flutter_test.dart';
import 'package:lumifx/src/core/effects/engine/effect_renderer.dart';
import 'package:lumifx/src/features/common/app_text.dart';
import 'package:lumifx/src/features/effects/catalog/builtin_scenes.dart';

void main() {
  final occasions = [
    candlelitDinner,
    gameNight,
    readingLight,
    aperitivo,
    guestsArriving,
  ];

  test('moods for occasions: named in every language, gentle', () {
    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = lookupAppLocalizations(locale);
      for (final effect in occasions) {
        expect(l10n.effectName(effect), isNotEmpty);
        expect(l10n.effectDescription(effect), isNotEmpty);
        expect(l10n.collectionName(effect), isNotNull);
      }
    }
    for (final effect in occasions) {
      expect(effect.hasRapidFlashes, isFalse);
      expect(builtinScenes, contains(effect));
    }
  });

  test('guests in 10 minutes brightens slowly, then stays', () {
    final renderer = EffectRenderer(guestsArriving, slotCount: 1, seed: 1);
    final start = renderer.render(const Duration(seconds: 10)).first;
    final middle = renderer.render(const Duration(minutes: 5)).first;
    final after = renderer.render(const Duration(minutes: 30)).first;
    expect(start.brightness, lessThan(0.2));
    expect(middle.brightness, inExclusiveRange(start.brightness, 0.8));
    expect(after.brightness, greaterThan(0.7));
  });

  test('candlelight is low and warm', () {
    final frame = EffectRenderer(candlelitDinner, slotCount: 1, seed: 1)
        .render(const Duration(seconds: 20))
        .first;
    expect(frame.brightness, lessThan(0.4));
    expect(frame.color.r, greaterThan(frame.color.b));
  });
}
