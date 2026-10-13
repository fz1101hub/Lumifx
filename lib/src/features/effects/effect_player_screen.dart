import 'dart:async';

import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/effects/effect.dart';
import '../../core/effects/engine/effect_player.dart';
import '../../core/effects/engine/light_frame.dart';
import '../../core/screen_wake.dart';
import '../entertainment/entertainment_area_editor.dart';
import '../music/music_sync_controller.dart';
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
  StreamSubscription<String>? _messages;

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
        screenWake: widget.screenWake,
      );
      _messages = controller.messages.listen((message) {
        if (mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(message)));
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
    _messages?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _createArea() async {
    await Navigator.of(context).push(
      MaterialPageRoute<bool>(builder: (_) => const EntertainmentAreaEditor()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.effect.name),
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
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (widget.effect.description.isNotEmpty)
                Text(widget.effect.description,
                    style: theme.textTheme.bodyLarge),
              const SizedBox(height: 20),
              DropdownButtonFormField<String?>(
                // Rebuilt when the available targets change, so the field
                // never holds a value that is no longer in the list.
                key: ValueKey(Object.hashAll(targetKeys)),
                initialValue: c.selectedTarget,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Play on',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(
                      value: null, child: Text('Preview only')),
                  for (final area in areas)
                    DropdownMenuItem(
                      value: 'area:${area.id}',
                      child: _TargetLabel(
                        icon: Icons.bolt,
                        text: '${area.name} · streaming',
                      ),
                    ),
                  for (final group in groups)
                    DropdownMenuItem(
                      value: 'group:${group.id}',
                      child: _TargetLabel(
                        icon: Icons.meeting_room_outlined,
                        text: '${group.name} · ${group.lightIds.length} '
                            '${group.lightIds.length == 1 ? 'light' : 'lights'}',
                      ),
                    ),
                ],
                onChanged: busy ? null : c.changeTarget,
              ),
              if (widget.effect.prefersStreaming && c.group != null) ...[
                const SizedBox(height: 8),
                Text(
                  'This effect is very fast. Rooms update a few times per '
                  'second, so pick an entertainment area for the full effect.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
              if (c.home != null && areas.isEmpty)
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'For fast effects, stream to an entertainment area.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    TextButton(
                      onPressed: busy ? null : _createArea,
                      child: const Text('Create area'),
                    ),
                  ],
                ),
              const SizedBox(height: 24),
              _LampPreview(player: c.player, names: c.lightNames),
              if (widget.effect.usesMicrophone) ...[
                const SizedBox(height: 16),
                _MusicMeter(player: c.player, music: c.music),
              ],
              const SizedBox(height: 24),
              Center(
                child: Wrap(
                  spacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FilledButton.icon(
                      onPressed: busy ? null : c.toggle,
                      icon: busy
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(c.isPlaying ? Icons.pause : Icons.play_arrow),
                      label: Text(busy
                          ? 'Connecting…'
                          : c.isPlaying
                              ? 'Pause'
                              : 'Play'),
                    ),
                    if (c.status == PlaybackStatus.playing ||
                        c.status == PlaybackStatus.paused)
                      OutlinedButton.icon(
                        onPressed: c.stop,
                        icon: const Icon(Icons.stop),
                        label: const Text('Stop'),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _ControlSlider(
                label: 'Brightness',
                value: controls.brightness,
                onChanged: (v) =>
                    c.setControls(controls.copyWith(brightness: v)),
              ),
              _ControlSlider(
                label: 'Intensity',
                value: controls.intensity,
                onChanged: (v) =>
                    c.setControls(controls.copyWith(intensity: v)),
              ),
              if (widget.effect.usesMicrophone)
                _ControlSlider(
                  label: 'Sensitivity',
                  value: c.sensitivity,
                  min: 0.5,
                  max: 2.5,
                  onChanged: c.setSensitivity,
                )
              else
                _ControlSlider(
                  label: 'Speed',
                  value: controls.speed,
                  min: 0.25,
                  max: 3,
                  onChanged: (v) => c.setControls(controls.copyWith(speed: v)),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Live bass / mid / treble levels, a beat light and the tempo.
class _MusicMeter extends StatelessWidget {
  const _MusicMeter({required this.player, required this.music});

  final EffectPlayer? player;
  final MusicSyncController? music;

  @override
  Widget build(BuildContext context) {
    final player = this.player;
    final music = this.music;
    final theme = Theme.of(context);
    if (player == null || music == null || !music.isListening) {
      return Row(
        children: [
          const Icon(Icons.mic_none, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Press Play and LumiFX will listen to the music in the room. '
              'Audio is analysed on your phone and never recorded.',
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
            Icon(Icons.mic, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            for (final (label, value) in [
              ('Bass', f.bass),
              ('Mid', f.mid),
              ('Treble', f.treble),
            ])
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: theme.textTheme.labelSmall),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(value: value),
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
                f.bpm == null ? 'Listening' : '${f.bpm!.round()} BPM',
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
        return IconButton(
          tooltip: favorite ? 'Remove from favorites' : 'Add to favorites',
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
        SizedBox(width: 88, child: Text(label)),
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
