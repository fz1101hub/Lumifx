import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/color/light_color.dart';
import '../../core/effects/effect.dart';
import '../../core/effects/engine/light_frame.dart';
import '../common/app_text.dart';
import '../common/layout.dart';
import '../effects/light_color_ui.dart';
import '../effects/playback_controller.dart';
import 'light_games.dart';

/// A light game: its rules and a start button, then the lights' calls in
/// big letters on their colour, for those who look at the phone.
class GameScreen extends StatefulWidget {
  const GameScreen({required this.game, super.key});

  final LightGame game;

  static String titleOf(AppLocalizations l10n, LightGame game) =>
      switch (game) {
        LightGame.redLightGreenLight => l10n.gameRedLight,
        LightGame.statues => l10n.gameStatues,
        LightGame.colourHunt => l10n.gameColourHunt,
      };

  static String rulesOf(AppLocalizations l10n, LightGame game) =>
      switch (game) {
        LightGame.redLightGreenLight => l10n.gameRedLightRules,
        LightGame.statues => l10n.gameStatuesRules,
        LightGame.colourHunt => l10n.gameColourHuntRules,
      };

  static IconData iconOf(LightGame game) => switch (game) {
        LightGame.redLightGreenLight => Icons.traffic_outlined,
        LightGame.statues => Icons.accessibility_new,
        LightGame.colourHunt => Icons.search,
      };

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  GamePlan? _plan;
  LightingEffect? _effect;

  Future<void> _start() async {
    final l10n = context.l10n;
    final playback = AppScope.of(context).playback;
    final plan = GamePlan.random(widget.game);
    final effect = plan.effect(GameScreen.titleOf(l10n, widget.game));
    setState(() {
      _plan = plan;
      _effect = effect;
    });
    await playback.switchEffect(effect);
    if (playback.status == PlaybackStatus.idle) {
      await playback.start();
    } else if (playback.status == PlaybackStatus.paused) {
      await playback.resume();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final playback = AppScope.of(context).playback;
    return Scaffold(
      appBar: AppBar(title: Text(GameScreen.titleOf(l10n, widget.game))),
      body: ListenableBuilder(
        listenable: playback,
        builder: (context, _) {
          final plan = _plan;
          final effect = _effect;
          final player = playback.player;
          final running = plan != null &&
              effect != null &&
              playback.effect.id == effect.id &&
              player != null &&
              playback.status != PlaybackStatus.idle;
          if (!running) {
            return plan == null ? _intro(context) : _over(context);
          }
          return StreamBuilder<List<LightFrame>>(
            stream: player.frames,
            builder: (context, _) =>
                _playing(context, plan, playback, player.position),
          );
        },
      ),
    );
  }

  Widget _intro(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final preferences = AppScope.of(context).preferences;
    return ListView(
      padding: context.pageInsets(),
      children: [
        Icon(GameScreen.iconOf(widget.game),
            size: 72, color: theme.colorScheme.primary),
        const SizedBox(height: 16),
        Text(GameScreen.rulesOf(l10n, widget.game),
            style: theme.textTheme.bodyLarge),
        const SizedBox(height: 16),
        ListenableBuilder(
          listenable: preferences,
          builder: (context, _) => SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.record_voice_over_outlined),
            title: Text(l10n.gameSayCalls),
            value: preferences.readAloud,
            onChanged: preferences.setReadAloud,
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
          onPressed: _start,
          icon: const Icon(Icons.play_arrow),
          label: Text(l10n.timerStart),
        ),
      ],
    );
  }

  Widget _over(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.emoji_events_outlined,
                size: 72, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(l10n.gameOver,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall),
            const SizedBox(height: 24),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _start,
                  icon: const Icon(Icons.replay),
                  label: Text(l10n.gameAgain),
                ),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.close),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _playing(
    BuildContext context,
    GamePlan plan,
    PlaybackController playback,
    Duration position,
  ) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final phase = plan.phaseAt(position) ?? plan.phases.last;
    final color = LightColor.fromHex(plan.colorOf(phase)).toColor();
    final onColor =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
            ? Colors.white
            : Colors.black87;
    final left = phase.end - position.inMilliseconds / 1000;
    final done =
        (position.inMilliseconds / plan.length.inMilliseconds).clamp(0.0, 1.0);
    return Column(
      children: [
        Expanded(
          child: Container(
            width: double.infinity,
            color: color,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Semantics(
                  liveRegion: true,
                  child: Text(
                    plan.callOf(phase, l10n),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.displaySmall
                        ?.copyWith(color: onColor, fontWeight: FontWeight.w700),
                  ),
                ),
                if (phase.cue == GameCue.find) ...[
                  const SizedBox(height: 16),
                  Text(
                    '${left.ceil().clamp(0, GamePlan.huntSeconds)}',
                    style:
                        theme.textTheme.displayMedium?.copyWith(color: onColor),
                  ),
                ],
              ],
            ),
          ),
        ),
        LinearProgressIndicator(value: done),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: playback.toggle,
                  icon:
                      Icon(playback.isPlaying ? Icons.pause : Icons.play_arrow),
                  label: Text(playback.isPlaying ? l10n.pause : l10n.play),
                ),
                OutlinedButton.icon(
                  onPressed: playback.stop,
                  icon: const Icon(Icons.stop),
                  label: Text(l10n.stop),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
