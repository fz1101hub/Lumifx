import '../../core/effects/effect.dart';
import '../../core/effects/effect_event.dart';
import '../learn/colour_words.dart';

/// A referee for board games: the room shows whose turn it is in their
/// colour; with a turn timer the colour slowly turns red as time runs out,
/// then breathes red.
abstract final class BoardGame {
  /// The players' colours, in turn order.
  static const players = [
    LearnColour.red,
    LearnColour.blue,
    LearnColour.green,
    LearnColour.yellow,
    LearnColour.purple,
    LearnColour.orange,
  ];

  /// Seconds per turn; 0 is no timer.
  static const timerChoices = [0, 30, 60, 120];

  /// After the time is up, red breathes this long.
  static const overtime = Duration(minutes: 10);

  static const timeUp = '#FF2020';

  static const _prefix = '${LightingEffect.generatedPrefix}board:';

  /// [player]'s turn (an index in [players]) with [seconds] on the clock
  /// (0: none); [turn] makes each turn its own effect, so the clock starts
  /// again.
  static LightingEffect turnEffect(
    String name, {
    required int player,
    required int seconds,
    required int turn,
  }) {
    final colour = players[player % players.length].hex;
    final time = Duration(seconds: seconds);
    return LightingEffect(
      id: '$_prefix$player:$seconds:$turn',
      name: name,
      kind: EffectKind.interactive,
      isLooping: seconds == 0,
      loopDuration: seconds == 0 ? const Duration(minutes: 1) : time + overtime,
      events: seconds == 0
          ? [
              EffectEvent(
                at: Duration.zero,
                duration: const Duration(minutes: 1),
                type: EffectEventTypes.ambientPalette,
                parameters: {
                  'palette': <String>[colour, colour],
                  'brightnessMin': 0.65,
                  'brightnessMax': 0.75,
                  'speed': 0.02,
                },
              ),
            ]
          : [
              EffectEvent(
                at: Duration.zero,
                duration: time,
                type: EffectEventTypes.countdown,
                parameters: {'from': colour, 'to': timeUp, 'brightness': 0.75},
              ),
              EffectEvent(
                at: time,
                duration: overtime,
                type: EffectEventTypes.ambientPalette,
                parameters: const {
                  'palette': <String>[timeUp, '#FF4A4A'],
                  'brightnessMin': 0.3,
                  'brightnessMax': 0.9,
                  'speed': 0.25,
                },
              ),
            ],
    );
  }

  /// Whose turn a referee effect shows, with its timer, or null.
  static ({int player, int seconds})? of(LightingEffect effect) {
    if (!effect.id.startsWith(_prefix)) {
      return null;
    }
    final parts = [
      for (final p in effect.id.substring(_prefix.length).split(':'))
        int.tryParse(p),
    ];
    if (parts.length != 3 || parts.contains(null)) {
      return null;
    }
    final [player!, seconds!, _] = parts;
    return player < 0 || player >= players.length || seconds < 0
        ? null
        : (player: player, seconds: seconds);
  }
}
