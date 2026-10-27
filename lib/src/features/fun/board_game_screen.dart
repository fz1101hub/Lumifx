import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_scope.dart';
import '../../core/color/light_color.dart';
import '../../core/effects/engine/light_frame.dart';
import '../../core/speech/speaker.dart';
import '../common/app_text.dart';
import '../common/layout.dart';
import '../effects/light_color_ui.dart';
import '../effects/playback_controller.dart';
import 'board_game.dart';

/// The board game referee: how many players and how long a turn lasts,
/// then the room shows whose turn it is, a light die and the turn timer.
class BoardGameScreen extends StatefulWidget {
  const BoardGameScreen({this.random, super.key});

  /// Fixes the die (tests).
  final math.Random? random;

  @override
  State<BoardGameScreen> createState() => _BoardGameScreenState();
}

class _BoardGameScreenState extends State<BoardGameScreen> {
  late final _random = widget.random ?? math.Random();
  var _players = 2;
  var _seconds = 0;
  var _turn = 0;
  int? _rolled;
  var _timeUpSaid = false;
  var _rollGeneration = 0;

  String get _language => Localizations.localeOf(context).languageCode;

  String _playerName(int player) =>
      BoardGame.players[player % BoardGame.players.length].word(_language);

  static String _capitalised(String text) =>
      text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);

  void _say(String text) {
    final scope = AppScope.of(context);
    if (!scope.preferences.soundOn) {
      return;
    }
    final language = speechLanguage(_language);
    unawaited(() async {
      await scope.speaker.stop();
      await scope.speaker.speak(text, language);
    }());
  }

  Future<void> _play(int player) async {
    final l10n = context.l10n;
    final playback = AppScope.of(context).playback;
    _turn++;
    _rolled = null;
    _timeUpSaid = false;
    _rollGeneration++;
    _say(_capitalised(l10n.boardTurn(_playerName(player))));
    playback.setSleepTimer(null);
    await playback.switchEffect(BoardGame.turnEffect(l10n.boardGame,
        player: player, seconds: _seconds, turn: _turn));
    if (playback.status == PlaybackStatus.idle) {
      await playback.start();
    } else if (playback.status == PlaybackStatus.paused) {
      await playback.resume();
    }
  }

  /// The die: the lamps blink the number, one blink every 600 ms.
  Future<void> _roll() async {
    final playback = AppScope.of(context).playback;
    final number = _random.nextInt(6) + 1;
    final generation = ++_rollGeneration;
    unawaited(HapticFeedback.mediumImpact());
    setState(() => _rolled = number);
    _say('$number');
    for (var i = 0; i < number; i++) {
      if (!mounted || generation != _rollGeneration) {
        return;
      }
      playback.flash(LightColor.white,
          length: const Duration(milliseconds: 400));
      await Future<void>.delayed(const Duration(milliseconds: 600));
    }
  }

  @override
  void dispose() {
    _rollGeneration++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final playback = AppScope.of(context).playback;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.boardGame)),
      body: ListenableBuilder(
        listenable: playback,
        builder: (context, _) {
          final game = BoardGame.of(playback.effect);
          final player = playback.player;
          if (game != null &&
              player != null &&
              playback.status != PlaybackStatus.idle) {
            return StreamBuilder<List<LightFrame>>(
              stream: player.frames,
              builder: (context, _) => _running(context, game),
            );
          }
          return _setup(context);
        },
      ),
    );
  }

  Widget _setup(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return ListView(
      padding: context.pageInsets(),
      children: [
        Text(l10n.boardGameDescription, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 16),
        Text(l10n.boardPlayers, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (var n = 2; n <= BoardGame.players.length; n++)
              ChoiceChip(
                label: Text('$n'),
                selected: _players == n,
                onSelected: (_) => setState(() => _players = n),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          children: [
            for (var p = 0; p < _players; p++)
              Chip(
                avatar: CircleAvatar(
                    backgroundColor:
                        LightColor.fromHex(BoardGame.players[p].hex).toColor()),
                label: Text(_capitalised(_playerName(p))),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text(l10n.boardTimer, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final seconds in BoardGame.timerChoices)
              ChoiceChip(
                label: Text(seconds == 0
                    ? l10n.boardTimerOff
                    : l10n.boardTimerSeconds(seconds)),
                selected: _seconds == seconds,
                onSelected: (_) => setState(() => _seconds = seconds),
              ),
          ],
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
          onPressed: () => _play(0),
          icon: const Icon(Icons.casino_outlined),
          label: Text(l10n.boardStart),
        ),
      ],
    );
  }

  Widget _running(BuildContext context, ({int player, int seconds}) game) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final playback = AppScope.of(context).playback;
    final player = playback.player!;
    final colour = LightColor.fromHex(BoardGame.players[game.player].hex);
    final left = game.seconds == 0
        ? null
        : Duration(seconds: game.seconds) - player.position;
    final over = left != null && left <= Duration.zero;
    if (over && !_timeUpSaid) {
      _timeUpSaid = true;
      WidgetsBinding.instance
          .addPostFrameCallback((_) => mounted ? _say(l10n.boardTimeUp) : null);
    }
    return ListView(
      padding: context.pageInsets(),
      children: [
        const SizedBox(height: 16),
        Semantics(
          liveRegion: true,
          child: Text(
            _capitalised(l10n.boardTurn(_playerName(game.player))),
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium,
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: player.currentFrames.firstOrNull?.toDisplayColor() ??
                  colour.toColor(),
            ),
            alignment: Alignment.center,
            child: Text(
              over
                  ? l10n.boardTimeUp
                  : left != null
                      ? '${left.inSeconds + 1}'
                      : _rolled == null
                          ? ''
                          : '$_rolled',
              textAlign: TextAlign.center,
              style: theme.textTheme.displayMedium
                  ?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        if (left != null && _rolled != null) ...[
          const SizedBox(height: 8),
          Text('🎲 $_rolled',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall),
        ],
        const SizedBox(height: 24),
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(64)),
          onPressed: () => _play((game.player + 1) % _players),
          icon: const Icon(Icons.skip_next),
          label: Text(l10n.boardNext),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          style:
              OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(56)),
          onPressed: _roll,
          icon: const Icon(Icons.casino_outlined),
          label: Text(l10n.boardRoll),
        ),
        const SizedBox(height: 24),
        Center(
          child: TextButton.icon(
            onPressed: playback.stop,
            icon: const Icon(Icons.stop),
            label: Text(l10n.stop),
          ),
        ),
      ],
    );
  }
}
