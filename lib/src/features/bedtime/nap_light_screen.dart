import 'dart:async';

import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/effects/engine/light_frame.dart';
import '../common/app_text.dart';
import '../common/layout.dart';
import '../effects/light_color_ui.dart';
import '../effects/playback_controller.dart';
import 'nap_light.dart';

/// The nap light: choose how long the rest lasts; the lamps glow faint
/// amber, then turn green when it is time to get up.
class NapLightScreen extends StatefulWidget {
  const NapLightScreen({super.key});

  @override
  State<NapLightScreen> createState() => _NapLightScreenState();
}

class _NapLightScreenState extends State<NapLightScreen> {
  int? _chosen;

  /// The rest chosen here, else last time, else an hour.
  int get _minutes {
    final saved = AppScope.of(context).preferences.napMinutes;
    return _chosen ?? (NapLight.choices.contains(saved) ? saved! : 60);
  }

  Future<void> _start() async {
    final playback = AppScope.of(context).playback;
    // A sleep timer left by a lullaby would switch the lamps off before
    // they turn green.
    playback.setSleepTimer(null);
    await playback.switchEffect(
        NapLight.effect(context.l10n.napLight, Duration(minutes: _minutes)));
    if (playback.status == PlaybackStatus.idle) {
      await playback.start();
    } else if (playback.status == PlaybackStatus.paused) {
      await playback.resume();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final playback = AppScope.of(context).playback;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.napLight)),
      body: ListenableBuilder(
        listenable: playback,
        builder: (context, _) {
          final player = playback.player;
          final rest = NapLight.restOf(playback.effect);
          if (rest != null &&
              player != null &&
              playback.status != PlaybackStatus.idle) {
            return StreamBuilder<List<LightFrame>>(
              stream: player.frames,
              builder: (context, _) => _running(context, rest),
            );
          }
          return ListView(
            padding: context.pageInsets(),
            children: [
              Text(l10n.napDescription, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 16),
              Text(l10n.napHowLong, style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final minutes in NapLight.choices)
                    ChoiceChip(
                      label: Text(l10n.sleepTimerMinutes(minutes)),
                      selected: _minutes == minutes,
                      onSelected: (_) {
                        setState(() => _chosen = minutes);
                        unawaited(AppScope.of(context)
                            .preferences
                            .setNapMinutes(minutes));
                      },
                    ),
                ],
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56)),
                onPressed: _start,
                icon: const Icon(Icons.bedtime_outlined),
                label: Text(l10n.napStart),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _running(BuildContext context, Duration rest) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final playback = AppScope.of(context).playback;
    final player = playback.player!;
    final speed = playback.effectiveSpeed.clamp(0.05, 5.0);
    final left = rest - player.position;
    final over = left <= Duration.zero;
    final minutes = over ? 0 : (left.inSeconds / 60 / speed).ceil();
    final frame = player.currentFrames.firstOrNull;
    return ListView(
      padding: context.pageInsets(),
      children: [
        const SizedBox(height: 24),
        Center(
          child: Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: frame?.toDisplayColor() ?? Colors.black,
            ),
            alignment: Alignment.center,
            child: Icon(
              over ? Icons.wb_sunny_outlined : Icons.bedtime_outlined,
              size: 64,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Semantics(
          liveRegion: true,
          child: Text(
            over ? l10n.napOver : l10n.napResting,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
          ),
        ),
        if (!over) ...[
          const SizedBox(height: 8),
          Text(
            l10n.napGreenIn(minutes),
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
