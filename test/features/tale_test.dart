import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumifx/l10n/generated/app_localizations.dart';
import 'package:lumifx/src/core/effects/effect.dart';
import 'package:lumifx/src/core/effects/engine/effect_renderer.dart';
import 'package:lumifx/src/features/effects/read_along.dart';
import 'package:lumifx/src/features/library/effect_library.dart';
import 'package:lumifx/src/features/library/preferences_controller.dart';
import 'package:lumifx/src/features/tales/tale.dart';

void main() {
  final english = lookupAppLocalizations(const Locale('en'));

  test('a tale survives its effect id, whatever the name', () {
    for (final name in ['Pip', 'Anna Maria', 'Zoë: 1/2 %', 'ゆい']) {
      final tale = Tale(
        hero: TaleHero.owl,
        place: TalePlace.castle,
        quest: TaleQuest.treasure,
        name: name,
      );
      final back = Tale.of(tale.effect(english))!;
      expect(back.hero, TaleHero.owl);
      expect(back.place, TalePlace.castle);
      expect(back.quest, TaleQuest.treasure);
      expect(back.name, name);
    }
  });

  test('other effects are no tale', () {
    LightingEffect effect(String id) => LightingEffect(
          id: id,
          name: 'x',
          kind: EffectKind.story,
          loopDuration: const Duration(seconds: 10),
          events: const [],
        );
    expect(Tale.of(effect('ocean')), isNull);
    expect(Tale.of(effect('gen:tale:fox:sea')), isNull);
    expect(Tale.of(effect('gen:tale:cow:sea:star:Pip')), isNull);
    expect(Tale.of(effect('gen:tale:fox:sea:star:')), isNull);
    expect(Tale.of(effect('gen:tale:fox:sea:star:%E0%A4%A')), isNull);
  });

  test('every tale reads well in every language, with the name in it', () {
    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = lookupAppLocalizations(locale);
      for (final hero in TaleHero.values) {
        for (final place in TalePlace.values) {
          for (final quest in TaleQuest.values) {
            final tale =
                Tale(hero: hero, place: place, quest: quest, name: 'Nemo');
            final lines = tale.narration(l10n);
            expect(lines, hasLength(5));
            expect([for (final l in lines) l.$1],
                orderedEquals([0, 9, 19, 30, 42]));
            for (final (_, text) in lines) {
              expect(text, contains('Nemo'), reason: '$locale $text');
              expect(text, isNot(contains('{')), reason: '$locale $text');
            }
            expect(tale.title(l10n), contains('Nemo'));
          }
        }
      }
    }
  });

  test('the lights of every tale fit in the story and end in a dim glow', () {
    for (final hero in TaleHero.values) {
      for (final place in TalePlace.values) {
        for (final quest in TaleQuest.values) {
          final effect =
              Tale(hero: hero, place: place, quest: quest, name: 'Pip')
                  .effect(english);
          expect(effect.isLooping, isFalse);
          expect(effect.isGenerated, isTrue);
          expect(effect.hasRapidFlashes, isFalse);
          for (final event in effect.events) {
            expect(event.at + event.duration,
                lessThanOrEqualTo(effect.cycleLength),
                reason: '${quest.name} ${event.type} at ${event.at}');
          }
          final renderer = EffectRenderer(effect, slotCount: 4);
          final end = renderer.render(effect.cycleLength);
          for (final frame in end) {
            expect(frame.brightness, lessThan(0.15));
          }
        }
      }
    }
  });

  test('the words are read along and read aloud', () {
    final library =
        EffectLibrary(PreferencesController(store: InMemoryKeyValueStore()));
    const tale = Tale(
      hero: TaleHero.dragon,
      place: TalePlace.space,
      quest: TaleQuest.dark,
      name: 'Leo',
    );
    final lines = narrationOf(tale.effect(english), english, library);
    expect(
        lines.first.$2,
        'Once upon a time there was Leo, a baby dragon who sneezes green '
        'sparks instead of fire.');
    expect(lines.last.$2, endsWith('Goodnight, Leo.'));
  });

  test('a surprise keeps a chosen name, or gives the hero its own', () {
    final a = Tale.random(math.Random(3));
    final b = Tale.random(math.Random(3));
    expect(
        (a.hero, a.place, a.quest, a.name), (b.hero, b.place, b.quest, b.name));
    expect(a.name, a.hero.defaultName);
    expect(Tale.random(math.Random(3), name: 'Sofia').name, 'Sofia');
    final kinds = {
      for (var seed = 0; seed < 20; seed++)
        Tale.random(math.Random(seed)).effect(english).id,
    };
    expect(kinds.length, greaterThan(10));
  });

  test("a tale kept among the user's own stories keeps its words", () {
    const tale = Tale(
      hero: TaleHero.unicorn,
      place: TalePlace.sea,
      quest: TaleQuest.firefly,
      name: 'Ada',
    );
    final story = tale.toUserStory(english);
    expect(story.id, startsWith('story:'));
    expect(story.name, 'The story of Ada');
    expect(story.colors, TalePlace.sea.palette);
    expect(story.moments, hasLength(5));
    expect([for (final (_, words) in story.narration) words],
        [for (final (_, words) in tale.narration(english)) words]);
    expect(story.toEffect().cycleLength, const Duration(seconds: 60));
  });
}
