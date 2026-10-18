import 'dart:math' as math;

import '../../core/effects/effect.dart';
import '../../core/effects/effect_event.dart';
import 'colour_words.dart';

/// The paints a child can mix.
const mixingPaints = [
  LearnColour.red,
  LearnColour.yellow,
  LearnColour.blue,
  LearnColour.white,
];

/// What two paints make, mixed as on a palette, in the order the quiz asks
/// them.
const paintMixes = [
  (LearnColour.red, LearnColour.yellow, LearnColour.orange),
  (LearnColour.yellow, LearnColour.blue, LearnColour.green),
  (LearnColour.blue, LearnColour.red, LearnColour.purple),
  (LearnColour.red, LearnColour.white, LearnColour.pink),
];

/// What [a] and [b] make together, or null for two paints that make no
/// colour a child learns (or the same paint twice).
LearnColour? mixOf(LearnColour a, LearnColour b) {
  for (final (x, y, mix) in paintMixes) {
    if ((a == x && b == y) || (a == y && b == x)) {
      return mix;
    }
  }
  return null;
}

/// Two paints mixed on the lamps: they glow in both colours, go dark as
/// if stirred, then shine in the colour they make; over and over.
abstract final class ColourMix {
  static const _prefix = '${LightingEffect.generatedPrefix}mix:';

  static const _apart = Duration(seconds: 4);
  static const _stir = Duration(milliseconds: 2500);
  static const _cycle = Duration(seconds: 12);

  /// The effect mixing [a] and [b], which must make a colour.
  static LightingEffect effect(String name, LearnColour a, LearnColour b) {
    final mix = mixOf(a, b)!;
    return LightingEffect(
      id: '$_prefix${a.name}:${b.name}',
      name: name,
      kind: EffectKind.scene,
      loopDuration: _cycle,
      events: [
        EffectEvent(
          at: Duration.zero,
          duration: _apart,
          type: EffectEventTypes.ambientPalette,
          parameters: {
            'palette': [a.hex, b.hex],
            'brightnessMin': 0.7,
            'brightnessMax': 0.85,
            'speed': 0.03,
          },
        ),
        EffectEvent(
          at: _apart,
          duration: _cycle - _apart,
          type: EffectEventTypes.ambientPalette,
          parameters: {
            'palette': [mix.hex, mix.hex],
            'brightnessMin': 0.75,
            'brightnessMax': 0.85,
            'speed': 0.02,
          },
        ),
        EffectEvent(
          at: _apart,
          duration: _stir,
          type: EffectEventTypes.ramp,
          parameters: {
            'color': mix.hex,
            'from': 0.05,
            'to': 0.8,
          },
        ),
      ],
    );
  }

  /// The two paints an effect mixes, or null for any other effect.
  static (LearnColour, LearnColour)? of(LightingEffect effect) {
    if (!effect.id.startsWith(_prefix)) {
      return null;
    }
    final names = effect.id.substring(_prefix.length).split(':');
    if (names.length != 2) {
      return null;
    }
    final a = LearnColour.values.asNameMap()[names[0]];
    final b = LearnColour.values.asNameMap()[names[1]];
    return a != null && b != null && mixOf(a, b) != null ? (a, b) : null;
  }
}

/// What do these two paints make? Three colours to choose from.
class MixQuiz {
  MixQuiz([math.Random? random]) : _random = random ?? math.Random();

  final math.Random _random;

  /// Which of [paintMixes] is asked, and whether its paints are swapped.
  int? _index;
  var _swapped = false;
  var _choices = const <LearnColour>[];
  var _score = 0;

  /// The two paints mixed.
  (LearnColour, LearnColour) get paints {
    final (a, b, _) = paintMixes[_index!];
    return _swapped ? (b, a) : (a, b);
  }

  /// What they make.
  LearnColour get target => paintMixes[_index!].$3;
  List<LearnColour> get choices => _choices;
  int get score => _score;

  /// A new pair, never the same twice in a row, the paints in either
  /// order.
  void next() {
    final others = [
      for (var i = 0; i < paintMixes.length; i++)
        if (i != _index) i,
    ];
    _index = others[_random.nextInt(others.length)];
    _swapped = _random.nextBool();
    final wrong = [
      for (final (_, _, other) in paintMixes)
        if (other != target) other,
    ]..shuffle(_random);
    _choices = [target, ...wrong.take(2)]..shuffle(_random);
  }

  bool answer(LearnColour colour) {
    final right = colour == target;
    if (right) {
      _score++;
    }
    return right;
  }
}
