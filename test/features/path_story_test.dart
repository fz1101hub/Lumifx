import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumifx/l10n/generated/app_localizations.dart';
import 'package:lumifx/src/core/effects/engine/effect_renderer.dart';
import 'package:lumifx/src/features/effects/read_along.dart';
import 'package:lumifx/src/features/library/effect_library.dart';
import 'package:lumifx/src/features/library/preferences_controller.dart';
import 'package:lumifx/src/features/paths/path_story.dart';

void main() {
  final english = lookupAppLocalizations(const Locale('en'));

  test('every turn leads somewhere, every part can be reached', () {
    for (final story in pathStories) {
      final reached = <String>{story.start.id};
      final queue = [story.start];
      while (queue.isNotEmpty) {
        final part = queue.removeLast();
        if (part.choices case (final a, final b)) {
          for (final choice in [a, b]) {
            final next = story.part(choice.next);
            if (reached.add(next.id)) {
              queue.add(next);
            }
          }
        }
      }
      expect(reached, {for (final p in story.parts) p.id}, reason: story.id);
      expect(story.parts.where((p) => p.isEnding), isNotEmpty);
      expect(
          {for (final p in story.parts) p.id}, hasLength(story.parts.length));
    }
  });

  test('words and lights fit inside each part', () {
    for (final story in pathStories) {
      for (final part in story.parts) {
        expect(part.lines.first.$1, 0, reason: '${story.id}/${part.id}');
        for (var i = 1; i < part.lines.length; i++) {
          expect(part.lines[i].$1, greaterThan(part.lines[i - 1].$1));
        }
        expect(part.lines.last.$1, lessThan(part.seconds));
        for (final event in part.events) {
          expect(event.end, lessThanOrEqualTo(Duration(seconds: part.seconds)),
              reason: '${story.id}/${part.id}');
        }
      }
    }
  });

  test('every line and choice in every language, none repeated', () {
    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = lookupAppLocalizations(locale);
      final seen = <String>{};
      for (final story in pathStories) {
        expect(story.title(l10n).trim(), isNotEmpty);
        for (final part in story.parts) {
          for (final (_, text) in part.lines) {
            expect(seen.add(text(l10n)), isTrue, reason: '$locale');
          }
          if (part.choices case (final a, final b)) {
            expect(a.label(l10n), isNot(b.label(l10n)));
          }
        }
      }
    }
  });

  test('a turn waits for the choice; an ending plays once', () {
    final library =
        EffectLibrary(PreferencesController(store: InMemoryKeyValueStore()));
    for (final story in pathStories) {
      for (final part in story.parts) {
        final effect = story.effectOf(part, english);
        expect(effect.isGenerated, isTrue);
        expect(effect.isLooping, isFalse);
        expect(effect.hasRapidFlashes, isFalse);
        expect(
          effect.cycleLength,
          Duration(seconds: part.seconds) +
              (part.isEnding ? PathStory.endingTail : PathStory.waitForChoice),
        );
        final (backStory, backPart) = PathStory.of(effect)!;
        expect(backStory.id, story.id);
        expect(backPart.id, part.id);
        expect(narrationOf(effect, english, library).map((l) => l.$2),
            [for (final (_, text) in part.lines) text(english)]);
        // While waiting, the last background goes on glowing.
        if (!part.isEnding) {
          final waiting = EffectRenderer(effect, slotCount: 2, seed: 1)
              .render(Duration(seconds: part.seconds + 120));
          expect(waiting.first.brightness, greaterThan(0));
        }
      }
    }
  });
}
