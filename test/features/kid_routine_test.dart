import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumifx/l10n/generated/app_localizations.dart';
import 'package:lumifx/src/core/color/light_color.dart';
import 'package:lumifx/src/core/effects/engine/effect_renderer.dart';
import 'package:lumifx/src/features/library/preferences_controller.dart';
import 'package:lumifx/src/features/routines/kid_routine.dart';
import 'package:lumifx/src/features/routines/routines_screen.dart';

void main() {
  test('the lamps fill up one after the other with the steps done', () {
    final effect = KidRoutine.morning.progressEffect(3, 6, 'Morning');
    final frames =
        EffectRenderer(effect, slotCount: 4, seed: 1).render(Duration.zero);
    final to = LightColor.fromHex('#FFD36B');
    final from = LightColor.fromHex('#2E3F8F');
    // Half way across four lamps: two lit, two dim.
    expect(frames[0].color.toHex(), to.toHex());
    expect(frames[1].color.toHex(), to.toHex());
    expect(frames[2].color.toHex(), from.toHex());
    expect(frames[0].brightness, greaterThan(frames[3].brightness));
    final none = EffectRenderer(KidRoutine.morning.progressEffect(0, 6, 'M'),
            slotCount: 2, seed: 1)
        .render(Duration.zero);
    expect(none.map((f) => f.color.toHex()), everyElement(from.toHex()));
    expect(effect.isGenerated, isTrue);
    expect(KidRoutine.of(effect), KidRoutine.morning);
  });

  test('all done: a party that plays once', () {
    final done = KidRoutine.evening.doneEffect('Evening');
    expect(done.isLooping, isFalse);
    expect(done.hasRapidFlashes, isFalse);
    expect(KidRoutine.of(done), KidRoutine.evening);
  });

  test('a grown-up chooses the steps; one star per routine a day', () async {
    final store = InMemoryKeyValueStore();
    final preferences = PreferencesController(store: store);
    expect(
        stepsOf(preferences, KidRoutine.morning), KidRoutine.morning.allSteps);
    await preferences.setRoutineSteps('morning', ['getUp', 'brushTeeth']);
    expect(stepsOf(preferences, KidRoutine.morning),
        [RoutineStep.getUp, RoutineStep.brushTeeth]);

    final today = DateTime(2026, 10, 18, 8);
    final key = routineDayKey(KidRoutine.morning, today);
    expect(key, '2026-10-18:morning');
    expect(preferences.earnStar(key), isTrue);
    expect(preferences.earnStar(key), isFalse, reason: 'once a day');
    expect(
        preferences.earnStar(routineDayKey(KidRoutine.evening, today)), isTrue);
    await Future<void>.delayed(Duration.zero);
    final again = PreferencesController(store: store);
    await again.load();
    expect(again.stars, hasLength(2));
    expect(again.routineSteps('morning'), ['getUp', 'brushTeeth']);
  });

  test('a grown-up makes steps of their own, kept per routine', () async {
    final store = InMemoryKeyValueStore();
    final preferences = PreferencesController(store: store);
    final cat =
        (await preferences.addCustomStep('  Feed the cat ', 0, '#FFB347'))!;
    expect(cat.name, 'Feed the cat');
    expect(await preferences.addCustomStep('   ', 0, '#FFB347'), isNull);
    expect(
        stepsOf(preferences, KidRoutine.evening), KidRoutine.evening.allSteps,
        reason: 'not kept until ticked');
    await preferences.setRoutineSteps('evening', ['bath', cat.key]);
    expect(stepsOf(preferences, KidRoutine.evening), [RoutineStep.bath, cat]);

    final again = PreferencesController(store: store);
    await again.load();
    expect(again.customSteps.single.name, 'Feed the cat');
    expect(
        stepsOf(again, KidRoutine.evening)
            .last
            .label(lookupAppLocalizations(const Locale('en'))),
        'Feed the cat');
    await again.removeCustomStep(cat.id);
    expect(again.customSteps, isEmpty);
    expect(again.routineSteps('evening'), ['bath']);
  });
}
