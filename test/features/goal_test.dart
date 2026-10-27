import 'package:flutter_test/flutter_test.dart';
import 'package:lumifx/src/core/effects/engine/effect_renderer.dart';
import 'package:lumifx/src/features/fun/goal.dart';
import 'package:lumifx/src/features/links/app_link.dart';

void main() {
  test('a burst in the team colours, then the colours a while, no strobe', () {
    final effect = Goal.effect('Goal!', GoalTeam.italy.colors);
    expect(effect.hasRapidFlashes, isFalse);
    expect(effect.isLooping, isFalse);
    expect(effect.cycleLength, Goal.lasts);
    expect(Goal.colorsOf(effect), ['#0066CC', '#FFFFFF']);
    final start = EffectRenderer(effect, slotCount: 3, seed: 1)
        .render(const Duration(milliseconds: 200));
    expect(start.every((f) => f.brightness > 0.8), isTrue,
        reason: 'the white flash');
    final later = EffectRenderer(effect, slotCount: 3, seed: 1)
        .render(const Duration(seconds: 30));
    for (final frame in later) {
      // Blue or white: never red or green.
      expect(frame.color.b, greaterThanOrEqualTo(frame.color.r - 0.01));
    }
  });

  test('a saved choice: a team, colours of your own, or Italy', () {
    expect(Goal.colorsOfChoice('brazil'), GoalTeam.brazil.colors);
    expect(Goal.colorsOfChoice('#7b2cbf,#ffffff'), ['#7B2CBF', '#FFFFFF']);
    expect(Goal.colorsOfChoice(null), GoalTeam.italy.colors);
    expect(Goal.colorsOfChoice('nonsense'), GoalTeam.italy.colors);
  });

  test('the goal link, with or without a team', () {
    expect(AppLink.parse('lumifx://app/goal'), isA<GoalLink>());
    expect(
        (AppLink.parse('lumifx://app/goal/Spain')! as GoalLink).team, 'spain');
    expect(AppLink.goal, 'lumifx://app/goal');
  });
}
