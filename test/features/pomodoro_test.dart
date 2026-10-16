import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumifx/l10n/generated/app_localizations.dart';
import 'package:lumifx/src/core/effects/engine/effect_renderer.dart';
import 'package:lumifx/src/features/effects/read_along.dart';
import 'package:lumifx/src/features/library/effect_library.dart';
import 'package:lumifx/src/features/library/preferences_controller.dart';
import 'package:lumifx/src/features/timers/light_timer.dart';
import 'package:lumifx/src/features/timers/pomodoro.dart';

void main() {
  final english = lookupAppLocalizations(const Locale('en'));

  test('focus, break, focus…: no break after the last round', () {
    final pomodoro = Pomodoro(rounds: 3);
    expect([for (final p in pomodoro.phases) p.$1],
        [false, true, false, true, false]);
    expect(pomodoro.length, const Duration(minutes: 3 * 25 + 2 * 5));
    expect(pomodoro.phaseAt(Duration.zero), 0);
    expect(pomodoro.phaseAt(const Duration(minutes: 26)), 1);
    expect(pomodoro.phaseAt(const Duration(minutes: 31)), 2);
    expect(pomodoro.roundOf(2), 2);
    expect(pomodoro.phaseAt(pomodoro.length), isNull);
  });

  test('the effect plays once, ends with a party, and comes back by id', () {
    final pomodoro = Pomodoro(
      rounds: 2,
      work: const Duration(minutes: 1),
      rest: const Duration(seconds: 30),
    );
    final effect = pomodoro.effect('Pomodoro');
    expect(effect.isGenerated, isTrue);
    expect(effect.isLooping, isFalse);
    expect(effect.hasRapidFlashes, isFalse);
    expect(effect.cycleLength, pomodoro.length + LightTimer.ending);
    final back = Pomodoro.of(effect)!;
    expect(back.rounds, 2);
    expect(back.work, const Duration(minutes: 1));
    expect(back.rest, const Duration(seconds: 30));

    final renderer = EffectRenderer(effect, slotCount: 2, seed: 1);
    // Focus starts warm white, a break is green.
    final focus = renderer.render(Duration.zero);
    expect(focus.last.color.toHex(), '#FFF4E5');
    final rest = renderer.render(const Duration(seconds: 80));
    for (final frame in rest) {
      expect(frame.color.g, greaterThan(frame.color.b));
    }
  });

  test('each phase is announced, and the end too', () {
    final library =
        EffectLibrary(PreferencesController(store: InMemoryKeyValueStore()));
    final effect = Pomodoro(rounds: 2).effect('Pomodoro');
    final lines = narrationOf(effect, english, library);
    expect(lines.map((l) => l.$2), [
      'Focus: round 1 of 2',
      'Break: stretch and drink some water',
      'Focus: round 2 of 2',
      'Well done, all rounds finished!',
    ]);
    expect(lines.map((l) => l.$1), [0, 1500, 1800, 3300]);
  });
}
