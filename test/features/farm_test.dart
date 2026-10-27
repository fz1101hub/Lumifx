import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:lumifx/src/core/effects/engine/effect_renderer.dart';
import 'package:lumifx/src/features/common/app_text.dart';
import 'package:lumifx/src/features/learn/farm.dart';
import 'package:lumifx/src/features/learn/farm_screen.dart';

void main() {
  test('each animal lights the room in its colour', () {
    for (final animal in FarmAnimal.values) {
      final effect = animal.effect(animal.name);
      expect(FarmAnimal.of(effect), animal);
      expect(effect.hasRapidFlashes, isFalse);
      expect(
          EffectRenderer(effect, slotCount: 1, seed: 1)
              .render(const Duration(seconds: 5))
              .first
              .color
              .toHex(),
          animal.color);
    }
  });

  test('the quiz: three animals, the one making the sound among them', () {
    final quiz = FarmQuiz(math.Random(3));
    FarmAnimal? last;
    for (var i = 0; i < 20; i++) {
      quiz.next();
      expect(quiz.choices, hasLength(3));
      expect(quiz.choices, contains(quiz.target));
      expect(quiz.choices.toSet(), hasLength(3));
      expect(quiz.target, isNot(last), reason: 'never twice in a row');
      last = quiz.target;
      expect(quiz.answer(quiz.target), isTrue);
    }
  });

  test('every animal has a name and a sound in every language', () {
    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = lookupAppLocalizations(locale);
      final sounds = {
        for (final a in FarmAnimal.values) FarmScreen.soundOf(l10n, a),
      };
      expect(sounds, hasLength(FarmAnimal.values.length),
          reason: locale.languageCode);
      for (final a in FarmAnimal.values) {
        expect(FarmScreen.nameOf(l10n, a), isNotEmpty);
      }
    }
  });
}
