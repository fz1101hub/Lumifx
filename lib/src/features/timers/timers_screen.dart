import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/color/light_color.dart';
import '../../core/effects/effect.dart';
import '../../core/effects/engine/light_frame.dart';
import '../common/app_text.dart';
import '../common/layout.dart';
import '../effects/light_color_ui.dart';
import '../effects/playback_controller.dart';
import 'light_timer.dart';
import 'pomodoro.dart';
import 'pomodoro_screen.dart';

/// The light timers, each a tap away; cooking asks how long.
class TimersScreen extends StatefulWidget {
  const TimersScreen({super.key});

  static const cookingChoices = [5, 10, 15, 20, 30, 45, 60];

  @override
  State<TimersScreen> createState() => _TimersScreenState();
}

class _TimersScreenState extends State<TimersScreen> {
  int _cookingMinutes = LightTimer.cooking.minutes;
  int _pomodoroRounds = 4;

  Future<void> _startPomodoro() async {
    final l10n = context.l10n;
    final playback = AppScope.of(context).playback;
    final pomodoro = Pomodoro(rounds: _pomodoroRounds);
    final effect = pomodoro.effect(l10n.pomodoro);
    await playback.switchEffect(effect);
    if (playback.status == PlaybackStatus.idle) {
      await playback.start();
    } else if (playback.status == PlaybackStatus.paused) {
      await playback.resume();
    }
    if (!mounted || playback.effect.id != effect.id) {
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => PomodoroRunningScreen(pomodoro: pomodoro, effect: effect),
    ));
  }

  static String nameOf(AppLocalizations l10n, LightTimer timer) =>
      switch (timer) {
        LightTimer.teeth => l10n.timerTeeth,
        LightTimer.tidyUp => l10n.timerTidyUp,
        LightTimer.homework => l10n.timerHomework,
        LightTimer.focus => l10n.timerFocus,
        LightTimer.cooking => l10n.timerCooking,
      };

  static IconData _iconOf(LightTimer timer) => switch (timer) {
        LightTimer.teeth => Icons.clean_hands_outlined,
        LightTimer.tidyUp => Icons.toys_outlined,
        LightTimer.homework => Icons.menu_book_outlined,
        LightTimer.focus => Icons.center_focus_strong_outlined,
        LightTimer.cooking => Icons.soup_kitchen_outlined,
      };

  Future<void> _start(LightTimer timer) async {
    final l10n = context.l10n;
    final playback = AppScope.of(context).playback;
    final length = Duration(
      minutes: timer == LightTimer.cooking ? _cookingMinutes : timer.minutes,
    );
    final effect = timer.effect(name: nameOf(l10n, timer), length: length);
    await playback.switchEffect(effect);
    if (playback.status == PlaybackStatus.idle) {
      await playback.start();
    } else if (playback.status == PlaybackStatus.paused) {
      await playback.resume();
    }
    if (!mounted || playback.effect.id != effect.id) {
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => TimerRunningScreen(effect: effect, length: length),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.timers)),
      body: ListView(
        padding: context.pageInsets(),
        children: [
          Text(l10n.timersDescription, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 16),
          for (final timer in LightTimer.values)
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            LightColor.fromHex(timer.from).toColor(),
                        foregroundColor: Colors.black87,
                        child: Icon(_iconOf(timer)),
                      ),
                      title: Text(nameOf(l10n, timer)),
                      subtitle: Text(l10n.sleepTimerMinutes(
                        timer == LightTimer.cooking
                            ? _cookingMinutes
                            : timer.minutes,
                      )),
                      trailing: FilledButton(
                        onPressed: () => _start(timer),
                        child: Text(l10n.timerStart),
                      ),
                    ),
                    if (timer == LightTimer.cooking)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            for (final minutes in TimersScreen.cookingChoices)
                              ChoiceChip(
                                label: Text(l10n.sleepTimerMinutes(minutes)),
                                selected: _cookingMinutes == minutes,
                                onSelected: (_) =>
                                    setState(() => _cookingMinutes = minutes),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFFF8A2B),
                      foregroundColor: Colors.black87,
                      child: Icon(Icons.repeat),
                    ),
                    title: Text(l10n.pomodoro),
                    subtitle: Text(l10n.pomodoroSubtitle(25, 5)),
                    trailing: FilledButton(
                      onPressed: _startPomodoro,
                      child: Text(l10n.timerStart),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        for (final rounds in Pomodoro.roundChoices)
                          ChoiceChip(
                            label: Text(l10n.pomodoroRounds(rounds)),
                            selected: _pomodoroRounds == rounds,
                            onSelected: (_) =>
                                setState(() => _pomodoroRounds = rounds),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A running timer: the time left in large figures over the lights'
/// colour, pause and stop; "Time's up!" once it has finished.
class TimerRunningScreen extends StatelessWidget {
  const TimerRunningScreen({
    required this.effect,
    required this.length,
    super.key,
  });

  final LightingEffect effect;
  final Duration length;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final playback = AppScope.of(context).playback;
    return Scaffold(
      appBar: AppBar(title: Text(effect.name)),
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
                  Icon(Icons.celebration_outlined,
                      size: 64, color: theme.colorScheme.primary),
                  const SizedBox(height: 16),
                  Text(l10n.timerDone, style: theme.textTheme.headlineMedium),
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
              final speed = playback.controls.speed.clamp(0.05, 5.0);
              final left = length - player.position;
              final seconds = left.isNegative
                  ? 0
                  : (left.inMilliseconds / 1000 / speed).ceil();
              final frame = player.currentFrames.firstOrNull;
              final done =
                  (player.position.inMilliseconds / length.inMilliseconds)
                      .clamp(0.0, 1.0);
              return ListView(
                padding: context.pageInsets(),
                children: [
                  const SizedBox(height: 24),
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
                              semanticsLabel: effect.name,
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
                            seconds == 0
                                ? l10n.timerDone
                                : '${seconds ~/ 60}:'
                                    '${(seconds % 60).toString().padLeft(2, '0')}',
                            textAlign: TextAlign.center,
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
