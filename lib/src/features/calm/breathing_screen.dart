import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/color/light_color.dart';
import '../../core/effects/effect.dart';
import '../../core/effects/engine/light_frame.dart';
import '../common/app_text.dart';
import '../common/layout.dart';
import '../effects/light_color_ui.dart';
import '../effects/playback_controller.dart';
import 'breathing.dart';

/// Calm breathing with the lights: choose a way of breathing and how long,
/// then follow the circle and the lamps, up as you breathe in, down as you
/// breathe out.
class BreathingScreen extends StatefulWidget {
  const BreathingScreen({this.playing, super.key});

  /// The breathing already on the lights, when opened from the
  /// mini-player.
  final LightingEffect? playing;

  static String nameOf(AppLocalizations l10n, BreathingPattern pattern) =>
      switch (pattern) {
        BreathingPattern.flowerCandle => l10n.breathePatternFlower,
        BreathingPattern.box => l10n.breathePatternBox,
        BreathingPattern.relax478 => l10n.breathePattern478,
      };

  static String descriptionOf(
          AppLocalizations l10n, BreathingPattern pattern) =>
      switch (pattern) {
        BreathingPattern.flowerCandle => l10n.breathePatternFlowerDescription,
        BreathingPattern.box => l10n.breathePatternBoxDescription,
        BreathingPattern.relax478 => l10n.breathePattern478Description,
      };

  @override
  State<BreathingScreen> createState() => _BreathingScreenState();
}

class _BreathingScreenState extends State<BreathingScreen> {
  late var _pattern = _running?.$1 ?? BreathingPattern.flowerCandle;
  late var _minutes = _running?.$2 ?? 3;
  late LightingEffect? _effect = widget.playing;

  (BreathingPattern, int)? get _running => switch (widget.playing) {
        final effect? => BreathingPattern.of(effect),
        null => null,
      };

  Future<void> _start() async {
    final l10n = context.l10n;
    final playback = AppScope.of(context).playback;
    final effect = _pattern.effect(
      minutes: _minutes,
      name: BreathingScreen.nameOf(l10n, _pattern),
    );
    setState(() => _effect = effect);
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
      appBar: AppBar(title: Text(l10n.breathe)),
      body: ListenableBuilder(
        listenable: playback,
        builder: (context, _) {
          final effect = _effect;
          final player = playback.player;
          final running = effect != null &&
              playback.effect.id == effect.id &&
              player != null &&
              playback.status != PlaybackStatus.idle;
          if (running) {
            return StreamBuilder<List<LightFrame>>(
              stream: player.frames,
              builder: (context, _) =>
                  _breathing(context, playback, player.position),
            );
          }
          return effect == null ? _intro(context) : _done(context);
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
        Text(l10n.breatheDescription, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 16),
        RadioGroup<BreathingPattern>(
          groupValue: _pattern,
          onChanged: (value) => setState(() => _pattern = value ?? _pattern),
          child: Column(
            children: [
              for (final pattern in BreathingPattern.values)
                RadioListTile<BreathingPattern>(
                  contentPadding: EdgeInsets.zero,
                  value: pattern,
                  title: Text(BreathingScreen.nameOf(l10n, pattern)),
                  subtitle: Text(BreathingScreen.descriptionOf(l10n, pattern)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final minutes in BreathingPattern.minutesChoices)
              ChoiceChip(
                label: Text(l10n.sleepTimerMinutes(minutes)),
                selected: _minutes == minutes,
                onSelected: (_) => setState(() => _minutes = minutes),
              ),
          ],
        ),
        ListenableBuilder(
          listenable: preferences,
          builder: (context, _) => SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.record_voice_over_outlined),
            title: Text(l10n.breatheVoice),
            value: preferences.readAloud,
            onChanged: preferences.setReadAloud,
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
          onPressed: _start,
          icon: const Icon(Icons.air),
          label: Text(l10n.timerStart),
        ),
      ],
    );
  }

  Widget _breathing(
    BuildContext context,
    PlaybackController playback,
    Duration position,
  ) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final (phase, _, fullness) = _pattern.at(position);
    final color = LightColor.lerp(
      LightColor.fromHex(BreathingPattern.emptyColor),
      LightColor.fromHex(BreathingPattern.fullColor),
      fullness,
    ).toColor();
    final total = _pattern.lengthSeconds(_minutes);
    final left =
        (total - position.inMilliseconds / 1000).ceil().clamp(0, total);
    return Column(
      children: [
        Expanded(
          child: Center(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final largest = constraints.biggest.shortestSide * 0.8;
                final size = largest * (0.35 + 0.65 * fullness);
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox.square(
                      dimension: largest,
                      child: Center(
                        child: Container(
                          width: size,
                          height: size,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: color.withValues(alpha: 0.85),
                            boxShadow: [
                              BoxShadow(color: color, blurRadius: 40),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        Semantics(
          liveRegion: true,
          child: Text(
            _pattern.callOf(phase, l10n),
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium,
          ),
        ),
        const SizedBox(height: 8),
        Text('${left ~/ 60}:${(left % 60).toString().padLeft(2, '0')}',
            style: theme.textTheme.titleMedium),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton.icon(
              onPressed: playback.stop,
              icon: const Icon(Icons.stop),
              label: Text(l10n.stop),
            ),
          ),
        ),
      ],
    );
  }

  Widget _done(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.spa_outlined,
                size: 72, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(l10n.breatheDone,
                textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
            const SizedBox(height: 24),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: _start,
                  icon: const Icon(Icons.replay),
                  label: Text(l10n.breatheAgain),
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
}
