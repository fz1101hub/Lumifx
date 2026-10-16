import 'dart:async';

import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/audio/audio_input.dart';
import '../../core/color/light_color.dart';
import '../../core/effects/effect.dart';
import '../../core/effects/engine/effect_player.dart';
import '../../core/effects/engine/light_frame.dart';
import '../../core/screen_wake.dart';
import '../common/app_text.dart';
import '../common/layout.dart';
import '../entertainment/entertainment_area_editor.dart';
import '../music/music_sync_controller.dart';
import 'effect_palette.dart';
import 'light_color_ui.dart';
import 'playback_controller.dart';

class EffectPlayerScreen extends StatefulWidget {
  const EffectPlayerScreen({
    required this.effect,
    this.screenWake = const WakelockScreenWake(),
    super.key,
  });

  final LightingEffect effect;
  final ScreenWake screenWake;

  @override
  State<EffectPlayerScreen> createState() => _EffectPlayerScreenState();
}

class _EffectPlayerScreenState extends State<EffectPlayerScreen>
    with WidgetsBindingObserver {
  PlaybackController? _controller;
  StreamSubscription<PlaybackNotice>? _notices;

  PlaybackController get controller => _controller!;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller == null) {
      final scope = AppScope.of(context);
      _controller = PlaybackController(
        effect: widget.effect,
        bridge: scope.bridge,
        preferences: scope.preferences,
        audioInput: scope.audioInput,
        phoneAudioInput: scope.phoneAudioInput,
        screenWake: widget.screenWake,
      );
      _notices = controller.notices.listen((notice) {
        if (mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(
              content: Text(describePlaybackNotice(context.l10n, notice)),
            ));
        }
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      controller.handleAppPaused();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notices?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _createArea() async {
    await Navigator.of(context).push(
      MaterialPageRoute<bool>(builder: (_) => const EntertainmentAreaEditor()),
    );
  }

  static const _sleepOptions = [15, 30, 45, 60, 90];

  Future<void> _chooseSleepTimer() async {
    final l10n = context.l10n;
    final current = controller.sleepTimer?.inMinutes ?? 0;
    final minutes = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l10n.sleepTimer),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(
              l10n.sleepTimerDescription,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          for (final option in [0, ..._sleepOptions])
            ListTile(
              leading: Icon(option == current
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off),
              title: Text(option == 0
                  ? l10n.sleepTimerOff
                  : l10n.sleepTimerMinutes(option)),
              onTap: () => Navigator.of(context).pop(option),
            ),
        ],
      ),
    );
    if (minutes != null) {
      controller
          .setSleepTimer(minutes == 0 ? null : Duration(minutes: minutes));
    }
  }

  String _sleepLabel(AppLocalizations l10n, PlaybackController c) {
    if (c.isFadingOut) {
      return l10n.sleepTimerFading;
    }
    final remaining = c.sleepRemaining;
    if (remaining != null) {
      // Round up, so "1 minute" is shown until the lights actually go out.
      return l10n.sleepTimerRemaining((remaining.inSeconds / 60).ceil());
    }
    final timer = c.sleepTimer;
    return timer == null
        ? l10n.sleepTimer
        : l10n.sleepTimerMinutes(timer.inMinutes);
  }

  /// Play/pause, with a one-time warning before the first effect that
  /// flashes. Nothing plays until the user has chosen.
  Future<void> _toggle() async {
    final c = controller;
    final preferences = AppScope.of(context).preferences;
    if (c.status == PlaybackStatus.idle &&
        widget.effect.hasRapidFlashes &&
        !preferences.flashWarningShown) {
      final soften = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _FlashWarningDialog(),
      );
      if (!mounted || soften == null) {
        return;
      }
      unawaited(preferences.setFlashWarningShown(true));
      if (soften) {
        unawaited(preferences.setSoftFlashes(true));
      }
    }
    await c.toggle();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final description = l10n.effectDescription(widget.effect);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.effectName(widget.effect)),
        actions: [_FavoriteButton(effectId: widget.effect.id)],
      ),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final c = controller;
          final busy = c.isBusy;
          final groups = c.groups;
          final areas = c.areas;
          final targetKeys = [
            for (final area in areas) 'area:${area.id}',
            for (final group in groups) 'group:${group.id}',
          ];
          final controls = c.controls;
          // What to play and where (setup) and the lamps with the
          // transport and sliders (stage): one column on a phone, two
          // panes side by side on a tablet.
          final setup = <Widget>[
            if (description.isNotEmpty)
              Text(description, style: theme.textTheme.bodyLarge),
            if (widget.effect.variants.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  _VariantChip(
                    label: l10n.variantClassic,
                    colors: effectPalette(widget.effect),
                    selected: c.variantId == null,
                    onSelected: () => c.setVariant(null),
                  ),
                  for (final variant in widget.effect.variants)
                    _VariantChip(
                      label: l10n.variantName(variant),
                      colors: [
                        for (final hex in variant.palette)
                          LightColor.fromHex(hex).toColor(),
                      ],
                      selected: c.variantId == variant.id,
                      onSelected: () => c.setVariant(variant.id),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            DropdownButtonFormField<String?>(
              // Rebuilt when the available targets change, so the field
              // never holds a value that is no longer in the list.
              key: ValueKey(Object.hashAll(targetKeys)),
              initialValue: c.selectedTarget,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: l10n.playOn,
                border: const OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem(value: null, child: Text(l10n.previewOnly)),
                for (final area in areas)
                  DropdownMenuItem(
                    value: 'area:${area.id}',
                    child: _TargetLabel(
                      icon: Icons.bolt,
                      text: l10n.targetStreaming(area.name),
                    ),
                  ),
                for (final group in groups)
                  DropdownMenuItem(
                    value: 'group:${group.id}',
                    child: _TargetLabel(
                      icon: Icons.meeting_room_outlined,
                      text: l10n.targetGroup(group.name, group.lightIds.length),
                    ),
                  ),
              ],
              onChanged: busy ? null : c.changeTarget,
            ),
            if (c.bridgeUnreachable) ...[
              const SizedBox(height: 8),
              Text(
                l10n.playerBridgeUnreachable,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.error),
              ),
            ],
            if (c.streamingUnavailable) ...[
              const SizedBox(height: 8),
              Text(
                l10n.playerStreamingUnavailable,
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (widget.effect.prefersStreaming && c.group != null) ...[
              const SizedBox(height: 8),
              Text(
                l10n.playerPrefersStreaming,
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (c.groupLights.length > 1) ...[
              const SizedBox(height: 12),
              Text(l10n.lightsToPlay, style: theme.textTheme.labelMedium),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final entry in c.groupLights)
                    FilterChip(
                      label: Text(entry.light.name),
                      selected: entry.enabled,
                      onSelected:
                          busy ? null : (_) => c.toggleLight(entry.light.id),
                    ),
                ],
              ),
            ],
            if (c.home != null && !c.streamingUnavailable && areas.isEmpty)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.playerCreateAreaHint,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  TextButton(
                    onPressed: busy ? null : _createArea,
                    child: Text(l10n.createArea),
                  ),
                ],
              ),
          ];
          final stage = <Widget>[
            _LampPreview(
              player: c.player,
              names: [
                for (final slot in c.lightNames) describeSlot(l10n, slot),
              ],
            ),
            if (widget.effect.usesMicrophone) ...[
              const SizedBox(height: 16),
              _MusicMeter(
                player: c.player,
                music: c.music,
                source: c.musicSource,
              ),
            ],
            const SizedBox(height: 24),
            Center(
              child: Wrap(
                spacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: busy ? null : _toggle,
                    icon: busy
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(c.isPlaying ? Icons.pause : Icons.play_arrow),
                    label: Text(busy
                        ? l10n.connecting
                        : c.isPlaying
                            ? l10n.pause
                            : l10n.play),
                  ),
                  if (c.status == PlaybackStatus.playing ||
                      c.status == PlaybackStatus.paused)
                    OutlinedButton.icon(
                      onPressed: c.stop,
                      icon: const Icon(Icons.stop),
                      label: Text(l10n.stop),
                    ),
                  OutlinedButton.icon(
                    onPressed: busy || c.isFadingOut ? null : _chooseSleepTimer,
                    icon: Icon(c.sleepTimer == null
                        ? Icons.bedtime_outlined
                        : Icons.bedtime),
                    label: Text(_sleepLabel(l10n, c)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _ControlSlider(
              label: l10n.brightness,
              value: controls.brightness,
              onChanged: (v) => c.setControls(controls.copyWith(brightness: v)),
            ),
            _ControlSlider(
              label: l10n.intensity,
              value: controls.intensity,
              onChanged: (v) => c.setControls(controls.copyWith(intensity: v)),
            ),
            if (widget.effect.usesMicrophone)
              _ControlSlider(
                label: l10n.sensitivity,
                value: c.sensitivity,
                min: 0.5,
                max: 2.5,
                onChanged: c.setSensitivity,
              )
            else
              _ControlSlider(
                label: l10n.speed,
                value: controls.speed,
                min: 0.25,
                max: 3,
                onChanged: (v) => c.setControls(controls.copyWith(speed: v)),
              ),
          ];
          if (context.isWide) {
            return ListView(
              padding: context.pageInsets(maxWidth: 1100),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: setup,
                      ),
                    ),
                    const SizedBox(width: 32),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [const SizedBox(height: 8), ...stage],
                      ),
                    ),
                  ],
                ),
              ],
            );
          }
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [...setup, const SizedBox(height: 24), ...stage],
          );
        },
      ),
    );
  }
}

