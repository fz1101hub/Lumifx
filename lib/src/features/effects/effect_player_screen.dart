import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/effects/effect.dart';
import '../../core/effects/engine/effect_player.dart';
import '../../core/effects/engine/effect_renderer.dart';
import '../../core/effects/engine/light_frame.dart';
import '../../core/effects/engine/light_output.dart';
import '../../core/hue/entertainment/dtls/dtls_client.dart';
import '../../core/hue/entertainment/entertainment_session.dart';
import '../../core/hue/hue_bridge_client.dart';
import '../../core/hue/hue_exceptions.dart';
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

  /// `group:<id>`, `area:<id>`, or null for the preview.
  String? _targetKey;
  EffectControls _controls = const EffectControls();
  bool _starting = false;

  @override
  void dispose() {
    _player?.stop();
    super.dispose();
  }

  HueHome? get _home {
    final bridge = AppScope.of(context).bridge;
    return bridge.isConnected ? bridge.home : null;
  }

  /// The selected room or zone, looked up fresh because the bridge
  /// snapshot is replaced on every refresh.
  HueGroup? get _group =>
      _home?.groups.where((g) => _targetKey == 'group:${g.id}').firstOrNull;

  HueEntertainmentArea? get _area => _home?.entertainmentAreas
      .where((a) => _targetKey == 'area:${a.id}')
      .firstOrNull;

  List<String> _lightNames() {
    final home = _home;
    final group = _group;
    final area = _area;
    if (home != null && group != null) {
      return [for (final id in group.lightIds) home.lights[id]?.name ?? id];
    }
    if (home != null && area != null) {
      return [
        for (final channel in area.spatialChannels)
          channel.lightIds.isEmpty
              ? 'Channel ${channel.id}'
              : channel.lightIds
                  .map((id) => home.lights[id]?.name ?? id)
                  .join(' / '),
      ];
    }
    return [for (var i = 1; i <= _previewLightCount; i++) 'Lamp $i'];
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
    await _start();
  }

  Future<void> _start() async {
    final bridge = AppScope.of(context).bridge;
    final client = bridge.client;
    final group = _group;
    final area = _area;

    var lightIds = [for (var i = 0; i < _previewLightCount; i++) 'preview-$i'];
    LightOutput output = const NullLightOutput();
    var tick = const Duration(milliseconds: 100);

    if (area != null) {
      setState(() => _starting = true);
      try {
        final streaming = await bridge.openEntertainment(area);
        if (!mounted) {
          await streaming.close();
          return;
        }
        output = streaming;
        lightIds = entertainmentSlotIds(area);
        // Hue recommends 50-60 messages per second; the bridge forwards
        // them to the lights at 25 Hz.
        tick = const Duration(milliseconds: 20);
        // Any end we did not ask for (alert, close_notify, another app
        // taking over the area) stops playback.
        streaming.session.done
            .catchError((Object _) {})
            .whenComplete(() => _onStreamEnded(streaming));
      } on Object catch (error) {
        if (mounted) {
          _showError('Could not start streaming: ${_describe(error)}');
        }
        return;
      } finally {
        if (mounted) {
          setState(() => _starting = false);
        }
      }
    } else if (group != null && group.lightIds.isNotEmpty && client != null) {
      lightIds = group.lightIds;
      output = hueRestOutput(client);
    }

    final player = EffectPlayer(
      effect: widget.effect,
      lightIds: lightIds,
      output: output,
      seed: DateTime.now().millisecondsSinceEpoch & 0x7FFFFFFF,
      controls: _controls,
      tick: tick,
    )..play();
    setState(() => _player = player);
  }

  /// The bridge ended the stream while it was still in use.
  void _onStreamEnded(LightOutput output) {
    final player = _player;
    if (!mounted || player == null || player.output != output) {
      return;
    }
    setState(() => _player = null);
    player.stop();
    _showError('Streaming stopped by the bridge.');
  }

  Future<void> _changeTarget(String? targetKey) async {
    final previous = _player;
    final wasPlaying = previous?.state == PlaybackState.playing;
    setState(() {
      _targetKey = targetKey;
      _player = null;
    });
    await previous?.stop();
    if (wasPlaying && mounted) {
      await _start();
    }
  }

  void _updateControls(EffectControls controls) {
    setState(() => _controls = controls);
    _player?.controls = controls;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  static String _describe(Object error) => switch (error) {
        HueException(:final message) => message,
        DtlsException(:final message) => message,
        _ => 'the bridge did not respond.',
      };

  @override
  Widget build(BuildContext context) {
    final home = _home;
    final groups = home?.groups.where((g) => g.lightIds.isNotEmpty).toList() ??
        const <HueGroup>[];
    final areas =
        home?.entertainmentAreas.where((a) => a.channels.isNotEmpty).toList() ??
            const <HueEntertainmentArea>[];
    final player = _player;
    final isPlaying = player?.state == PlaybackState.playing;
    final theme = Theme.of(context);
    final selectedKey = _group != null || _area != null ? _targetKey : null;

    return Scaffold(
      appBar: AppBar(title: Text(widget.effect.name)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (widget.effect.description.isNotEmpty)
            Text(widget.effect.description, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 20),
          DropdownButtonFormField<String?>(
            initialValue: selectedKey,
            decoration: const InputDecoration(
              labelText: 'Play on',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('Preview only')),
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
            onChanged: _starting ? null : _changeTarget,
          ),
          if (home != null && areas.isEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'For fast effects, create an entertainment area in the Hue app '
              '(Settings › Entertainment areas).',
              style: theme.textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 24),
          _LampPreview(player: player, names: _lightNames()),
          const SizedBox(height: 24),
          Center(
            child: FilledButton.icon(
              onPressed: _starting ? null : _togglePlayback,
              icon: _starting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(isPlaying ? Icons.pause : Icons.play_arrow),
              label: Text(_starting
                  ? 'Connecting…'
                  : isPlaying
                      ? 'Pause'
                      : 'Play'),
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
