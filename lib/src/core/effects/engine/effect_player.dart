import 'dart:async';

import '../../audio/audio_analyzer.dart';
import '../../camera/screen_sampler.dart';
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
    this.screen,
  })  : _seed = seed,
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

  /// Latest colours of the TV, read on every tick; null without TV Sync.
  final ScreenColors? Function()? screen;
  final int _seed;
  EffectRenderer _renderer;

  /// Frames shown when [crossfadeTo] was called, blended out over
  /// [_fadeLength] of wall time.
  List<LightFrame>? _fadeFrom;
  Duration _fadeLength = Duration.zero;
  Duration _fadeElapsed = Duration.zero;

  /// Limits how fast each light may change, so lightning and beats become
  /// soft pulses instead of flashes (for photosensitive users).
  bool softFlashes = false;

  /// Largest brightness change per second with [softFlashes] on: the full
  /// range takes 400 ms, far slower than any flash in the catalog.
  static const softFlashRate = 2.5;

  /// Multiplies every frame's brightness, 0..1; the sleep timer fades it
  /// to 0. Applied after [softFlashes], so a fade is never slowed down.
  double masterLevel = 1;

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

  /// Swaps the effect in place, keeping its time: for a colour variant of
  /// the same effect.
  set effect(LightingEffect value) => _renderer.effect = value;

  /// Fades in from [from] (what the lights show before the effect starts,
  /// one frame per light) over [over], instead of jumping to the effect's
  /// first colours. Call before [play].
  void fadeInFrom(
    List<LightFrame> from, {
    Duration over = const Duration(milliseconds: 2500),
  }) {
    if (from.length != lightIds.length) {
      return;
    }
    _fadeFrom = from;
    _fadeLength = over;
    _fadeElapsed = Duration.zero;
  }

  /// Starts [next] from its beginning, blending from what the lights show
  /// now over [over], so changing effects never drops the room to black
  /// or snaps it to new colours.
  void crossfadeTo(
    LightingEffect next, {
    Duration over = const Duration(milliseconds: 1500),
  }) {
    _fadeFrom = _current.isEmpty ? null : _current;
    _fadeLength = over;
    _fadeElapsed = Duration.zero;
    _renderer = EffectRenderer(
      next,
      slotCount: lightIds.length,
      seed: _seed + 1,
      controls: _renderer.controls,
    );
    _effectTime = Duration.zero;
    _shown = null;
    if (_state == PlaybackState.playing) {
      advance(Duration.zero);
    }
  }

  LightFrame? _flash;
  Duration _flashLength = Duration.zero;
  Duration _flashElapsed = Duration.zero;
  double? _flashAt;

  /// Every light shows [color] at once (or only the one [at] along the
  /// room, 0 the first and 1 the last), over whatever the effect shows,
  /// for [length] of wall time (the last third fading out): a light that
  /// answers a tap. A new flash replaces the one showing.
  void flashNow(
    LightColor color, {
    double brightness = 1,
    Duration length = const Duration(milliseconds: 600),
    double? at,
  }) {
    _flash = LightFrame(color, brightness.clamp(0.0, 1.0));
    _flashAt = at?.clamp(0.0, 1.0);
    _flashLength = length;
    _flashElapsed = Duration.zero;
    if (_state == PlaybackState.playing) {
      advance(Duration.zero);
    }
  }

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
    var rendered = _renderer.render(
      _effectTime,
      audio: audio?.call(),
      screen: screen?.call(),
    );
    final from = _fadeFrom;
    if (from != null && from.length == rendered.length) {
      _fadeElapsed += wallTime;
      final t = _fadeLength <= Duration.zero
          ? 1.0
          : (_fadeElapsed.inMicroseconds / _fadeLength.inMicroseconds)
              .clamp(0.0, 1.0);
      rendered = [
        for (var i = 0; i < rendered.length; i++)
          blendFrames(from[i], rendered[i], t),
      ];
      if (t >= 1) {
        _fadeFrom = null;
      }
    }
    final flash = _flash;
    if (flash != null) {
      _flashElapsed += wallTime;
      final t = _flashLength <= Duration.zero
          ? 1.0
          : _flashElapsed.inMicroseconds / _flashLength.inMicroseconds;
      if (t >= 1) {
        _flash = null;
      } else {
        final alpha = t < 2 / 3 ? 1.0 : (1 - t) * 3;
        final at = _flashAt;
        final only = at == null ? null : (at * (rendered.length - 1)).round();
        rendered = [
          for (final (i, frame) in rendered.indexed)
            only == null || i == only ? frame.blend(flash, alpha) : frame,
        ];
      }
    }
    final step = wallTime == Duration.zero ? tick : wallTime;
    final shown = softFlashes
        ? softenFrames(_shown, rendered, step.inMicroseconds / 1e6)
        : rendered;
    _shown = shown;
    final level = masterLevel.clamp(0.0, 1.0);
    _current = level == 1
        ? shown
        : [for (final f in shown) LightFrame(f.color, f.brightness * level)];
    // No time passed for a flash: the output's budget must not grow.
    output.update(
      {for (var i = 0; i < lightIds.length; i++) lightIds[i]: _current[i]},
      wallTime,
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

/// The frame [t] of the way from [a] to [b] (0..1).
LightFrame blendFrames(LightFrame a, LightFrame b, double t) => LightFrame(
      LightColor(
        a.color.r + (b.color.r - a.color.r) * t,
        a.color.g + (b.color.g - a.color.g) * t,
        a.color.b + (b.color.b - a.color.b) * t,
      ),
      a.brightness + (b.brightness - a.brightness) * t,
    );

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
