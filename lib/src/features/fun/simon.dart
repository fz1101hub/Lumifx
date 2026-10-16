import 'dart:math' as math;

import '../../core/effects/effect.dart';
import '../../core/effects/effect_event.dart';

/// The four colours of the memory game.
enum SimonColor {
  red('#FF1A1A'),
  green('#00E04B'),
  blue('#1A5BFF'),
  yellow('#FFD000');

  const SimonColor(this.hex);

  final String hex;
}

/// What a press did.
enum SimonPress {
  /// Right, more to go.
  correct,

  /// Right, and the whole sequence is done.
  roundDone,

  /// Wrong: the game is over.
  wrong,
}

/// The memory game: the lights show a sequence of colours, one longer each
/// round, and the player repeats it.
class SimonGame {
  SimonGame([math.Random? random]) : _random = random ?? math.Random();

  final math.Random _random;
  final _sequence = <SimonColor>[];
  var _entered = 0;
  var _completed = 0;
  var _over = false;

  List<SimonColor> get sequence => List.unmodifiable(_sequence);

  /// The round being played, from 1.
  int get round => _sequence.length;

  /// Sequences repeated in full.
  int get score => _completed;

  bool get isOver => _over;

  /// One more colour at the end of the sequence.
  void nextRound() {
    _sequence.add(SimonColor.values[_random.nextInt(SimonColor.values.length)]);
    _entered = 0;
  }

  SimonPress press(SimonColor color) {
    if (_over || _entered >= _sequence.length) {
      return SimonPress.wrong;
    }
    if (_sequence[_entered] != color) {
      _over = true;
      return SimonPress.wrong;
    }
    _entered++;
    if (_entered < _sequence.length) {
      return SimonPress.correct;
    }
    _completed++;
    return SimonPress.roundDone;
  }

  /// How long each colour shows when the lights play the sequence: a
  /// little faster as it grows.
  Duration get showLength =>
      Duration(milliseconds: math.max(350, 800 - 35 * (round - 1)));

  /// The pause between two colours.
  Duration get gapLength =>
      Duration(milliseconds: showLength.inMilliseconds * 2 ~/ 5);

  /// The dim background the game's colours flash over.
  static LightingEffect background(String name) => LightingEffect(
        id: '${LightingEffect.generatedPrefix}simon',
        name: name,
        kind: EffectKind.interactive,
        loopDuration: const Duration(minutes: 1),
        events: const [
          EffectEvent(
            at: Duration.zero,
            duration: Duration(minutes: 1),
            type: EffectEventTypes.ambientPalette,
            parameters: {
              'palette': <String>['#2A2A48', '#3A3360'],
              'brightnessMin': 0.12,
              'brightnessMax': 0.2,
              'speed': 0.02,
            },
          ),
        ],
      );
}
