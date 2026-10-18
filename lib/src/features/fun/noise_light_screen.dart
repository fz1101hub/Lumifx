import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/audio/audio_input.dart';
import '../../core/color/light_color.dart';
import '../common/app_text.dart';
import '../common/layout.dart';
import '../effects/light_color_ui.dart';
import '../effects/playback_controller.dart';
import 'noise_light.dart';

/// The noise light: the lamps stay green while the room is calm, turn
/// amber when it gets loud and red when it is too loud. It listens only
/// while this screen is open.
class NoiseLightScreen extends StatefulWidget {
  const NoiseLightScreen({super.key});

  @override
  State<NoiseLightScreen> createState() => _NoiseLightScreenState();
}

class _NoiseLightScreenState extends State<NoiseLightScreen> {
  late AudioInput _microphone;
  late PlaybackController _playback;
  var _limit = NoiseLimit.normal;
  NoiseWatch? _watch;
  StreamSubscription<Uint8List>? _listening;
  var _starting = false;
  var _tooLoud = 0;
  var _disposed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = AppScope.of(context);
    _microphone = scope.audioInput;
    _playback = scope.playback;
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_stopListening(stopLights: true));
    super.dispose();
  }

  Future<void> _show(NoiseZone zone) async {
    await _playback.switchEffect(zone.effect(context.l10n.noiseLight));
    if (_playback.status == PlaybackStatus.idle) {
      await _playback.start();
    } else if (_playback.status == PlaybackStatus.paused) {
      await _playback.resume();
    }
  }

  Future<void> _listen() async {
    if (_starting) {
      return;
    }
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _starting = true);
    try {
      if (!await _microphone.requestPermission()) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.noiseMicDenied)));
        return;
      }
      if (!mounted) {
        return;
      }
      final watch = NoiseWatch(
        sampleRate: _microphone.sampleRate,
        limit: _limit,
      );
      await _show(NoiseZone.calm);
      final audio = await _microphone.start();
      if (!mounted) {
        await _microphone.stop();
        return;
      }
      setState(() {
        _watch = watch;
        _tooLoud = 0;
        var shown = watch.level;
        _listening = audio.listen((pcm) {
          final changed = watch.add(pcm);
          if (changed) {
            if (watch.zone == NoiseZone.tooLoud) {
              _tooLoud++;
            }
            unawaited(_show(watch.zone));
          }
          // The meter moves in small steps, not at every buffer.
          if (mounted && (changed || (watch.level - shown).abs() > 0.02)) {
            shown = watch.level;
            setState(() {});
          }
        });
      });
    } on Object catch (error) {
      debugPrint('Noise light microphone: $error');
      messenger.showSnackBar(SnackBar(content: Text(l10n.noiseMicDenied)));
    } finally {
      if (mounted) {
        setState(() => _starting = false);
      }
    }
  }

  Future<void> _stopListening({bool stopLights = false}) async {
    final listening = _listening;
    _listening = null;
    _watch = null;
    if (listening != null) {
      unawaited(listening.cancel());
      await _microphone.stop();
    }
    if (stopLights && NoiseZone.of(_playback.effect) != null) {
      // Not while the screen is being taken down: stopping redraws
      // whatever listens to the player.
      final playback = _playback;
      unawaited(Future.microtask(() {
        if (NoiseZone.of(playback.effect) != null) {
          return playback.stop();
        }
      }));
    }
    if (mounted && !_disposed) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final watch = _watch;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.noiseLight)),
      body: ListView(
        padding: context.pageInsets(),
        children: [
          Text(l10n.noiseDescription, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 16),
          SegmentedButton<NoiseLimit>(
            segments: [
              ButtonSegment(
                value: NoiseLimit.quiet,
                label: Text(l10n.noiseQuiet),
              ),
              ButtonSegment(
                value: NoiseLimit.normal,
                label: Text(l10n.noiseNormal),
              ),
              ButtonSegment(
                value: NoiseLimit.lively,
                label: Text(l10n.noiseLively),
              ),
            ],
            selected: {_limit},
            onSelectionChanged: (selected) => setState(() {
              _limit = selected.first;
              _watch?.limit = _limit;
            }),
          ),
          const SizedBox(height: 24),
          if (watch != null) ...[
            Center(
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: LightColor.fromHex(watch.zone.color).toColor(),
                ),
                child: Icon(
                  switch (watch.zone) {
                    NoiseZone.calm => Icons.sentiment_satisfied_alt,
                    NoiseZone.loud => Icons.sentiment_neutral,
                    NoiseZone.tooLoud => Icons.volume_up,
                  },
                  size: 88,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Semantics(
              liveRegion: true,
              child: Text(
                switch (watch.zone) {
                  NoiseZone.calm => l10n.noiseCalm,
                  NoiseZone.loud => l10n.noiseLoud,
                  NoiseZone.tooLoud => l10n.noiseTooLoud,
                },
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall,
              ),
            ),
            const SizedBox(height: 12),
            ExcludeSemantics(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: watch.level,
                  minHeight: 12,
                  color: LightColor.fromHex(watch.zone.color).toColor(),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.noiseTooLoudTimes(_tooLoud),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => _stopListening(stopLights: true),
              icon: const Icon(Icons.stop),
              label: Text(l10n.stop),
            ),
          ] else
            FilledButton.icon(
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56)),
              onPressed: _starting ? null : _listen,
              icon: const Icon(Icons.mic_none),
              label: Text(l10n.noiseStart),
            ),
        ],
      ),
    );
  }
}
