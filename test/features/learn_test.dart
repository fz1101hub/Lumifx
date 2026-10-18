import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:lumifx/l10n/generated/app_localizations.dart';
import 'package:lumifx/src/features/learn/colour_words.dart';
import 'package:lumifx/src/features/learn/counting.dart';

void main() {
  test('the blinks stay in range and never repeat the same number', () {
    final game = CountingGame(math.Random(1));
    var last = 0;
    for (var i = 0; i < 200; i++) {
      game.next();
      expect(game.target, inInclusiveRange(1, game.max));
      expect(game.target, isNot(last));
      expect(game.colors, hasLength(game.target));
      last = game.target;
    }
  });

  test('the numbers grow with right answers in a row, up to nine', () {
    final game = CountingGame(math.Random(2));
    expect(game.max, CountingGame.firstMax);
    game.next();
    expect(game.answer(game.target), isTrue);
    game.next();
    expect(game.answer(game.target), isTrue);
    game.next();
    // A wrong answer starts the streak again.
    expect(game.answer(game.target + 1), isFalse);
    expect(game.score, 2);
    for (var i = 0; i < CountingGame.toGrow - 1; i++) {
      game.next();
      game.answer(game.target);
    }
    expect(game.max, CountingGame.firstMax);
    game.next();
    game.answer(game.target);
    expect(game.max, CountingGame.firstMax + 1);
    for (var i = 0; i < 100; i++) {
      game.next();
      game.answer(game.target);
    }
    expect(game.max, CountingGame.lastMax);
  });

  test('every language names every colour, each differently', () {
    expect(
      learnLanguages.keys.toSet(),
      {for (final l in AppLocalizations.supportedLocales) l.languageCode},
    );
    for (final code in learnLanguages.keys) {
      final words = [for (final c in LearnColour.values) c.word(code)];
      expect(words.toSet(), hasLength(LearnColour.values.length), reason: code);
    }
    expect(LearnColour.green.word('it'), 'verde');
    expect(LearnColour.green.word('xx'), 'green');
  });

  test('a colour survives its effect', () {
    for (final colour in LearnColour.values) {
      expect(LearnColour.of(colour.effect('Colours')), colour);
    }
    expect(LearnColour.of(CountingGame.background('Count')), isNull);
    expect(CountingGame.isCounting(CountingGame.background('Count')), isTrue);
  });

  test('the quiz offers four colours, the right one among them', () {
    final quiz = ColourQuiz(math.Random(4));
    LearnColour? last;
    for (var i = 0; i < 100; i++) {
      quiz.next();
      expect(quiz.choices.toSet(), hasLength(4));
      expect(quiz.choices, contains(quiz.target));
      expect(quiz.target, isNot(last));
      last = quiz.target;
    }
    expect(quiz.answer(quiz.target), isTrue);
    expect(
        quiz.answer(quiz.choices.firstWhere((c) => c != quiz.target)), isFalse);
    expect(quiz.score, 1);
  });
}
