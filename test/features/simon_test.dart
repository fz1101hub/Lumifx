import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:lumifx/src/features/fun/simon.dart';
import 'package:lumifx/src/features/library/preferences_controller.dart';

void main() {
  test('one more colour each round; the same draw, the same colours', () {
    final game = SimonGame(math.Random(4));
    final twin = SimonGame(math.Random(4));
    for (var round = 1; round <= 6; round++) {
      game.nextRound();
      twin.nextRound();
      expect(game.round, round);
      expect(game.sequence, twin.sequence);
      expect(game.sequence.sublist(0, round - 1),
          twin.sequence.sublist(0, round - 1));
    }
  });

  test('repeat the sequence: right, right, done; a wrong one ends it', () {
    final game = SimonGame(math.Random(1))..nextRound();
    expect(game.press(game.sequence[0]), SimonPress.roundDone);
    expect(game.score, 1);
    game.nextRound();
    final [first, second] = game.sequence;
    expect(game.press(first), SimonPress.correct);
    expect(game.press(second), SimonPress.roundDone);
    expect(game.score, 2);

    game.nextRound();
    final wrong = SimonColor.values.firstWhere((c) => c != game.sequence[0]);
    expect(game.press(wrong), SimonPress.wrong);
    expect(game.isOver, isTrue);
    expect(game.score, 2, reason: 'two rounds were repeated in full');
    expect(game.press(game.sequence[0]), SimonPress.wrong,
        reason: 'over is over');
  });

  test('the lights go faster as the sequence grows, never too fast', () {
    final game = SimonGame(math.Random(2))..nextRound();
    final first = game.showLength;
    for (var i = 0; i < 30; i++) {
      game.nextRound();
    }
    expect(game.showLength, lessThan(first));
    expect(game.showLength, const Duration(milliseconds: 350));
    expect(game.gapLength, const Duration(milliseconds: 140));
  });

  test('the background is dim, plays on, and is made for one use', () {
    final effect = SimonGame.background('Light memory');
    expect(effect.isGenerated, isTrue);
    expect(effect.isLooping, isTrue);
    expect(effect.hasRapidFlashes, isFalse);
  });

  test('the best score is kept, only when beaten', () async {
    final store = InMemoryKeyValueStore();
    final preferences = PreferencesController(store: store);
    expect(preferences.recordSimonScore(0), isFalse);
    expect(preferences.recordSimonScore(5), isTrue);
    expect(preferences.recordSimonScore(3), isFalse);
    expect(preferences.simonBest, 5);
    await Future<void>.delayed(Duration.zero);
    final again = PreferencesController(store: store);
    await again.load();
    expect(again.simonBest, 5);
  });
}
