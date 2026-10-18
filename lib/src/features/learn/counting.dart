import 'dart:math' as math;

import '../../core/effects/effect.dart';
import '../../core/effects/effect_event.dart';

/// Count the lights: the lamps blink a few times and the child taps how
/// many. The numbers grow after a few right answers in a row.
class CountingGame {
  CountingGame([math.Random? random]) : _random = random ?? math.Random();

  final math.Random _random;

  /// The highest number at the start, and at most.
  static const firstMax = 3, lastMax = 9;

  /// Right answers in a row that make the numbers grow.
  static const toGrow = 3;

  /// How long each blink shows, and the dark between two: slow enough to
  /// count aloud.
  static const blink = Duration(milliseconds: 600);
  static const gap = Duration(milliseconds: 450);

  static const _id = '${LightingEffect.generatedPrefix}counting';

  var _max = firstMax;
  var _streak = 0;
  var _score = 0;
  var _target = 0;
  var _colors = const <String>[];

  /// The highest number now.
  int get max => _max;

  /// Right answers so far.
  int get score => _score;

  /// How many blinks this round.
  int get target => _target;

  /// The colour of each blink.
  List<String> get colors => _colors;

  /// A new number of blinks, never the same twice in a row.
  void next() {
    var count = 1 + _random.nextInt(_max);
    if (count == _target) {
      count = count % _max + 1;
    }
    _target = count;
    _colors = [
      for (var i = 0; i < count; i++)
        blinkColors[_random.nextInt(blinkColors.length)],
    ];
  }

  /// Whether [count] is right; a wrong one starts the streak again.
  bool answer(int count) {
    if (count != _target) {
      _streak = 0;
      return false;
    }
    _score++;
    if (++_streak >= toGrow && _max < lastMax) {
      _max++;
      _streak = 0;
    }
    return true;
  }

  /// A dim glow between the blinks.
  static LightingEffect background(String name) => LightingEffect(
        id: _id,
        name: name,
        kind: EffectKind.interactive,
        loopDuration: const Duration(minutes: 1),
        events: const [
          EffectEvent(
            at: Duration.zero,
            duration: Duration(minutes: 1),
            type: EffectEventTypes.ambientPalette,
            parameters: {
              'palette': <String>['#1E2140', '#2A2A48'],
              'brightnessMin': 0.08,
              'brightnessMax': 0.14,
              'speed': 0.02,
            },
          ),
        ],
      );

  static bool isCounting(LightingEffect effect) => effect.id == _id;
}

/// Bright, easy to tell apart.
const blinkColors = [
  '#FF3B30', '#FFD60A', '#34C759', '#0A84FF', '#FF6FB5', '#FF9500', //
];
