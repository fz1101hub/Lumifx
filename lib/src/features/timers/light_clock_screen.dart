import 'dart:async';

import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/speech/speaker.dart';
import '../common/app_text.dart';
import '../common/layout.dart';
import '../effects/light_color_ui.dart';
import '../effects/playback_controller.dart';
import 'light_clock.dart';

/// The light clock: what for, at what time, and how early the lamps turn
/// yellow; then the lamps count down and the voice says when to get
/// ready and when it is time.
class LightClockScreen extends StatefulWidget {
  const LightClockScreen({super.key});

  @override
  State<LightClockScreen> createState() => _LightClockScreenState();
}

class _LightClockScreenState extends State<LightClockScreen> {
  var _occasion = ClockOccasion.leave;
  TimeOfDay? _time;
  var _warn = 10;
  Timer? _tick;
  ClockPhase? _phase;

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  /// Half an hour from now, on a round five minutes.
  TimeOfDay get _defaultTime {
    final soon = AppScope.of(context).clock().add(const Duration(minutes: 30));
    final minutes = (soon.hour * 60 + soon.minute + 4) ~/ 5 * 5;
    return TimeOfDay(hour: minutes ~/ 60 % 24, minute: minutes % 60);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? _defaultTime,
    );
    if (picked != null) {
      setState(() => _time = picked);
    }
  }

  Future<void> _start() async {
    final scope = AppScope.of(context);
    final playback = scope.playback;
    final now = scope.clock();
    final time = _time ?? _defaultTime;
    final effect = LightClock.effect(
      _occasionName(context.l10n, _occasion),
      now: now,
      at: LightClock.nextAt(now, time.hour, time.minute),
      warnMinutes: _warn,
      occasion: _occasion,
    );
    // A sleep timer left by a lullaby would switch the lamps off early.
    playback.setSleepTimer(null);
    _phase = null;
    await playback.switchEffect(effect);
    if (playback.status == PlaybackStatus.idle) {
      await playback.start();
    } else if (playback.status == PlaybackStatus.paused) {
      await playback.resume();
    }
  }

  static String _occasionName(AppLocalizations l10n, ClockOccasion o) =>
      switch (o) {
        ClockOccasion.leave => l10n.clockLeave,
        ClockOccasion.meal => l10n.clockMeal,
        ClockOccasion.bed => l10n.clockBed,
        ClockOccasion.other => l10n.clockOther,
      };

  /// What the voice says as the lamps turn yellow, and when it is time.
  static String? _saying(AppLocalizations l10n, ClockOccasion occasion,
      ClockPhase phase, int minutes) {
    return switch ((phase, occasion)) {
      (ClockPhase.yellow, ClockOccasion.leave) =>
        l10n.clockSayLeaveSoon(minutes),
      (ClockPhase.yellow, ClockOccasion.meal) => l10n.clockSayMealSoon(minutes),
      (ClockPhase.yellow, ClockOccasion.bed) => l10n.clockSayBedSoon(minutes),
      (ClockPhase.yellow, ClockOccasion.other) =>
        l10n.clockSayOtherSoon(minutes),
      (ClockPhase.now, ClockOccasion.leave) => l10n.clockSayLeaveNow,
      (ClockPhase.now, ClockOccasion.meal) => l10n.clockSayMealNow,
      (ClockPhase.now, ClockOccasion.bed) => l10n.clockSayBedNow,
      (ClockPhase.now, ClockOccasion.other) => l10n.clockPhaseNow,
      _ => null,
    };
  }

  /// Watches the time while a light clock runs, to say what is next.
  void _watch(bool running) {
    if (running && _tick == null) {
      _tick = Timer.periodic(const Duration(seconds: 1), (_) => _check());
    } else if (!running && _tick != null) {
      _tick?.cancel();
      _tick = null;
      _phase = null;
    }
  }

  void _check() {
    if (!mounted) {
      return;
    }
    final scope = AppScope.of(context);
    final clock = LightClock.of(scope.playback.effect);
    if (clock == null) {
      return;
    }
    final now = scope.clock();
    final phase = LightClock.phaseAt(now, clock.at, clock.warnMinutes);
    final previous = _phase;
    if (phase != previous) {
      setState(() => _phase = phase);
      // Not on opening the screen mid-way: only as it changes.
      if (previous != null && scope.preferences.soundOn) {
        final minutes = (clock.at.difference(now).inSeconds / 60).ceil();
        final text = _saying(context.l10n, clock.occasion, phase, minutes);
        if (text != null) {
          final language =
              speechLanguage(Localizations.localeOf(context).languageCode);
          unawaited(() async {
            await scope.speaker.stop();
            await scope.speaker.speak(text, language, style: SpeechStyle.story);
          }());
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final playback = AppScope.of(context).playback;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.lightClock)),
      body: ListenableBuilder(
        listenable: playback,
        builder: (context, _) {
          final clock = LightClock.of(playback.effect);
          final player = playback.player;
          final running = clock != null &&
              player != null &&
              playback.status != PlaybackStatus.idle;
          _watch(running);
          if (running) {
            return StreamBuilder(
              stream: player.frames,
              builder: (context, _) => _running(context, clock),
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
    final time = _time ?? _defaultTime;
    return ListView(
      padding: context.pageInsets(),
      children: [
        Text(l10n.lightClockDescription, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 16),
        Text(l10n.lightClockWhat, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final occasion in ClockOccasion.values)
              ChoiceChip(
                label: Text(_occasionName(l10n, occasion)),
                selected: _occasion == occasion,
                onSelected: (_) => setState(() => _occasion = occasion),
              ),
          ],
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          style:
              OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(56)),
          onPressed: _pickTime,
          icon: const Icon(Icons.schedule),
          label: Text(
            l10n.lightClockAt(MaterialLocalizations.of(context).formatTimeOfDay(
              time,
              alwaysUse24HourFormat:
                  MediaQuery.alwaysUse24HourFormatOf(context),
            )),
            style: theme.textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: 16),
        Text(l10n.lightClockWarn, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final minutes in LightClock.warnChoices)
              ChoiceChip(
                label: Text(l10n.sleepTimerMinutes(minutes)),
                selected: _warn == minutes,
                onSelected: (_) => setState(() => _warn = minutes),
              ),
          ],
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
          onPressed: _start,
          icon: const Icon(Icons.play_arrow),
          label: Text(l10n.lightClockStart),
        ),
      ],
    );
  }

  Widget _running(BuildContext context,
      ({ClockOccasion occasion, DateTime at, int warnMinutes}) clock) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scope = AppScope.of(context);
    final playback = scope.playback;
    final now = scope.clock();
    final phase = LightClock.phaseAt(now, clock.at, clock.warnMinutes);
    final minutes = (clock.at.difference(now).inSeconds / 60).ceil();
    final frame = playback.player?.currentFrames.firstOrNull;
    return ListView(
      padding: context.pageInsets(),
      children: [
        const SizedBox(height: 24),
        Center(
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: frame?.toDisplayColor() ?? Colors.black,
            ),
            alignment: Alignment.center,
            child: Text(
              _occasionName(l10n, clock.occasion),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Semantics(
          liveRegion: true,
          child: Text(
            switch (phase) {
              ClockPhase.green => l10n.clockPhaseGreen,
              ClockPhase.yellow => l10n.clockPhaseYellow,
              ClockPhase.red => l10n.clockPhaseRed,
              ClockPhase.now => l10n.clockPhaseNow,
            },
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
          ),
        ),
        if (phase != ClockPhase.now) ...[
          const SizedBox(height: 8),
          Text(
            l10n.clockMinutesLeft(minutes),
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
        ],
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
