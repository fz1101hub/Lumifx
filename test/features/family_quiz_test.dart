import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumifx/src/core/effects/engine/effect_renderer.dart';
import 'package:lumifx/src/features/common/app_text.dart';
import 'package:lumifx/src/features/fun/family_quiz.dart';
import 'package:lumifx/src/features/fun/family_quiz_screen.dart';
import 'package:lumifx/src/features/learn/colour_words.dart';
import 'package:lumifx/src/features/learn/farm.dart';

void main() {
  test('each pack asks its own kinds of questions, varied', () {
    for (final pack in QuizPack.values) {
      final questions = FamilyQuiz.make(pack, math.Random(pack.index));
      expect(questions, hasLength(FamilyQuiz.questions));
      for (var i = 1; i < questions.length; i++) {
        expect(
            questions[i].runtimeType == questions[i - 1].runtimeType &&
                questions[i] is! SumQuestion,
            isFalse);
      }
      for (final q in questions) {
        switch ((pack, q)) {
          case (QuizPack.little, SumQuestion(:final answer)):
            expect(answer, inInclusiveRange(1, 5));
          case (QuizPack.family, SoundQuestion() || ColourQuestion()):
            fail('too easy for everyone');
          case (QuizPack.little, MixQuestion()):
            fail('too hard for the little ones');
          case (_, SumQuestion(:final answer)):
            expect(answer, greaterThanOrEqualTo(0));
          default:
        }
      }
    }
  });

  test('questions and answers read right in every language', () {
    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = lookupAppLocalizations(locale);
      final language = locale.languageCode;
      for (final q in [
        const SoundQuestion(FarmAnimal.cow),
        const ColourQuestion(LearnColour.blue),
        const SumQuestion(7, 5, SumOp.minus),
        const MixQuestion(
            LearnColour.red, LearnColour.yellow, LearnColour.orange),
      ]) {
        expect(FamilyQuizScreen.question(l10n, language, q), isNotEmpty);
        expect(FamilyQuizScreen.answer(l10n, language, q), isNotEmpty);
      }
    }
    final en = lookupAppLocalizations(const Locale('en'));
    expect(
        FamilyQuizScreen.question(
            en, 'en', const SumQuestion(3, 4, SumOp.times)),
        'How much is 3 times 4?');
    expect(
        FamilyQuizScreen.answer(en, 'en', const SumQuestion(3, 4, SumOp.times)),
        '12');
    expect(
        FamilyQuizScreen.answer(
            en,
            'en',
            const MixQuestion(
                LearnColour.blue, LearnColour.yellow, LearnColour.green)),
        'Green');
  });

  test('the winners burst in their colour, without rapid flashes', () {
    final effect = FamilyQuiz.winner('Quiz', LearnColour.blue);
    expect(FamilyQuiz.isQuiz(effect), isTrue);
    expect(effect.hasRapidFlashes, isFalse);
    expect(
        EffectRenderer(effect, slotCount: 1, seed: 1)
            .render(const Duration(seconds: 10))
            .first
            .brightness,
        greaterThan(0.5));
  });
}
