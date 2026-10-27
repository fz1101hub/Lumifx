import 'dart:async';

import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/effects/engine/light_frame.dart';
import '../../core/speech/speaker.dart';
import '../common/app_text.dart';
import '../common/layout.dart';
import '../effects/light_color_ui.dart';
import '../effects/playback_controller.dart';
import '../effects/read_aloud.dart';
import 'interval_training.dart';

/// Interval training: pick a workout and the rounds, then the lights lead
/// it and the voice calls each part, a moment early so the word comes
/// with the light.
class IntervalTrainingScreen extends StatefulWidget {
  const IntervalTrainingScreen({super.key});

  @override
  State<IntervalTrainingScreen> createState() => _IntervalTrainingScreenState();
}

class _IntervalTrainingScreenState extends State<IntervalTrainingScreen> {
  var _preset = WorkoutPreset.hiit;
  int? _rounds;
  (IntervalKind, int)? _called;

  static String _presetName(AppLocalizations l10n, WorkoutPreset preset) =>
      switch (preset) {
        WorkoutPreset.hiit => l10n.workoutHiit,
        WorkoutPreset.tabata => l10n.workoutTabata,
        WorkoutPreset.stretching => l10n.workoutStretching,
      };

  Future<void> _start() async {
    final l10n = context.l10n;
    final playback = AppScope.of(context).playback;
    final workout = IntervalWorkout(
      work: Duration(seconds: _preset.work),
      rest: Duration(seconds: _preset.rest),
      rounds: _rounds ?? _preset.rounds,
    );
    _called = null;
    playback.setSleepTimer(null);
    await playback.switchEffect(workout.effect(_presetName(l10n, _preset)));
    if (playback.status == PlaybackStatus.idle) {
      await playback.start();
    } else if (playback.status == PlaybackStatus.paused) {
      await playback.resume();
    }
  }

  /// Calls the part about to start, as the lights change.
  void _call(IntervalWorkout workout, Duration position) {
    final next = workout.at(position + ReadAloud.speechLead);
    final key = (next.kind, next.round);
    if (_called == key) {
      return;
    }
    final first = _called == null;
    _called = key;
    final scope = AppScope.of(context);
    if (first || !scope.preferences.soundOn) {
      return;
    }
    final l10n = context.l10n;
    final text = switch (next.kind) {
      IntervalKind.work when next.round == workout.rounds =>
        l10n.intervalLastRound,
      IntervalKind.work => l10n.intervalWork,
      IntervalKind.rest => l10n.intervalRest,
      IntervalKind.done => l10n.intervalDone,
      IntervalKind.ready => null,
    };
    if (text == null) {
      return;
    }
    final language =
        speechLanguage(Localizations.localeOf(context).languageCode);
    unawaited(() async {
      await scope.speaker.stop();
      await scope.speaker.speak(text, language);
    }());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final playback = AppScope.of(context).playback;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.intervals)),
      body: ListenableBuilder(
        listenable: playback,
        builder: (context, _) {
          final workout = IntervalWorkout.of(playback.effect);
          final player = playback.player;
          if (workout != null &&
              player != null &&
              playback.status != PlaybackStatus.idle) {
            return StreamBuilder<List<LightFrame>>(
              stream: player.frames,
              builder: (context, _) {
                _call(workout, player.position);
                return _running(context, workout);
              },
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
    final rounds = _rounds ?? _preset.rounds;
    return ListView(
      padding: context.pageInsets(),
      children: [
        Text(l10n.intervalsDescription, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 16),
        for (final preset in WorkoutPreset.values)
          Card(
            child: ListTile(
              leading: Icon(_preset == preset
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off),
              title: Text(_presetName(l10n, preset)),
              subtitle: Text(l10n.workoutWorkRest(preset.work, preset.rest)),
              selected: _preset == preset,
              onTap: () => setState(() {
                _preset = preset;
                _rounds = null;
              }),
            ),
          ),
        const SizedBox(height: 16),
        Text(l10n.intervalsRounds, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final choice in IntervalWorkout.roundChoices)
              ChoiceChip(
                label: Text('$choice'),
                selected: rounds == choice,
                onSelected: (_) => setState(() => _rounds = choice),
              ),
          ],
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
          onPressed: _start,
          icon: const Icon(Icons.fitness_center),
          label: Text(l10n.intervalsStart),
        ),
      ],
    );
  }

  Widget _running(BuildContext context, IntervalWorkout workout) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final playback = AppScope.of(context).playback;
    final player = playback.player!;
    final part = workout.at(player.position);
    final frame = player.currentFrames.firstOrNull;
    return ListView(
      padding: context.pageInsets(),
      children: [
        const SizedBox(height: 24),
        Center(
          child: Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: frame?.toDisplayColor() ?? Colors.black,
            ),
            alignment: Alignment.center,
            child: Text(
              part.kind == IntervalKind.done
                  ? ''
                  : '${part.left.inMilliseconds ~/ 1000 + 1}',
              style: theme.textTheme.displayLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Semantics(
          liveRegion: true,
          child: Text(
            switch (part.kind) {
              IntervalKind.ready => l10n.intervalReady,
              IntervalKind.work => l10n.intervalWork,
              IntervalKind.rest => l10n.intervalRest,
              IntervalKind.done => l10n.intervalDone,
            },
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium,
          ),
        ),
        if (part.kind == IntervalKind.work || part.kind == IntervalKind.rest)
          Text(
            l10n.intervalRound(part.round, workout.rounds),
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
        const SizedBox(height: 32),
        Center(
          child: OutlinedButton.icon(
            onPressed: playback.stop,
            icon: const Icon(Icons.stop),
            label: Text(l10n.stop),
          ),
        ),
      ],
    );
  }
}
