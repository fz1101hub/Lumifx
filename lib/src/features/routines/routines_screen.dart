import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_scope.dart';
import '../../core/color/light_color.dart';
import '../../core/effects/effect.dart';
import '../common/app_text.dart';
import '../common/layout.dart';
import '../effects/light_color_ui.dart';
import '../effects/playback_controller.dart';
import '../library/preferences_controller.dart';
import 'kid_routine.dart';

/// The steps of [routine] a grown-up kept, in order.
List<RoutineStep> stepsOf(
    PreferencesController preferences, KidRoutine routine) {
  final kept = preferences.routineSteps(routine.name);
  return [
    for (final step in routine.allSteps)
      if (kept == null || kept.contains(step.name)) step,
  ];
}

/// Morning and evening picture checklists, and the stars earned.
class RoutinesScreen extends StatelessWidget {
  const RoutinesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scope = AppScope.of(context);
    final preferences = scope.preferences;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.kidRoutines)),
      body: ListenableBuilder(
        listenable: preferences,
        builder: (context, _) {
          final today = scope.clock();
          final stars = preferences.stars;
          return ListView(
            padding: context.pageInsets(),
            children: [
              Text(l10n.kidRoutinesDescription,
                  style: theme.textTheme.bodyMedium),
              const SizedBox(height: 16),
              for (final routine in KidRoutine.values)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(routine == KidRoutine.morning
                                ? Icons.wb_sunny_outlined
                                : Icons.nightlight_outlined),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(routine.title(l10n),
                                  style: theme.textTheme.titleMedium),
                            ),
                            if (stars.contains(routineDayKey(routine, today)))
                              Icon(Icons.star,
                                  color: Colors.amber.shade400,
                                  semanticLabel: l10n.routineStarToday),
                            IconButton(
                              tooltip: l10n.routineChooseSteps,
                              icon: const Icon(Icons.tune),
                              onPressed: () => showDialog<void>(
                                context: context,
                                builder: (_) => _StepsDialog(routine: routine),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 4,
                          children: [
                            for (final step in stepsOf(preferences, routine))
                              Icon(step.icon,
                                  size: 20,
                                  color: theme.colorScheme.onSurfaceVariant),
                          ],
                        ),
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => RoutineScreen(routine: routine),
                            ),
                          ),
                          icon: const Icon(Icons.play_arrow),
                          label: Text(l10n.timerStart),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Text(l10n.routineStars(stars.length),
                  style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              _Week(today: today, stars: stars),
            ],
          );
        },
      ),
    );
  }
}

/// The last seven days: a star for each routine done.
class _Week extends StatelessWidget {
  const _Week({required this.today, required this.stars});

  final DateTime today;
  final Set<String> stars;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = MaterialLocalizations.of(context);
    return Row(
      children: [
        for (var back = 6; back >= 0; back--)
          Expanded(
            child: Builder(builder: (context) {
              final day = DateTime(today.year, today.month, today.day - back);
              return Column(
                children: [
                  Text(
                    localizations.narrowWeekdays[day.weekday % 7],
                    style: theme.textTheme.labelMedium,
                  ),
                  for (final routine in KidRoutine.values)
                    Icon(
                      stars.contains(routineDayKey(routine, day))
                          ? Icons.star
                          : Icons.star_border,
                      color: stars.contains(routineDayKey(routine, day))
                          ? Colors.amber.shade400
                          : theme.colorScheme.outlineVariant,
                    ),
                ],
              );
            }),
          ),
      ],
    );
  }
}

/// Which steps a routine has.
class _StepsDialog extends StatelessWidget {
  const _StepsDialog({required this.routine});

