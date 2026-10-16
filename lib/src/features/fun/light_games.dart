import 'dart:math' as math;

import '../../core/effects/effect.dart';
import '../../core/effects/effect_event.dart';
import '../common/app_text.dart';

/// Games the lights lead: they say when to move, when to freeze, what to
/// look for.
enum LightGame { redLightGreenLight, statues, colourHunt }

/// What the lights ask for during one phase of a game.
enum GameCue {
  /// Green: move.
  go,

  /// Amber: red is coming.
  slowDown,

  /// Red: freeze.
  stop,

  /// Every colour: dance.
  dance,

  /// Icy blue: be a statue.
  freeze,

  /// One colour: find something of that colour.
  find,

  /// The hunt is over: did you find it?
  found,

  /// The end of the game.
  finish,
}

/// One phase of a game, in whole seconds from its start.
class GamePhase {
  const GamePhase(this.cue, this.at, this.seconds, {this.color});

  final GameCue cue;

  /// When it starts and how long it lasts, in seconds.
  final int at;
  final int seconds;

  /// The colour to find, for [GameCue.find] and [GameCue.found].
  final HuntColor? color;

  int get end => at + seconds;
}

/// The colours of the colour hunt.
enum HuntColor {
  red('#FF1A1A'),
  orange('#FF7A00'),
  yellow('#FFE000'),
  green('#00E04B'),
  blue('#1A5BFF'),
  purple('#9B30FF'),
  pink('#FF4FC3'),
  white('#FFF4E5');

  const HuntColor(this.hex);

  final String hex;

  String find(AppLocalizations l10n) => switch (this) {
        HuntColor.red => l10n.gameFindRed,
        HuntColor.orange => l10n.gameFindOrange,
        HuntColor.yellow => l10n.gameFindYellow,
        HuntColor.green => l10n.gameFindGreen,
        HuntColor.blue => l10n.gameFindBlue,
        HuntColor.purple => l10n.gameFindPurple,
        HuntColor.pink => l10n.gameFindPink,
        HuntColor.white => l10n.gameFindWhite,
      };
}

/// One game as it will play: its phases, drawn from [seed] so that the
/// same seed always plays the same game.
class GamePlan {
  GamePlan(this.game, this.seed) : phases = _phasesOf(game, seed);

  /// A new game with a fresh draw.
  factory GamePlan.random(LightGame game, [math.Random? random]) =>
      GamePlan(game, (random ?? math.Random()).nextInt(1 << 30));

  final LightGame game;
  final int seed;
  final List<GamePhase> phases;

  static const _prefix = '${LightingEffect.generatedPrefix}game:';

  /// About two minutes of play before the finish.
  static const playSeconds = 110;
  static const finishSeconds = 6;

  /// Seconds to find a colour, and to celebrate it after.
  static const huntSeconds = 12;
  static const foundSeconds = 3;
  static const huntRounds = 8;

  Duration get length => Duration(seconds: phases.last.end);

  /// The game of a game effect, or null for any other effect.
  static GamePlan? of(LightingEffect effect) {
    if (!effect.id.startsWith(_prefix)) {
      return null;
    }
    final [name, seed, ...] = [
      ...effect.id.substring(_prefix.length).split(':'),
      '',
      '',
    ];
    final game = LightGame.values.asNameMap()[name];
    final number = int.tryParse(seed);
    return game == null || number == null ? null : GamePlan(game, number);
  }

  /// The phase at [position] into the game; null once it is over.
  GamePhase? phaseAt(Duration position) {
    final second = position.inMilliseconds / 1000;
    for (final phase in phases) {
      if (second >= phase.at && second < phase.end) {
        return phase;
      }
    }
    return null;
  }

  /// What the lights ask for in [phase], in words.
  String callOf(GamePhase phase, AppLocalizations l10n) => switch (phase.cue) {
        GameCue.go => l10n.gameGo,
        GameCue.slowDown => l10n.gameSlowDown,
        GameCue.stop => l10n.gameStop,
        GameCue.dance => l10n.gameDance,
        GameCue.freeze => l10n.gameFreeze,
        GameCue.find => phase.color!.find(l10n),
        GameCue.found => l10n.gameTimeUp,
        GameCue.finish => l10n.gameOver,
      };

  /// The calls, said as each phase starts (read along and read aloud).
  List<(int, String)> narration(AppLocalizations l10n) =>
      [for (final phase in phases) (phase.at, callOf(phase, l10n))];

  /// The colour that stands for [phase] on screen.
  String colorOf(GamePhase phase) => switch (phase.cue) {
        GameCue.go => '#00E676',
        GameCue.slowDown => '#FFB300',
        GameCue.stop => '#FF1744',
        GameCue.dance => '#FF4FC3',
        GameCue.freeze => '#B3E5FC',
        GameCue.find || GameCue.found => phase.color!.hex,
        GameCue.finish => '#FFD740',
      };

