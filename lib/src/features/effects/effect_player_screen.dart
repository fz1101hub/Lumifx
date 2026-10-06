import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/effects/effect.dart';
import '../../core/effects/engine/effect_player.dart';
import '../../core/effects/engine/effect_renderer.dart';
import '../../core/effects/engine/light_frame.dart';
import '../../core/effects/engine/light_output.dart';
import '../../core/hue/hue_bridge_client.dart';
import '../../core/hue/hue_models.dart';
import 'light_color_ui.dart';

/// Lamps shown when playing without a bridge.
const _previewLightCount = 5;

class EffectPlayerScreen extends StatefulWidget {
  const EffectPlayerScreen({required this.effect, super.key});

  final LightingEffect effect;

  @override
  State<EffectPlayerScreen> createState() => _EffectPlayerScreenState();
}

class _EffectPlayerScreenState extends State<EffectPlayerScreen> {
  EffectPlayer? _player;
  String? _targetId;
  EffectControls _controls = const EffectControls();

  @override
  void dispose() {
    _player?.stop();
    super.dispose();
  }

  /// The selected room or zone, looked up fresh because the bridge
  /// snapshot is replaced on every refresh.
  HueGroup? get _target {
    final bridge = AppScope.of(context).bridge;
    final groups = bridge.isConnected ? bridge.home?.groups : null;
    return groups?.where((g) => g.id == _targetId).firstOrNull;
  }

  List<String> _lightNames(HueHome? home) {
    final target = _target;
    if (target == null || home == null) {
      return [for (var i = 1; i <= _previewLightCount; i++) 'Lamp $i'];
    }
    return [for (final id in target.lightIds) home.lights[id]?.name ?? id];
  }

  Future<void> _togglePlayback() async {
    final player = _player;
    if (player != null && player.state == PlaybackState.playing) {
      player.pause();
      setState(() {});
      return;
    }
    if (player != null && player.state == PlaybackState.paused) {
      player.play();
      setState(() {});
      return;
    }
    _start();
  }

  void _start() {
    final bridge = AppScope.of(context).bridge;
    final client = bridge.client;
    final target = _target;

    final List<String> lightIds;
    final LightOutput output;
    if (target != null && target.lightIds.isNotEmpty && client != null) {
      lightIds = target.lightIds;
      output = hueRestOutput(client);
    } else {
      lightIds = [for (var i = 0; i < _previewLightCount; i++) 'preview-$i'];
      output = const NullLightOutput();
    }

    final player = EffectPlayer(
      effect: widget.effect,
      lightIds: lightIds,
      output: output,
      seed: DateTime.now().millisecondsSinceEpoch & 0x7FFFFFFF,
      controls: _controls,
    )..play();
    setState(() => _player = player);
  }

  Future<void> _changeTarget(String? targetId) async {
    final previous = _player;
    final wasPlaying = previous?.state == PlaybackState.playing;
    setState(() {
      _targetId = targetId;
      _player = null;
    });
    await previous?.stop();
    if (wasPlaying && mounted) {
      _start();
    }
  }

  void _updateControls(EffectControls controls) {
    setState(() => _controls = controls);
    _player?.controls = controls;
  }

  @override
  Widget build(BuildContext context) {
    final bridge = AppScope.of(context).bridge;
    final home = bridge.isConnected ? bridge.home : null;
    final groups = home?.groups.where((g) => g.lightIds.isNotEmpty).toList() ??
        const <HueGroup>[];
    final player = _player;
    final isPlaying = player?.state == PlaybackState.playing;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(widget.effect.name)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (widget.effect.description.isNotEmpty)
            Text(widget.effect.description, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 20),
          DropdownButtonFormField<String?>(
            initialValue: _target?.id,
            decoration: const InputDecoration(
              labelText: 'Play on',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('Preview only')),
              for (final group in groups)
                DropdownMenuItem(
                  value: group.id,
                  child: Text(
                    '${group.name} · ${group.lightIds.length} '
                    '${group.lightIds.length == 1 ? 'light' : 'lights'}',
                  ),
                ),
            ],
            onChanged: _changeTarget,
          ),
          const SizedBox(height: 24),
          _LampPreview(player: player, names: _lightNames(home)),
          const SizedBox(height: 24),
          Center(
            child: FilledButton.icon(
              onPressed: _togglePlayback,
              icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
              label: Text(isPlaying ? 'Pause' : 'Play'),
            ),
          ),
          const SizedBox(height: 24),
          _ControlSlider(
            label: 'Brightness',
            value: _controls.brightness,
            onChanged: (v) =>
                _updateControls(_controls.copyWith(brightness: v)),
          ),
          _ControlSlider(
            label: 'Intensity',
            value: _controls.intensity,
            onChanged: (v) => _updateControls(_controls.copyWith(intensity: v)),
          ),
          _ControlSlider(
            label: 'Speed',
            value: _controls.speed,
            min: 0.25,
            max: 3,
            onChanged: (v) => _updateControls(_controls.copyWith(speed: v)),
          ),
        ],
      ),
    );
  }
}

/// Sends frames to Hue lights through the REST API.
LightOutput hueRestOutput(HueBridgeClient client) {
  return RateLimitedLightOutput(
    send: (lightId, frame, transition) => client.setLight(
      lightId,
      HueLightCommand.fromColor(
        frame.color,
        frame.brightness,
        transition: transition,
      ),
    ),
  );
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
          child: Slider(value: value, min: min, max: max, onChanged: onChanged),
        ),
      ],
    );
  }
}
