import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/effects/effect.dart';
import '../../core/effects/engine/light_frame.dart';
import '../common/app_text.dart';
import '../common/layout.dart';
import '../effects/light_color_ui.dart';
import '../effects/playback_controller.dart';
import 'pomodoro.dart';

/// A running pomodoro: focus or break, the time left of it over the
/// lights' colour, the round, pause and stop.
class PomodoroRunningScreen extends StatelessWidget {
  const PomodoroRunningScreen({
    required this.pomodoro,
    required this.effect,
    super.key,
  });

  final Pomodoro pomodoro;
  final LightingEffect effect;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final playback = AppScope.of(context).playback;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.pomodoro)),
      body: ListenableBuilder(
        listenable: playback,
        builder: (context, _) {
          final player = playback.player;
          final running = playback.effect.id == effect.id &&
              player != null &&
              playback.status != PlaybackStatus.idle;
          if (!running) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.emoji_events_outlined,
                      size: 64, color: theme.colorScheme.primary),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(l10n.pomodoroDone,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleLarge),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.close),
                  ),
                ],
              ),
            );
          }
          return StreamBuilder<List<LightFrame>>(
            stream: player.frames,
            builder: (context, _) {
              final position = player.position;
              final index = pomodoro.phaseAt(position);
              final speed = playback.controls.speed.clamp(0.05, 5.0);
              final String label;
              var seconds = 0;
              var done = 1.0;
              if (index == null) {
                label = l10n.timerDone;
              } else {
                final (isBreak, at, length) = pomodoro.phases[index];
                label = isBreak
                    ? l10n.pomodoroBreak
                    : l10n.pomodoroFocus(
                        pomodoro.roundOf(index), pomodoro.rounds);
                final left = at + length - position;
                seconds = (left.inMilliseconds / 1000 / speed).ceil();
                done = ((position - at).inMilliseconds / length.inMilliseconds)
                    .clamp(0.0, 1.0);
              }
              final frame = player.currentFrames.firstOrNull;
              return ListView(
                padding: context.pageInsets(),
                children: [
                  const SizedBox(height: 16),
                  Semantics(
                    liveRegion: true,
                    child: Text(label,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleLarge),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: SizedBox.square(
                      dimension: 220,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox.expand(
                            child: CircularProgressIndicator(
                              value: done,
                              strokeWidth: 10,
                              semanticsLabel: label,
                            ),
                          ),
                          Container(
                            width: 170,
                            height: 170,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: frame?.toDisplayColor() ?? Colors.black,
                            ),
                          ),
                          Text(
                            '${seconds ~/ 60}:'
                            '${(seconds % 60).toString().padLeft(2, '0')}',
                            style: theme.textTheme.displaySmall?.copyWith(
                              color: Colors.white,
                              shadows: const [
                                Shadow(blurRadius: 8, color: Colors.black54),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    children: [
                      FilledButton.icon(
                        onPressed: playback.toggle,
                        icon: Icon(playback.isPlaying
                            ? Icons.pause
                            : Icons.play_arrow),
                        label:
                            Text(playback.isPlaying ? l10n.pause : l10n.play),
                      ),
                      OutlinedButton.icon(
                        onPressed: playback.stop,
                        icon: const Icon(Icons.stop),
                        label: Text(l10n.stop),
                      ),
                    ],
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
