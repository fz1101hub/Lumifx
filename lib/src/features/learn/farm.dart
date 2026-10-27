import 'dart:math' as math;

import '../../core/effects/effect.dart';
import '../../core/effects/effect_event.dart';

/// The animals of the light farm, each with its colour; the voice says
/// its sound, in the app's language.
enum FarmAnimal {
  cow('#FFFFFF'),
  pig('#FF8FC7'),
  duck('#FFD60A'),
  frog('#2BD94F'),
  cat('#9B3BFF'),
  dog('#FF8C1A'),
  horse('#A0522D'),
  rooster('#FF2020');

  const FarmAnimal(this.color);

  final String color;

  static const _prefix = '${LightingEffect.generatedPrefix}farm:';

  /// The room in the animal's colour, with a little hop of light.
  LightingEffect effect(String name) => LightingEffect(
        id: '$_prefix${this.name}',
        name: name,
        kind: EffectKind.scene,
        loopDuration: const Duration(minutes: 1),
        events: [
          EffectEvent(
            at: Duration.zero,
            duration: const Duration(minutes: 1),
            type: EffectEventTypes.ambientPalette,
            parameters: {
              'palette': <String>[color, color],
              'brightnessMin': 0.6,
              'brightnessMax': 0.75,
              'speed': 0.03,
            },
          ),
          EffectEvent(
            at: Duration.zero,
            duration: const Duration(milliseconds: 1200),
            type: EffectEventTypes.travel,
            parameters: {'color': color, 'brightness': 1},
          ),
        ],
      );

  /// The animal shown by a farm effect, or null for any other effect.
  static FarmAnimal? of(LightingEffect effect) => effect.id.startsWith(_prefix)
      ? FarmAnimal.values.asNameMap()[effect.id.substring(_prefix.length)]
      : null;
}

/// "Who says this?": a sound, and three animals to choose from.
class FarmQuiz {
  FarmQuiz([math.Random? random]) : _random = random ?? math.Random();

  final math.Random _random;
  FarmAnimal? _target;
  List<FarmAnimal> _choices = const [];

  FarmAnimal get target => _target!;
  List<FarmAnimal> get choices => _choices;

  /// A new question, never the same animal twice in a row.
  void next() {
    final others = [
      for (final a in FarmAnimal.values)
        if (a != _target) a,
    ];
    _target = others[_random.nextInt(others.length)];
    final wrong = [
      for (final a in FarmAnimal.values)
        if (a != _target) a,
    ]..shuffle(_random);
    _choices = [_target!, ...wrong.take(2)]..shuffle(_random);
  }

  bool answer(FarmAnimal animal) => animal == _target;
}
