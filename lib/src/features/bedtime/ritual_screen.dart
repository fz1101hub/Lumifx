import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/effects/effect.dart';
import '../../core/effects/engine/light_frame.dart';
import '../../core/sound/melodies.dart';
import '../calm/breathing.dart';
import '../../core/speech/speaker.dart';
import '../common/app_text.dart';
import '../common/layout.dart';
import '../effects/playback_controller.dart';
import '../effects/read_along.dart';
import '../music_box/melody_lights.dart';
import '../music_box/music_box_screen.dart';
import '../routines/child_picker.dart';
import '../routines/kid_routine.dart';
import '../routines/routines_screen.dart';
import '../tales/tale.dart';
import 'monster_spray.dart';
import 'monster_spray_screen.dart';
import 'ritual.dart';

/// The bedtime ritual in one tap: the evening routine, the monster spray,
/// a story made up for tonight, a lullaby and the guardian light, one
/// after the other (the steps a grown-up kept).
class BedtimeRitualScreen extends StatefulWidget {
  const BedtimeRitualScreen({this.seed, super.key});

  /// Fixes tonight's story (tests).
  final int? seed;

  @override
  State<BedtimeRitualScreen> createState() => _BedtimeRitualScreenState();
}

class _BedtimeRitualScreenState extends State<BedtimeRitualScreen> {
  late final _random =
      widget.seed == null ? math.Random() : math.Random(widget.seed);
  late PlaybackController _playback;
  StreamSubscription<PlaybackNotice>? _notices;

