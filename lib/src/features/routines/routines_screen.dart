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
import '../timers/light_timer.dart';
import '../timers/timers_screen.dart';
import 'child_picker.dart';
import 'custom_step.dart';
import 'kid_routine.dart';
import 'star_shop_screen.dart';

/// The steps of [routine] a grown-up kept, in order: the built-in ones,
/// then those the grown-up made.
List<RoutineItem> stepsOf(
    PreferencesController preferences, KidRoutine routine) {
  final kept = preferences.routineSteps(routine.name);
  if (kept == null) {
    return routine.allSteps;
  }
  return [
    for (final step in routine.allSteps)
      if (kept.contains(step.key)) step,
    for (final step in preferences.customSteps)
      if (kept.contains(step.key)) step,
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
              const SizedBox(height: 12),
              const ChildPicker(),
              const SizedBox(height: 12),
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
              Row(
                children: [
                  Expanded(
                    child: Text(l10n.routineStars(stars.length),
                        style: theme.textTheme.titleMedium),
                  ),
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                          builder: (_) => const StarShopScreen()),
                    ),
                    icon: const Icon(Icons.storefront_outlined),
                    label: Text(l10n.starShop),
                  ),
                ],
              ),
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
          final all = <RoutineItem>[
            ...routine.allSteps,
            ...preferences.customSteps,
          ];
          void keep(RoutineItem step, bool on) {
            final next = [
              for (final s in all)
                if (s == step ? on : kept.contains(s)) s.key,
            ];
            if (next.isNotEmpty) {
              preferences.setRoutineSteps(routine.name, next);
            }
          }

          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final step in all)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: step is CustomStep
                        ? IconButton(
                            tooltip: l10n.delete,
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () =>
                                preferences.removeCustomStep(step.id),
                          )
                        : Icon(step.icon),
                    title: Row(
                      children: [
                        if (step is CustomStep) ...[
                          Icon(step.icon, size: 20),
                          const SizedBox(width: 8),
                        ],
                        Expanded(child: Text(step.label(l10n))),
                      ],
                    ),
                    value: kept.contains(step),
                    onChanged: (on) => keep(step, on == true),
                  ),
                if (preferences.customSteps.length < CustomStep.maxSteps)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () async {
                        final step = await showDialog<CustomStep>(
                          context: context,
                          builder: (_) => const _NewStepDialog(),
                        );
                        if (step == null) {
                          return;
                        }
                        final made = await preferences.addCustomStep(
                            step.name, step.iconIndex, step.color);
                        if (made != null) {
                          await preferences.setRoutineSteps(routine.name, [
                            for (final s in stepsOf(preferences, routine))
                              s.key,
                            made.key,
                          ]);
                        }
                      },
                      icon: const Icon(Icons.add),
                      label: Text(l10n.routineAddStep),
                    ),
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

/// A new step: what to do, its picture and colour.
class _NewStepDialog extends StatefulWidget {
  const _NewStepDialog();

  @override
  State<_NewStepDialog> createState() => _NewStepDialogState();
}

class _NewStepDialogState extends State<_NewStepDialog> {
  final _name = TextEditingController();
  var _icon = 0;
  var _color = customStepColors.first;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.routineAddStep),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              maxLength: CustomStep.maxName,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: l10n.routineStepName),
              onChanged: (_) => setState(() {}),
            ),
            Wrap(
              spacing: 4,
              children: [
                for (final (i, icon) in customStepIcons.indexed)
                  IconButton(
                    isSelected: _icon == i,
                    icon: Icon(icon),
                    onPressed: () => setState(() => _icon = i),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final hex in customStepColors)
                  InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => setState(() => _color = hex),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: LightColor.fromHex(hex).toColor(),
                        shape: BoxShape.circle,
                        border: _color == hex
                            ? Border.all(
                                color: Theme.of(context).colorScheme.onSurface,
                                width: 3)
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _name.text.trim().isEmpty
              ? null
              : () => Navigator.of(context).pop(CustomStep(
                    id: '',
                    name: _name.text,
                    iconIndex: _icon,
                    color: _color,
                  )),
          child: Text(l10n.save),
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
  final _done = <RoutineItem>{};
  late List<RoutineItem> _steps;
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

  Future<void> _tap(RoutineItem step) async {
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

  /// Brushing teeth with the two-minute light timer (and its tune): the
  /// step is done when the time is up.
  Future<void> _teethTimer(RoutineItem step) async {
    final scope = AppScope.of(context);
    final l10n = context.l10n;
    final playback = scope.playback;
    final effect = LightTimer.teeth.effect(
      name: TimersScreen.nameOf(l10n, LightTimer.teeth),
      tune: scope.preferences.teethTune,
    );
    var finished = false;
    final notices = playback.notices.listen((notice) {
      if (notice.kind == PlaybackNoticeKind.finished &&
          notice.name == effect.name) {
        finished = true;
      }
    });
    try {
      playback.setSleepTimer(null);
      await _play(playback, effect);
      if (!mounted) {
        return;
      }
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => TimerRunningScreen(
          effect: effect,
          length: Duration(minutes: LightTimer.teeth.minutes),
        ),
      ));
    } finally {
      // Not awaited: a broadcast subscription may take its time to go.
      unawaited(notices.cancel());
    }
    if (!mounted) {
      return;
    }
    if (finished && !_done.contains(step)) {
      await _tap(step);
    } else {
      await _show();
    }
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
                      onTimer: step == RoutineStep.brushTeeth &&
                              !_done.contains(step)
                          ? () => _teethTimer(step)
                          : null,
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
    this.onTimer,
  });

  final RoutineItem step;
  final bool done;
  final VoidCallback onTap;

  /// Starts a light timer for the step, if it has one.
  final VoidCallback? onTimer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = LightColor.fromHex(step.color).toColor();
    final label = step.label(context.l10n);
    final tile = Semantics(
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
    final timer = onTimer;
    if (timer == null) {
      return tile;
    }
    return Stack(
      children: [
        Positioned.fill(child: tile),
        Positioned(
          top: 4,
          right: 4,
          child: IconButton.filledTonal(
            tooltip: context.l10n.routineTeethTimer,
            onPressed: timer,
            icon: const Icon(Icons.timer_outlined),
          ),
        ),
      ],
    );
  }
}
