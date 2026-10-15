import 'dart:async';

import '../../audio/audio_analyzer.dart';
import '../../color/light_color.dart';
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
  }) : _renderer = EffectRenderer(
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

  /// Limits how fast each light may change, so lightning and beats become
  /// soft pulses instead of flashes (for photosensitive users).
  bool softFlashes = false;

  /// Largest brightness change per second with [softFlashes] on: the full
  /// range takes 400 ms, far slower than any flash in the catalog.
  static const softFlashRate = 2.5;

  final _frames = StreamController<List<LightFrame>>.broadcast();
  List<LightFrame>? _shown;
  Timer? _timer;
  Stopwatch? _stopwatch;
  Duration _lastWallTime = Duration.zero;
  Duration _effectTime = Duration.zero;
  PlaybackState _state = PlaybackState.stopped;
  bool _disposed = false;
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
    if (_state == PlaybackState.playing || _disposed) {
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

  /// Stops for good: the output is closed and play() becomes a no-op.
  Future<void> stop() async {
    _state = PlaybackState.stopped;
    _disposed = true;
    _stopTimer();
    await output.close();
    await _frames.close();
  }

  /// Moves the effect forward by [wallTime] of real time and renders.
  /// Called by the internal timer; public so tests can drive time.
  void advance(Duration wallTime) {
    if (_disposed) {
      return;
    }
    final speed = controls.speed.clamp(0.05, 5.0);
    _effectTime += wallTime * speed;
    final rendered = _renderer.render(_effectTime, audio: audio?.call());
    final step = wallTime == Duration.zero ? tick : wallTime;
    _current = softFlashes
        ? softenFrames(_shown, rendered, step.inMicroseconds / 1e6)
        : rendered;
    _shown = _current;
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

/// Moves each light from [previous] towards [target] by at most
/// [maxRate] (brightness units per second) times [seconds]. The colour
/// follows the same fraction of the way, so a white strike on a dark blue
/// background cannot jump in perceived brightness either. With no
/// [previous] frame the target is shown as is.
List<LightFrame> softenFrames(
  List<LightFrame>? previous,
  List<LightFrame> target,
  double seconds, {
  double maxRate = EffectPlayer.softFlashRate,
}) {
  if (previous == null || previous.length != target.length) {
    return target;
  }
  final maxStep = maxRate * seconds;
  return [
    for (var i = 0; i < target.length; i++)
      _approach(previous[i], target[i], maxStep),
  ];
}

LightFrame _approach(LightFrame from, LightFrame to, double maxStep) {
  final delta = to.brightness - from.brightness;
  if (delta.abs() <= maxStep) {
    return to;
  }
  final fraction = maxStep / delta.abs();
  LightColor lerp(LightColor a, LightColor b) => LightColor(
        a.r + (b.r - a.r) * fraction,
        a.g + (b.g - a.g) * fraction,
        a.b + (b.b - a.b) * fraction,
      );
  return LightFrame(
    lerp(from.color, to.color),
    from.brightness + delta.sign * maxStep,
  );
}