  /// Null before the start; the steps' count once the ritual is over.
  int? _index;
  var _steps = const <RitualStep>[];
  LightingEffect? _effect;
  Tale? _tale;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _playback = AppScope.of(context).playback;
    _notices ??= _playback.notices.listen(_onNotice);
  }

  @override
  void dispose() {
    unawaited(_notices?.cancel());
    super.dispose();
  }

  /// How long the breathing step lasts.
  static const _breathingMinutes = 1;

  RitualStep? get _step {
    final index = _index;
    return index == null || index >= _steps.length ? null : _steps[index];
  }

  /// The story or the lullaby ended: on to the next step.
  void _onNotice(PlaybackNotice notice) {
    final effect = _effect;
    if (notice.kind == PlaybackNoticeKind.finished &&
        effect != null &&
        notice.name == effect.name &&
        (_step == RitualStep.breathing ||
            _step == RitualStep.story ||
            _step == RitualStep.lullaby)) {
      unawaited(_next());
    }
  }

  Future<void> _play(LightingEffect effect) async {
    _effect = effect;
    await _playback.switchEffect(effect);
    if (_playback.status == PlaybackStatus.idle) {
      await _playback.start();
    } else if (_playback.status == PlaybackStatus.paused) {
      await _playback.resume();
    }
  }

  Future<void> _start() async {
    final settings = AppScope.of(context).preferences.ritual;
    setState(() {
      _steps = settings.steps;
      _index = -1;
    });
    await _next();
  }

  Future<void> _next() async {
    if (!mounted) {
      return;
    }
    final scope = AppScope.of(context);
    final l10n = context.l10n;
    final settings = scope.preferences.ritual;
    final index = (_index ?? -1) + 1;
    setState(() {
      _index = index;
      _effect = null;
    });
    final step = _step;
    if (step == null) {
      return;
    }
    // A timer left by the monster spray's guardian light would cut the
    // story short.
    _playback.setSleepTimer(null);
    switch (step) {
      case RitualStep.routine:
        await Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => const RoutineScreen(routine: KidRoutine.evening)));
        if (mounted && _index == index) {
          await _next();
        }
      case RitualStep.monsterSpray:
        await Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => const MonsterSprayScreen()));
        if (mounted && _index == index) {
          await _next();
        }
      case RitualStep.breathing:
        await _play(BreathingPattern.flowerCandle
            .effect(minutes: _breathingMinutes, name: l10n.breathe));
      case RitualStep.story:
        final tale =
            Tale.random(_random, name: scope.preferences.activeChild?.name);
        setState(() => _tale = tale);
        await _play(tale.effect(l10n));
      case RitualStep.lullaby:
        final melody = melodyById(settings.lullaby) ?? brahms;
        await _play(melodyEffect(melody,
            times: 1, name: MusicBoxScreen.nameOf(l10n, melody)));
      case RitualStep.guardian:
        await _play(MonsterHunt.guardian(l10n.guardianLight));
        _playback.setSleepTimer(Duration(minutes: settings.guardianMinutes));
        _sayGoodnight();
    }
  }

  /// "Goodnight, Mia!", by the child's name.
  String _goodnight(AppLocalizations l10n) {
    final name = AppScope.of(context).preferences.activeChild?.name;
    return name == null || name.trim().isEmpty
        ? l10n.ritualGoodnight
        : l10n.ritualGoodnightName(name.trim());
  }

  /// Said aloud too, when stories are read aloud.
  void _sayGoodnight() {
    // Closed while the guardian light was starting.
    if (!mounted) {
      return;
    }
    final scope = AppScope.of(context);
    if (!scope.preferences.readAloud || !scope.preferences.soundOn) {
      return;
    }
    final text = _goodnight(context.l10n);
    final language = Localizations.localeOf(context).languageCode;
    unawaited(scope.speaker.speak(text, speechLanguage(language)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.ritual)),
      body: _index == null ? _settings(context) : _running(context),
    );
  }

  Widget _settings(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final preferences = AppScope.of(context).preferences;
    return ListenableBuilder(
      listenable: preferences,
      builder: (context, _) {
        final settings = preferences.ritual;
        return ListView(
          padding: context.pageInsets(),
          children: [
            Text(l10n.ritualDescription, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),
            const ChildPicker(),
            const SizedBox(height: 8),
            for (final step in RitualStep.values)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                secondary: Icon(step.icon),
                title: Text(step.title(l10n)),
                value: settings.steps.contains(step),
                onChanged: (on) =>
                    preferences.setRitual(settings.withStep(step, on == true)),
              ),
            if (settings.steps.contains(RitualStep.lullaby)) ...[
              const SizedBox(height: 8),
              Text(l10n.lullabies, style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final melody in lullabies)
                    ChoiceChip(
                      label: Text(MusicBoxScreen.nameOf(l10n, melody)),
                      selected: settings.lullaby == melody.id,
                      onSelected: (_) => preferences
                          .setRitual(settings.copyWith(lullaby: melody.id)),
                    ),
                ],
              ),
            ],
            if (settings.steps.contains(RitualStep.guardian)) ...[
              const SizedBox(height: 16),
              Text(l10n.guardianLightFor, style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final minutes in MonsterHunt.guardianMinutes)
                    ChoiceChip(
                      label: Text(l10n.sleepTimerMinutes(minutes)),
                      selected: settings.guardianMinutes == minutes,
                      onSelected: (_) => preferences.setRitual(
                          settings.copyWith(guardianMinutes: minutes)),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56)),
              onPressed: _start,
              icon: const Icon(Icons.nights_stay_outlined),
              label: Text(l10n.timerStart),
            ),
          ],
        );
      },
    );
  }

  Widget _running(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final index = _index!;
    final step = _step;
    return ListenableBuilder(
      listenable: _playback,
      builder: (context, _) => ListView(
        padding: context.pageInsets(),
        children: [
          for (final (i, s) in _steps.indexed)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(i < index ? Icons.check_circle : s.icon,
                  color: i < index
                      ? theme.colorScheme.primary
                      : i == index
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.outline),
              title: Text(
                s.title(l10n),
                style: i == index
                    ? theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)
                    : null,
              ),
            ),
          const SizedBox(height: 16),
          if (step == null || step == RitualStep.guardian)
            Semantics(
              liveRegion: true,
              child: Text(_goodnight(l10n),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium),
            )
          else ...[
            Semantics(
              liveRegion: true,
              child: Text(
                l10n.ritualStepOf(index + 1, _steps.length),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
            ),
            if (step == RitualStep.breathing)
              if ((_effect, _playback.player)
                  case (final effect?, final player?)
                  when _playback.effect.id == effect.id)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: ReadAlongCaption(
                    effect: effect,
                    lines: BreathingPattern.flowerCandle
                        .narration(_breathingMinutes, l10n),
                    player: player,
                  ),
                ),
            if (step == RitualStep.story)
              if ((_tale, _effect, _playback.player)
                  case (final tale?, final effect?, final player?)
                  when _playback.effect.id == effect.id)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: StreamBuilder<List<LightFrame>>(
                    stream: player.frames,
                    builder: (context, _) => ReadAlongCaption(
                      effect: effect,
                      lines: tale.narration(l10n),
                      player: player,
                    ),
                  ),
                ),
            const SizedBox(height: 16),
            Center(
              child: TextButton.icon(
                onPressed: _next,
                icon: const Icon(Icons.skip_next),
                label: Text(l10n.ritualNext),
              ),
            ),
          ],
          if (step == null || step == RitualStep.guardian)
            Center(
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.close),
              ),
            ),
        ],
      ),
    );
  }
}