  /// The game on the lights, played once.
  LightingEffect effect(String name) => LightingEffect(
        id: '$_prefix${game.name}:$seed',
        name: name,
        kind: EffectKind.interactive,
        isLooping: false,
        loopDuration: length,
        events: [for (final phase in phases) ..._eventsOf(phase)],
      );

  static List<GamePhase> _phasesOf(LightGame game, int seed) {
    final random = math.Random(seed);
    int between(int low, int high) => low + random.nextInt(high - low + 1);
    final phases = <GamePhase>[];
    var at = 0;
    void add(GameCue cue, int seconds, {HuntColor? color}) {
      phases.add(GamePhase(cue, at, seconds, color: color));
      at += seconds;
    }

    switch (game) {
      case LightGame.redLightGreenLight:
        while (at < playSeconds) {
          add(GameCue.go, between(3, 8));
          add(GameCue.slowDown, 1);
          add(GameCue.stop, between(2, 5));
        }
      case LightGame.statues:
        while (at < playSeconds) {
          add(GameCue.dance, between(6, 14));
          add(GameCue.freeze, between(3, 6));
        }
      case LightGame.colourHunt:
        final colors = [...HuntColor.values]..shuffle(random);
        for (final color in colors.take(huntRounds)) {
          add(GameCue.find, huntSeconds, color: color);
          add(GameCue.found, foundSeconds, color: color);
        }
    }
    add(GameCue.finish, finishSeconds);
    return phases;
  }

  List<EffectEvent> _eventsOf(GamePhase phase) {
    final at = Duration(seconds: phase.at);
    final length = Duration(seconds: phase.seconds);
    EffectEvent ambient(
      List<String> palette, {
      double low = 0.75,
      double high = 0.9,
      double speed = 0.02,
    }) =>
        EffectEvent(
          at: at,
          duration: length,
          type: EffectEventTypes.ambientPalette,
          parameters: {
            'palette': palette,
            'brightnessMin': low,
            'brightnessMax': high,
            'speed': speed,
          },
        );
    EffectEvent flash(String color, {int after = 0, int ms = 700}) =>
        EffectEvent(
          at: at + Duration(seconds: after),
          duration: Duration(milliseconds: ms),
          type: EffectEventTypes.magicFlash,
          parameters: {'color': color, 'target': 'all', 'brightness': 1.0},
        );
    const rainbow = ['#FF3B5C', '#FFD740', '#40C4FF', '#7CFF6B', '#C86BFF'];
    return switch (phase.cue) {
      GameCue.go => [
          ambient(const ['#00E676', '#00C853'])
        ],
      GameCue.slowDown => [
          ambient(const ['#FFB300', '#FFA000'])
        ],
      GameCue.stop => [
          ambient(const ['#FF1744', '#D50000'], low: 0.8, high: 0.95),
          flash('#FF1744'),
        ],
      GameCue.dance => [
          ambient(rainbow, low: 0.4, high: 0.95, speed: 0.3),
          EffectEvent(
            at: at,
            duration: length,
            type: EffectEventTypes.travel,
            parameters: const {
              'color': '#FFFFFF',
              'pattern': 'random_walk',
              'stepDuration': 400,
              'brightness': 0.9,
            },
          ),
        ],
      GameCue.freeze => [
          ambient(const ['#B3E5FC', '#E1F5FE'],
              low: 0.6, high: 0.65, speed: 0.005),
          flash('#FFFFFF', ms: 900),
        ],
      GameCue.find => [
          ambient([phase.color!.hex, phase.color!.hex], low: 0.85, high: 0.9),
          flash(phase.color!.hex, ms: 1200),
          // The lamps go out one by one as time runs out.
          EffectEvent(
            at: at + const Duration(seconds: 2),
            duration: length - const Duration(seconds: 2),
            type: EffectEventTypes.countdown,
            parameters: {
              'from': phase.color!.hex,
              'to': '#141414',
              'brightness': 0.85,
            },
          ),
        ],
      GameCue.found => [
          ambient([phase.color!.hex, '#FFFFFF'], low: 0.5, high: 0.9),
          EffectEvent(
            at: at,
            duration: length,
            type: EffectEventTypes.surprise,
            parameters: {'color': phase.color!.hex, 'count': 4},
          ),
        ],
      GameCue.finish => [
          ambient(rainbow, low: 0.4, high: 0.9, speed: 0.15),
          for (final (i, color)
              in const ['#FF4F7B', '#FFD740', '#40C4FF'].indexed)
            EffectEvent(
              at: at + Duration(seconds: i + 1),
              duration: const Duration(milliseconds: 1500),
              type: EffectEventTypes.surprise,
              parameters: {'color': color, 'count': 4},
            ),
          flash('#FFFFFF', after: 4, ms: 1500),
        ],
    };
  }
}
