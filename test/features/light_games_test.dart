import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumifx/l10n/generated/app_localizations.dart';
import 'package:lumifx/src/core/color/light_color.dart';
import 'package:lumifx/src/core/effects/engine/effect_renderer.dart';
import 'package:lumifx/src/features/effects/read_along.dart';
import 'package:lumifx/src/features/fun/light_games.dart';
import 'package:lumifx/src/features/library/effect_library.dart';
import 'package:lumifx/src/features/library/preferences_controller.dart';

void main() {
  final english = lookupAppLocalizations(const Locale('en'));

  List<GameCue> cues(GamePlan plan) => [for (final p in plan.phases) p.cue];

  test('the same draw plays the same game; another draw another one', () {
    for (final game in LightGame.values) {
      final plan = GamePlan(game, 42);
      expect(cues(GamePlan(game, 42)), cues(plan));
      expect([for (final p in GamePlan(game, 42).phases) p.at],
          [for (final p in plan.phases) p.at]);
    }
    final draws = {
      for (var seed = 0; seed < 10; seed++)
        GamePlan(LightGame.redLightGreenLight, seed).phases.length +
            GamePlan(LightGame.redLightGreenLight, seed).phases[0].seconds *
                1000,
    };
    expect(draws.length, greaterThan(1));
  });

  test('phases follow one another, a couple of minutes, then the finish', () {
    for (final game in LightGame.values) {
      for (var seed = 0; seed < 20; seed++) {
        final plan = GamePlan(game, seed);
        expect(plan.phases.first.at, 0);
        for (var i = 1; i < plan.phases.length; i++) {
          expect(plan.phases[i].at, plan.phases[i - 1].end);
        }
        expect(plan.phases.last.cue, GameCue.finish);
        expect(plan.length, greaterThanOrEqualTo(const Duration(seconds: 110)));
        expect(plan.length, lessThan(const Duration(minutes: 3)));
      }
    }
  });

  test('red light, green light: go, careful, stop, again and again', () {
    for (var seed = 0; seed < 20; seed++) {
      final plan = GamePlan(LightGame.redLightGreenLight, seed);
      final play = plan.phases.sublist(0, plan.phases.length - 1);
      for (var i = 0; i < play.length; i++) {
        final phase = play[i];
        expect(phase.cue, [GameCue.go, GameCue.slowDown, GameCue.stop][i % 3]);
        switch (phase.cue) {
          case GameCue.go:
            expect(phase.seconds, inInclusiveRange(3, 8));
          case GameCue.slowDown:
            expect(phase.seconds, 1);
          default:
            expect(phase.seconds, inInclusiveRange(2, 5));
        }
      }
    }
  });

  test('statues: dance, then freeze', () {
    final plan = GamePlan(LightGame.statues, 7);
    final play = plan.phases.sublist(0, plan.phases.length - 1);
    for (final (i, phase) in play.indexed) {
      expect(phase.cue, i.isEven ? GameCue.dance : GameCue.freeze);
      expect(
          phase.seconds, inInclusiveRange(i.isEven ? 6 : 3, i.isEven ? 14 : 6));
    }
  });

  test('colour hunt: eight different colours, each found then cheered', () {
    final plan = GamePlan(LightGame.colourHunt, 3);
    final finds = plan.phases.where((p) => p.cue == GameCue.find).toList();
    expect(finds, hasLength(GamePlan.huntRounds));
    expect({for (final p in finds) p.color}, hasLength(GamePlan.huntRounds));
    for (var i = 0; i < GamePlan.huntRounds; i++) {
      expect(plan.phases[2 * i + 1].cue, GameCue.found);
      expect(plan.phases[2 * i + 1].color, plan.phases[2 * i].color);
    }
  });

  test('the game on the lights: once, made for one use, no rapid flashes', () {
    for (final game in LightGame.values) {
      final plan = GamePlan(game, 5);
      final effect = plan.effect('Game');
      expect(effect.isLooping, isFalse);
      expect(effect.isGenerated, isTrue);
      expect(effect.hasRapidFlashes, isFalse);
      expect(effect.cycleLength, plan.length);
      for (final event in effect.events) {
        expect(event.at + event.duration, lessThanOrEqualTo(plan.length));
      }
      final back = GamePlan.of(effect)!;
      expect(back.game, game);
      expect(cues(back), cues(plan));
    }
    expect(GamePlan.of(GamePlan(LightGame.statues, 1).effect('x')), isNotNull);
  });

  test('the lamps show the call: green to move, red to stop', () {
    final plan = GamePlan(LightGame.redLightGreenLight, 9);
    final renderer = EffectRenderer(plan.effect('Game'), slotCount: 3, seed: 1);
    final go = plan.phases.firstWhere((p) => p.cue == GameCue.go);
    final stop = plan.phases.firstWhere((p) => p.cue == GameCue.stop);
    for (final frame in renderer.render(Duration(seconds: go.at + 1))) {
      expect(frame.color.g, greaterThan(frame.color.r));
    }
    for (final frame
        in renderer.render(Duration(milliseconds: stop.at * 1000 + 1500))) {
      expect(frame.color.r, greaterThan(frame.color.g));
    }
  });

  test('the colour hunt lamps go out one by one', () {
    final plan = GamePlan(LightGame.colourHunt, 2);
    final find = plan.phases.first;
    final renderer = EffectRenderer(plan.effect('Hunt'), slotCount: 3, seed: 1);
    final color = LightColor.fromHex(find.color!.hex);
    final early = renderer.render(Duration(seconds: find.at + 3));
    expect(early.last.color.toHex(), color.toHex());
    final late = renderer.render(Duration(milliseconds: find.end * 1000 - 300));
    expect(late.first.color.toHex(), '#141414');
  });

  test('which phase now, and the calls to read along', () {
    final plan = GamePlan(LightGame.statues, 11);
    expect(plan.phaseAt(Duration.zero), plan.phases.first);
    final second = plan.phases[1];
    expect(plan.phaseAt(Duration(seconds: second.at)), second);
    expect(plan.phaseAt(plan.length), isNull);

    final library =
        EffectLibrary(PreferencesController(store: InMemoryKeyValueStore()));
    final lines = narrationOf(plan.effect('Statues'), english, library);
    expect(lines, hasLength(plan.phases.length));
    expect(lines.first.$2, 'Dance!');
    expect(lines[1].$2, 'Freeze like a statue!');
    expect(lines.last.$2, 'Game over! Well played!');

    final hunt = GamePlan(LightGame.colourHunt, 1);
    expect(
        hunt.callOf(hunt.phases.first, english), startsWith('Find something'));
  });

  test('every hunt colour has its call in every language', () {
    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = lookupAppLocalizations(locale);
      final calls = {for (final c in HuntColor.values) c.find(l10n)};
      expect(calls, hasLength(HuntColor.values.length), reason: '$locale');
    }
  });
}