  final KidRoutine routine;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final preferences = AppScope.of(context).preferences;
    return AlertDialog(
      title: Text(routine.title(l10n)),
      content: ListenableBuilder(
        listenable: preferences,
        builder: (context, _) {
          final kept = stepsOf(preferences, routine).toSet();
          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final step in routine.allSteps)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: Icon(step.icon),
                    title: Text(step.label(l10n)),
                    value: kept.contains(step),
                    onChanged: (on) {
                      final next = [
                        for (final s in routine.allSteps)
                          if (s == step ? on == true : kept.contains(s)) s.name,
                      ];
                      if (next.isNotEmpty) {
                        preferences.setRoutineSteps(routine.name, next);
                      }
                    },
                  ),
              ],
            ),
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.close),
        ),
      ],
    );
  }
}

/// A routine running: big pictures to tap when each step is done, the
/// lamps filling up, and a party and a star at the end.
class RoutineScreen extends StatefulWidget {
  const RoutineScreen({required this.routine, super.key});

  final KidRoutine routine;

  @override
  State<RoutineScreen> createState() => _RoutineScreenState();
}

class _RoutineScreenState extends State<RoutineScreen> {
  final _done = <RoutineStep>{};
  late List<RoutineStep> _steps;
  bool _started = false;
  bool? _newStar;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _steps = stepsOf(AppScope.of(context).preferences, widget.routine);
      // After the first frame: starting redraws whatever listens to the
      // player, which must not happen while this screen is being built.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(_show());
        }
      });
    }
  }

  Future<void> _play(PlaybackController playback, LightingEffect effect) async {
    await playback.switchEffect(effect);
    if (playback.status == PlaybackStatus.idle) {
      await playback.start();
    } else if (playback.status == PlaybackStatus.paused) {
      await playback.resume();
    }
  }

  /// The lights show how far the routine is.
  Future<void> _show() async {
    final l10n = context.l10n;
    final playback = AppScope.of(context).playback;
    await _play(
      playback,
      widget.routine.progressEffect(
          _done.length, _steps.length, widget.routine.title(l10n)),
    );
  }

  Future<void> _tap(RoutineStep step) async {
    final scope = AppScope.of(context);
    final l10n = context.l10n;
    unawaited(HapticFeedback.selectionClick());
    setState(() {
      if (!_done.remove(step)) {
        _done.add(step);
      }
    });
    if (_done.length == _steps.length) {
      final earned = scope.preferences
          .earnStar(routineDayKey(widget.routine, scope.clock()));
      setState(() => _newStar = earned);
      await _play(scope.playback,
          widget.routine.doneEffect(widget.routine.title(l10n)));
      return;
    }
    scope.playback.flash(LightColor.fromHex(step.color),
        length: const Duration(milliseconds: 800));
    await _show();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final allDone = _steps.isNotEmpty && _done.length == _steps.length;
    return Scaffold(
      appBar: AppBar(title: Text(widget.routine.title(l10n))),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  allDone
                      ? (_newStar == false
                          ? l10n.routineDoneAgain
                          : l10n.routineDone)
                      : l10n.routineProgress(_done.length, _steps.length),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall,
                ),
              ),
            ),
            LinearProgressIndicator(
              value: _steps.isEmpty ? 0 : _done.length / _steps.length,
              minHeight: 10,
            ),
            Expanded(
              child: GridView.count(
                padding: const EdgeInsets.all(16),
                crossAxisCount: context.isWide ? 3 : 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                children: [
                  for (final step in _steps)
                    _StepTile(
                      step: step,
                      done: _done.contains(step),
                      onTap: () => _tap(step),
                    ),
                ],
              ),
            ),
            if (allDone)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.star, size: 40, color: Colors.amber.shade400),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(l10n.close),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({
    required this.step,
    required this.done,
    required this.onTap,
  });

  final RoutineStep step;
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = LightColor.fromHex(step.color).toColor();
    final label = step.label(context.l10n);
    return Semantics(
      button: true,
      checked: done,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: done
            ? color.withValues(alpha: 0.85)
            : theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(done ? Icons.check_circle : step.icon,
                    size: 56, color: done ? Colors.black87 : color),
                const SizedBox(height: 8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: done ? Colors.black87 : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
