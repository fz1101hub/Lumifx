import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumifx/l10n/generated/app_localizations.dart';
import 'package:lumifx/src/core/effects/effect.dart';
import 'package:lumifx/src/features/effects/catalog/effect_catalog.dart';
import 'package:lumifx/src/features/effects/read_along.dart';

void main() {
  final stories = effectsOfKind(EffectKind.story);
  LightingEffect story(String id) => stories.singleWhere((e) => e.id == id);

  test('every built-in story has words to read along', () {
    expect(stories, isNotEmpty);
    for (final effect in stories) {
      expect(hasNarration(effect), isTrue, reason: effect.id);
    }
    // And only stories: no table entry for an effect that does not exist.
    expect(storyNarration.keys.toSet(), {for (final e in stories) e.id});
  });

  test('lines start at the beginning, in order, inside the cycle', () {
    for (final effect in stories) {
      final lines = storyNarration[effect.id]!;
      expect(lines.first.$1, 0, reason: effect.id);
      for (var i = 1; i < lines.length; i++) {
        expect(lines[i].$1, greaterThan(lines[i - 1].$1), reason: effect.id);
      }
      expect(Duration(seconds: lines.last.$1), lessThan(effect.cycleLength),
          reason: effect.id);
    }
  });

  test('every line has its words in every language', () {
    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = lookupAppLocalizations(locale);
      final seen = <String>{};
      for (final lines in storyNarration.values) {
        for (final (_, text) in lines) {
          final words = text(l10n);
          expect(words.trim(), isNotEmpty, reason: '$locale');
          expect(seen.add(words), isTrue,
              reason: '$locale repeats the line "$words"');
        }
      }
    }
  });

  test('the line follows the story time and starts over with each loop', () {
    final trickster = story('emerald_trickster');
    expect(trickster.cycleLength, const Duration(seconds: 40));
    expect(narrationIndexAt(trickster, Duration.zero), 0);
    expect(narrationIndexAt(trickster, const Duration(seconds: 7)), 0);
    // The golden spark at 8 s arrives with the line about it.
    expect(narrationIndexAt(trickster, const Duration(seconds: 8)), 1);
    expect(narrationIndexAt(trickster, const Duration(seconds: 21)), 2);
    expect(narrationIndexAt(trickster, const Duration(seconds: 39)), 3);
    expect(narrationIndexAt(trickster, const Duration(seconds: 40)), 0);
    expect(narrationIndexAt(trickster, const Duration(seconds: 48)), 1);
  });

  test('effects without words and finished one-shot stories show nothing', () {
    final ocean = effectsOfKind(EffectKind.scene).first;
    expect(narrationIndexAt(ocean, Duration.zero), isNull);

    final looping = story('emerald_trickster');
    final once = LightingEffect(
      id: looping.id,
      name: looping.name,
      kind: looping.kind,
      events: looping.events,
      loopDuration: looping.loopDuration,
      isLooping: false,
    );
    expect(narrationIndexAt(once, const Duration(seconds: 30)), 3);
    expect(narrationIndexAt(once, const Duration(seconds: 41)), isNull);
  });

  test('locales resolve', () {
    expect(lookupAppLocalizations(const Locale('it')).readAlong,
        'Leggiamo insieme');
  });
}
