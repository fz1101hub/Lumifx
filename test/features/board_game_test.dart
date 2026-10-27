import 'package:flutter_test/flutter_test.dart';
import 'package:lumifx/src/core/effects/engine/effect_renderer.dart';
import 'package:lumifx/src/features/fun/board_game.dart';

void main() {
  test('the turn shows the player colour, the timer turns it red', () {
    final noTimer =
        BoardGame.turnEffect('Referee', player: 1, seconds: 0, turn: 1);
    expect(noTimer.isLooping, isTrue);
    expect(
        EffectRenderer(noTimer, slotCount: 1, seed: 1)
            .render(const Duration(seconds: 5))
            .first
            .color
            .toHex(),
        BoardGame.players[1].hex);

    final timed =
        BoardGame.turnEffect('Referee', player: 2, seconds: 30, turn: 2);
    expect(timed.isLooping, isFalse);
    expect(timed.hasRapidFlashes, isFalse);
    final end = EffectRenderer(timed, slotCount: 2, seed: 1)
        .render(const Duration(seconds: 40));
    expect(end.first.color.r, greaterThan(end.first.color.g * 2),
        reason: 'red once the time is up');
    expect(BoardGame.of(timed), (player: 2, seconds: 30));
    expect(BoardGame.turnEffect('R', player: 2, seconds: 30, turn: 3).id,
        isNot(timed.id),
        reason: 'each turn starts the clock again');
  });
}
