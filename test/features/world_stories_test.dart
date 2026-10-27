import 'package:flutter_test/flutter_test.dart';
import 'package:lumifx/src/features/common/app_text.dart';
import 'package:lumifx/src/features/effects/catalog/builtin_world.dart';
import 'package:lumifx/src/features/effects/catalog/effect_catalog.dart';
import 'package:lumifx/src/features/effects/read_along.dart';
import 'package:lumifx/src/features/library/effect_library.dart';
import 'package:lumifx/src/features/library/preferences_controller.dart';

void main() {
  test('each place has its words, in time with its lights, in every language',
      () {
    final library =
        EffectLibrary(PreferencesController(store: InMemoryKeyValueStore()));
    for (final story in builtinWorld) {
      expect(effectById(story.id), story);
      expect(story.hasRapidFlashes, isFalse);
      for (final locale in AppLocalizations.supportedLocales) {
        final l10n = lookupAppLocalizations(locale);
        final lines = narrationOf(story, l10n, library);
        expect(lines, hasLength(4),
            reason: '${story.id} ${locale.languageCode}');
        expect(lines.last.$2, isNotEmpty);
        expect(l10n.collectionName(story), isNotNull);
        for (final (at, _) in lines) {
          expect(Duration(seconds: at), lessThan(story.cycleLength));
        }
      }
      // Every line after the first starts with something happening in
      // the lights at that very second.
      final lines = storyNarration[story.id]!;
      for (final (at, _) in lines.skip(1)) {
        expect(
            story.events.any((e) => e.at == Duration(seconds: at)) ||
                lines.last.$1 == at,
            isTrue,
            reason: '${story.id} at $at s');
      }
    }
  });
}
