import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:lumifx/l10n/generated/app_localizations.dart';
import 'package:lumifx/src/core/effects/engine/effect_renderer.dart';
import 'package:lumifx/src/features/learn/colour_mixing.dart';
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

  test('paints mix as on a palette, in either order', () {
    expect(mixOf(LearnColour.red, LearnColour.yellow), LearnColour.orange);
    expect(mixOf(LearnColour.blue, LearnColour.yellow), LearnColour.green);
    expect(mixOf(LearnColour.red, LearnColour.blue), LearnColour.purple);
    expect(mixOf(LearnColour.white, LearnColour.red), LearnColour.pink);
    expect(mixOf(LearnColour.red, LearnColour.red), isNull);
    expect(mixOf(LearnColour.yellow, LearnColour.white), isNull);
    for (final paint in mixingPaints) {
      expect(mixingPaints.where((other) => mixOf(paint, other) != null),
          isNotEmpty,
          reason: '$paint mixes with something');
    }
  });

  test('the lamps show both paints, then the colour they make', () {
    final effect =
        ColourMix.effect('Mixing', LearnColour.blue, LearnColour.yellow);
    expect(ColourMix.of(effect), (LearnColour.blue, LearnColour.yellow));
    expect(effect.isLooping, isTrue);
    expect(effect.hasRapidFlashes, isFalse);
    final renderer = EffectRenderer(effect, slotCount: 4, seed: 1);
    // The palette drifts: some lamps bluish, some yellowish.
    final apart = renderer.render(const Duration(seconds: 2));
    expect(apart.where((f) => f.color.b > f.color.r && f.color.b > f.color.g),
        isNotEmpty);
    expect(apart.where((f) => f.color.r > f.color.b && f.color.g > f.color.b),
        isNotEmpty);
    for (final frame in renderer.render(const Duration(seconds: 9))) {
      expect(frame.color.toHex(), LearnColour.green.hex);
      expect(frame.brightness, greaterThan(0.5));
    }
    // Stirred: dark for a moment as the colours meet.
    expect(renderer.render(const Duration(milliseconds: 4100)).first.brightness,
        lessThan(0.2));
  });

  test('other effects are not mixes', () {
    expect(ColourMix.of(LearnColour.red.effect('Red')), isNull);
  });

  test('the mixing quiz asks every mix, never twice in a row', () {
    final quiz = MixQuiz(math.Random(4));
    final asked = <LearnColour>{};
    LearnColour? last;
    for (var i = 0; i < 100; i++) {
      quiz.next();
      final (a, b) = quiz.paints;
      expect(mixOf(a, b), quiz.target);
      expect(quiz.target, isNot(last));
      expect(quiz.choices, hasLength(3));
      expect(quiz.choices.toSet(), hasLength(3));
      expect(quiz.choices, contains(quiz.target));
      asked.add(quiz.target);
      last = quiz.target;
    }
    expect(asked, hasLength(paintMixes.length));
    expect(quiz.answer(quiz.target), isTrue);
    expect(
        quiz.answer(quiz.choices.firstWhere((c) => c != quiz.target)), isFalse);
    expect(quiz.score, 1);
  });
}