/// A colour variant: a swatch of its palette and its name.
class _VariantChip extends StatelessWidget {
  const _VariantChip({
    required this.label,
    required this.colors,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final List<Color> colors;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      avatar: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: SweepGradient(
            colors: colors.length > 1
                ? [...colors, colors.first]
                : [...colors, ...colors],
          ),
        ),
      ),
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
    );
  }
}

/// Shown once before the first effect with lightning or beats.
class _FlashWarningDialog extends StatelessWidget {
  const _FlashWarningDialog();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      icon: const Icon(Icons.flash_on_outlined),
      title: Text(l10n.photosensitivityTitle),
      content: Text(l10n.photosensitivityBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.softenFlashes),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.continueAction),
        ),
      ],
    );
  }
}

/// Live bass / mid / treble levels, a beat light and the tempo.
class _MusicMeter extends StatelessWidget {
  const _MusicMeter({
    required this.player,
    required this.music,
    required this.source,
  });

  final EffectPlayer? player;
  final MusicSyncController? music;
  final MusicSource source;

  @override
  Widget build(BuildContext context) {
    final player = this.player;
    final music = this.music;
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final phoneAudio = source == MusicSource.phoneAudio;
    if (player == null || music == null || !music.isListening) {
      return Row(
        children: [
          Icon(phoneAudio ? Icons.phone_android : Icons.mic_none, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              phoneAudio ? l10n.musicSyncHintPhoneAudio : l10n.musicSyncHint,
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      );
    }
    // Repaint with the player's frames, which already run at tick rate.
    return StreamBuilder<List<LightFrame>>(
      stream: player.frames,
      builder: (context, _) {
        final f = music.features;
        final onBeat = f.secondsSinceBeat < 0.12;
        return Row(
          children: [
            Icon(
              phoneAudio ? Icons.phone_android : Icons.mic,
              size: 20,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 12),
            for (final (label, value) in [
              (l10n.bass, f.bass),
              (l10n.mid, f.mid),
              (l10n.treble, f.treble),
            ])
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: theme.textTheme.labelSmall),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: value,
                        semanticsLabel: label,
                        semanticsValue: '${(value * 100).round()}%',
                      ),
                    ],
                  ),
                ),
              ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 80),
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: onBeat
                    ? theme.colorScheme.primary
                    : theme.colorScheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 64,
              child: Text(
                f.bpm == null ? l10n.listening : l10n.bpm(f.bpm!.round()),
                style: theme.textTheme.labelMedium,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _FavoriteButton extends StatelessWidget {
  const _FavoriteButton({required this.effectId});

  final String effectId;

  @override
  Widget build(BuildContext context) {
    final preferences = AppScope.of(context).preferences;
    return ListenableBuilder(
      listenable: preferences,
      builder: (context, _) {
        final favorite = preferences.isFavorite(effectId);
        final l10n = context.l10n;
        return IconButton(
          tooltip: favorite ? l10n.removeFromFavorites : l10n.addToFavorites,
          icon: Icon(favorite ? Icons.star : Icons.star_border),
          onPressed: () => preferences.toggleFavorite(effectId),
        );
      },
    );
  }
}

class _TargetLabel extends StatelessWidget {
  const _TargetLabel({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 8),
        Flexible(child: Text(text, overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}

class _LampPreview extends StatelessWidget {
  const _LampPreview({required this.player, required this.names});

  final EffectPlayer? player;
  final List<String> names;

  @override
  Widget build(BuildContext context) {
    final player = this.player;
    if (player == null) {
      return _lamps(context, List.filled(names.length, LightFrame.off));
    }
    return StreamBuilder<List<LightFrame>>(
      stream: player.frames,
      initialData: player.currentFrames,
      builder: (context, snapshot) {
        final frames = snapshot.data ?? const <LightFrame>[];
        return _lamps(
          context,
          frames.length == names.length
              ? frames
              : List.filled(names.length, LightFrame.off),
        );
      },
    );
  }

  Widget _lamps(BuildContext context, List<LightFrame> frames) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 16,
      runSpacing: 16,
      children: [
        for (var i = 0; i < frames.length; i++)
          SizedBox(
            width: 64,
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: frames[i].toDisplayColor(),
                    border: Border.all(color: Colors.white24),
                    boxShadow: [
                      BoxShadow(
                        color: frames[i]
                            .color
                            .toColor()
                            .withValues(alpha: frames[i].brightness * 0.8),
                        blurRadius: 24 * frames[i].brightness,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  names[i],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ControlSlider extends StatelessWidget {
  const _ControlSlider({
    required this.label,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 1,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: MediaQuery.textScalerOf(context).scale(88),
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
