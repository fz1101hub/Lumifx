import 'dart:async';

import '../../audio/audio_analyzer.dart';
import '../effect.dart';
import 'effect_renderer.dart';
import 'light_frame.dart';
import 'light_output.dart';

enum PlaybackState { stopped, playing, paused }

/// Plays an effect on an ordered list of lights.
///
/// The order of [lightIds] is the spatial order the effect moves through.
/// Effect time advances by real time multiplied by the speed control, so
/// changing speed never makes the timeline jump.
class EffectPlayer {
  EffectPlayer({
    required LightingEffect effect,
    required this.lightIds,
    required this.output,
    int seed = 0,
    EffectControls controls = const EffectControls(),
    this.tick = const Duration(milliseconds: 100),
    this.audio,
  })  : assert(lightIds.isNotEmpty),
        _renderer = EffectRenderer(
          effect,
          slotCount: lightIds.length,
          seed: seed,
          controls: controls,
        );

  final List<String> lightIds;
  final LightOutput output;
  final Duration tick;

  /// Latest live audio features, read on every tick; null without Music Sync.
  final AudioFeatures? Function()? audio;
  final EffectRenderer _renderer;

  final _frames = StreamController<List<LightFrame>>.broadcast();
  Timer? _timer;
  Stopwatch? _stopwatch;
  Duration _lastWallTime = Duration.zero;
  Duration _effectTime = Duration.zero;
  PlaybackState _state = PlaybackState.stopped;
  List<LightFrame> _current = const [];

  LightingEffect get effect => _renderer.effect;
  PlaybackState get state => _state;
  Duration get position => _effectTime;
  List<LightFrame> get currentFrames => _current;

  /// Emits the frames rendered on every tick.
  Stream<List<LightFrame>> get frames => _frames.stream;

  EffectControls get controls => _renderer.controls;
  set controls(EffectControls value) => _renderer.controls = value;

  void play() {
    if (_state == PlaybackState.playing) {
      return;
    }
    _state = PlaybackState.playing;
    _stopwatch = Stopwatch()..start();
    _lastWallTime = Duration.zero;
    _timer = Timer.periodic(tick, (_) {
      final now = _stopwatch!.elapsed;
      advance(now - _lastWallTime);
      _lastWallTime = now;
    });
    advance(Duration.zero);
  }

  void pause() {
    if (_state != PlaybackState.playing) {
      return;
    }
    _state = PlaybackState.paused;
    _stopTimer();
  }

  Future<void> stop() async {
    _state = PlaybackState.stopped;
    _stopTimer();
    await output.close();
    await _frames.close();
  }

  /// Moves the effect forward by [wallTime] of real time and renders.
  /// Called by the internal timer; public so tests can drive time.
  void advance(Duration wallTime) {
    final speed = controls.speed.clamp(0.05, 5.0);
    _effectTime += wallTime * speed;
    _current = _renderer.render(_effectTime, audio: audio?.call());
    output.update(
      {for (var i = 0; i < lightIds.length; i++) lightIds[i]: _current[i]},
      wallTime == Duration.zero ? tick : wallTime,
    );
    if (!_frames.isClosed) {
      _frames.add(_current);
    }
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
    _stopwatch?.stop();
  }
}
