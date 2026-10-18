import 'package:flutter/material.dart';

import '../../core/effects/effect.dart';
import '../../core/effects/effect_event.dart';
import '../common/app_text.dart';

/// Something to do in a routine: a built-in step or one a grown-up made.
abstract interface class RoutineItem {
  /// How the routine's kept steps name it.
  String get key;
  IconData get icon;

  /// As `#RRGGBB`.
  String get color;
  String label(AppLocalizations l10n);
}

/// One thing to do in a routine, with its picture and colour.
enum RoutineStep implements RoutineItem {
  getUp(Icons.wb_sunny_outlined, '#FFD36B'),
  washFace(Icons.wash_outlined, '#7FD3FF'),
  getDressed(Icons.checkroom, '#FF8FAB'),
  breakfast(Icons.breakfast_dining_outlined, '#FFB347'),
  brushTeeth(Icons.clean_hands_outlined, '#3DDCFF'),
  shoesAndBag(Icons.backpack_outlined, '#7CFF6B'),
  bath(Icons.bathtub_outlined, '#8FD8FF'),
  pyjamas(Icons.bedroom_child_outlined, '#C3A6FF'),
  toilet(Icons.wc, '#B5E550'),
  tidyToys(Icons.toys_outlined, '#FF7A1A'),
  storyTime(Icons.menu_book_outlined, '#FFE29A');

  const RoutineStep(this.icon, this.color);

  @override
  final IconData icon;
  @override
  final String color;

  @override
  String get key => name;

  @override
  String label(AppLocalizations l10n) => switch (this) {
        getUp => l10n.stepGetUp,
        washFace => l10n.stepWashFace,
        getDressed => l10n.stepGetDressed,
        breakfast => l10n.stepBreakfast,
        brushTeeth => l10n.stepBrushTeeth,
        shoesAndBag => l10n.stepShoesAndBag,
        bath => l10n.stepBath,
        pyjamas => l10n.stepPyjamas,
        toilet => l10n.stepToilet,
        tidyToys => l10n.stepTidyToys,
        storyTime => l10n.stepStoryTime,
      };
}

/// A picture checklist for children: the lights fill up one lamp after
/// the other as the steps are done, and light up a party at the end.
enum KidRoutine {
  morning([
    RoutineStep.getUp,
    RoutineStep.washFace,
    RoutineStep.getDressed,
    RoutineStep.breakfast,
    RoutineStep.brushTeeth,
    RoutineStep.shoesAndBag,
  ]),
  evening([
    RoutineStep.bath,
    RoutineStep.pyjamas,
    RoutineStep.brushTeeth,
    RoutineStep.toilet,
    RoutineStep.tidyToys,
    RoutineStep.storyTime,
  ]);

  const KidRoutine(this.allSteps);

  /// Every step it can have, in order.
  final List<RoutineStep> allSteps;

  static const _prefix = '${LightingEffect.generatedPrefix}routine:';

  String title(AppLocalizations l10n) => switch (this) {
        morning => l10n.routineMorning,
        evening => l10n.routineEvening,
      };

  /// Morning sky colours, or a calm evening.
  (String, String) get _colors => switch (this) {
        morning => ('#2E3F8F', '#FFD36B'),
        evening => ('#1C1A5E', '#C3A6FF'),
      };

  /// [done] of [total] steps on the lights; plays until the next step.
  LightingEffect progressEffect(int done, int total, String name) {
    final (from, to) = _colors;
    return LightingEffect(
      id: '$_prefix${this.name}:$done:$total',
      name: name,
      kind: EffectKind.interactive,
      loopDuration: const Duration(minutes: 1),
      events: [
        EffectEvent(
          at: Duration.zero,
          duration: const Duration(minutes: 1),
          type: EffectEventTypes.progress,
          parameters: {
            'value': total == 0 ? 0.0 : done / total,
            'from': from,
            'to': to,
            'brightness': 0.85,
          },
        ),
      ],
    );
  }

  /// All done: a little party, then the lights go back; plays once.
  LightingEffect doneEffect(String name) => LightingEffect(
        id: '$_prefix${this.name}:done',
        name: name,
        kind: EffectKind.interactive,
        isLooping: false,
        loopDuration: const Duration(seconds: 8),
        events: [
          const EffectEvent(
            at: Duration.zero,
            duration: Duration(seconds: 8),
            type: EffectEventTypes.ambientPalette,
            parameters: {
              'palette': <String>['#FF3B5C', '#FFD740', '#40C4FF', '#7CFF6B'],
              'brightnessMin': 0.35,
              'brightnessMax': 0.8,
              'speed': 0.15,
            },
          ),
          for (final (i, color)
              in const ['#FF4F7B', '#FFD740', '#40C4FF'].indexed)
            EffectEvent(
              at: Duration(seconds: 1 + i),
              duration: const Duration(milliseconds: 1500),
              type: EffectEventTypes.surprise,
              parameters: {'color': color, 'count': 4},
            ),
          const EffectEvent(
            at: Duration(milliseconds: 4500),
            duration: Duration(milliseconds: 1500),
            type: EffectEventTypes.magicFlash,
            parameters: {
              'color': '#FFFFFF',
              'target': 'all',
              'brightness': 0.9
            },
          ),
        ],
      );

  /// The routine of a routine effect, or null for any other effect.
  static KidRoutine? of(LightingEffect effect) {
    if (!effect.id.startsWith(_prefix)) {
      return null;
    }
    final name = effect.id.substring(_prefix.length).split(':').first;
    return KidRoutine.values.asNameMap()[name];
  }
}

/// The key of [routine] on the day of [date], for the stars.
String routineDayKey(KidRoutine routine, DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}:${routine.name}';
