import 'dart:math' as math;
import 'dart:typed_data';

import '../../core/audio/fft.dart';
import '../../core/effects/effect.dart';
import '../../core/effects/effect_event.dart';

/// A sound the lights can tell about.
enum SoundAlert {
  /// A smoke or CO alarm: a loud tone near 3 kHz, beeping.
  smokeAlarm('#FF2020', 1.0),

  /// A doorbell: two clear notes, "ding-dong".
  doorbell('#1F6BFF', 0.5),

  /// A baby crying: bursts of a voice rich in harmonics.
  babyCrying('#FF6FB5', 1.6);

  const SoundAlert(this.color, this.every);

  final String color;

  /// Seconds between the flashes: the doorbell's double knock fastest,
  /// still well below the three a second that can trouble photosensitive
  /// eyes.
  final double every;

  static const _prefix = '${LightingEffect.generatedPrefix}alert:';

  /// How long the lamps tell about it.
  static const shown = Duration(seconds: 20);

  /// The lamps flashing in this alert's colour over a dim glow of it.
  LightingEffect effect(String name) {
    final flashes = (shown.inMilliseconds / (every * 1000)).floor();
    return LightingEffect(
      id: '$_prefix${this.name}',
      name: name,
      kind: EffectKind.interactive,
      isLooping: false,
      loopDuration: shown,
      events: [
        EffectEvent(
          at: Duration.zero,
          duration: shown,
          type: EffectEventTypes.ambientPalette,
          parameters: {
            'palette': [color, color],
            'brightnessMin': 0.3,
            'brightnessMax': 0.4,
            'speed': 0.02,
          },
        ),
        for (var i = 0; i < flashes; i++)
          EffectEvent(
            at: Duration(milliseconds: (i * every * 1000).round()),
            duration:
                Duration(milliseconds: math.min(600, (every * 600).round())),
            type: EffectEventTypes.magicFlash,
            parameters: {'color': color, 'target': 'all', 'brightness': 1.0},
          ),
      ],
    );
  }

  /// The alert an effect shows, or null for any other effect.
  static SoundAlert? of(LightingEffect effect) => effect.id.startsWith(_prefix)
      ? values.asNameMap()[effect.id.substring(_prefix.length)]
      : null;
}

enum _Kind { quiet, other, alarm, chime, cry }

class _Segment {
  _Segment(this.kind, this.start, this.frequency);

  final _Kind kind;
  final double start;
  double end = 0;
  double frequency;
  var frames = 1;

  double get length => end - start;
}

/// Hears smoke alarms, doorbells and a baby crying in the microphone's
/// sound (mono 16-bit PCM), on the phone: each window of about 46 ms is
/// a tone, a voice or neither, and the pattern of those over the last
/// seconds tells which sound it is. Nothing is kept beyond that.
class SoundWatch {
  SoundWatch({required this.sampleRate, Set<SoundAlert>? watching})
      : watching = watching ?? SoundAlert.values.toSet();

  final int sampleRate;

  /// The sounds to tell about.
  Set<SoundAlert> watching;

  static const window = 2048;

  /// After telling about a sound, the same one waits this long.
  static const rest = 30.0;

  final _buffer = Float64List(window);
  var _filled = 0;
  var _odd = -1;
  var _frames = 0;
  final _segments = <_Segment>[];
  _Segment? _run;
  final _told = <SoundAlert, double>{};

  double get _now => _frames * window / sampleRate;

  /// Adds [pcm]; the sounds recognised in it.
  List<SoundAlert> add(Uint8List pcm) {
    final found = <SoundAlert>[];
    var i = 0;
    if (_odd >= 0 && pcm.isNotEmpty) {
      _push(_odd, pcm[0], found);
      _odd = -1;
      i = 1;
    }
    for (; i + 1 < pcm.length; i += 2) {
      _push(pcm[i], pcm[i + 1], found);
    }
    if (i < pcm.length) {
      _odd = pcm[i];
    }
    return found;
  }

  void _push(int low, int high, List<SoundAlert> found) {
    var value = (high << 8) | low;
    if (value >= 0x8000) {
      value -= 0x10000;
    }
    _buffer[_filled++] = value / 32768;
    if (_filled == window) {
      _filled = 0;
      _frame(found);
    }
  }

  void _frame(List<SoundAlert> found) {
    final (kind, frequency) = _classify();
    final time = _now;
    _frames++;
    final run = _run;
    final samePitch = run != null &&
        (kind != _Kind.chime ||
            (frequency - run.frequency).abs() / run.frequency < 0.06);
    if (run != null && run.kind == kind && samePitch) {
      run.end = _now;
      run.frames++;
      run.frequency += (frequency - run.frequency) / run.frames;
    } else {
      if (run != null) {
        _segments.add(run);
      }
      _run = _Segment(kind, time, frequency)..end = _now;
    }
    _segments.removeWhere((s) => s.end < _now - 15);
    for (final alert in watching) {
      if (_heard(alert)) {
        final last = _told[alert];
        if (last == null || _now - last >= rest) {
          _told[alert] = _now;
          found.add(alert);
        }
      }
    }
  }

  /// What this window sounds like, and its main pitch.
  (_Kind, double) _classify() {
    var sum = 0.0;
    for (final v in _buffer) {
      sum += v * v;
    }
    final rms = math.sqrt(sum / window);
    if (rms < 0.01) {
      return (_Kind.quiet, 0);
    }
    final re = Float64List(window);
    final im = Float64List(window);
    for (var i = 0; i < window; i++) {
      // Hann window, so a pure tone stays in its own bins.
      re[i] = _buffer[i] * (0.5 - 0.5 * math.cos(2 * math.pi * i / window));
    }
    fft(re, im);
    final binHz = sampleRate / window;
    double magnitude(int bin) => bin <= 0 || bin >= window ~/ 2
        ? 0
        : math.sqrt(re[bin] * re[bin] + im[bin] * im[bin]);
    final low = (200 / binHz).floor();
    final high = math.min((5000 / binHz).ceil(), window ~/ 2 - 1);
    var peak = low;
    var total = 0.0;
    for (var bin = low; bin <= high; bin++) {
      final m = magnitude(bin);
      total += m;
      if (m > magnitude(peak)) {
        peak = bin;
      }
    }
    final mean = total / (high - low + 1);
    final top = magnitude(peak);
    // Parabolic interpolation between the bins around the peak.
    final a = magnitude(peak - 1), c = magnitude(peak + 1);
    final shift = (a - c) / (2 * (a - 2 * top + c)).clamp(-1e9, -1e-12);
    final frequency =
        (peak + (shift.isFinite ? shift.clamp(-0.5, 0.5) : 0)) * binHz;
    final tonal = top > 12 * mean;
    // Harmonics: the voice's pitch is the lowest strong partial.
    double near(double hz) {
      final bin = (hz / binHz).round();
      return math.max(
          magnitude(bin - 1), math.max(magnitude(bin), magnitude(bin + 1)));
    }

    if (rms > 0.02 && tonal && frequency >= 2700 && frequency <= 3700) {
      return (_Kind.alarm, frequency);
    }
    // The fundamental of a cry: the strongest of the low partials.
    var f0 = 0.0;
    var f0Level = 0.0;
    for (var bin = (250 / binHz).floor(); bin <= (750 / binHz).ceil(); bin++) {
      if (magnitude(bin) > f0Level) {
        f0Level = magnitude(bin);
        f0 = bin * binHz;
      }
    }
    final harmonics = [2, 3, 4].where((n) => near(f0 * n) > 0.25 * f0Level);
    if (rms > 0.03 &&
        f0Level > 0.3 * top &&
        f0Level > 8 * mean &&
        harmonics.length >= 2) {
      return (_Kind.cry, f0);
    }
    if (tonal && frequency >= 400 && frequency <= 2200) {
      return (_Kind.chime, frequency);
    }
    return (_Kind.other, frequency);
  }

  Iterable<_Segment> get _recent => [..._segments, if (_run case final r?) r];

  bool _heard(SoundAlert alert) {
    final now = _now;
    switch (alert) {
      case SoundAlert.smokeAlarm:
        final beeps = _recent.where((s) =>
            s.kind == _Kind.alarm &&
            s.end > now - 5 &&
            s.length >= 0.25 &&
            s.length <= 1.2);
        final long = _run?.kind == _Kind.alarm && (_run?.length ?? 0) >= 2.0;
        return beeps.length >= 3 || long;
      case SoundAlert.doorbell:
        // Two notes in a row, the second lower or higher by a third to a
        // fifth, just finished.
        final done = _segments;
        if (done.length < 2 || _run?.kind == _Kind.chime) {
          return false;
        }
        final notes = [
          for (final s in done)
            if (s.kind == _Kind.chime && s.length >= 0.12 && s.length <= 2.0) s,
        ];
        if (notes.length < 2) {
          return false;
        }
        final [first, second] = notes.sublist(notes.length - 2);
        final ratio = math.max(first.frequency, second.frequency) /
            math.min(first.frequency, second.frequency);
        return second.end > now - 1.0 &&
            second.start - first.end <= 0.6 &&
            ratio >= 1.1 &&
            ratio <= 1.7;
      case SoundAlert.babyCrying:
        final bursts = _recent.where((s) =>
            s.kind == _Kind.cry &&
            s.end > now - 12 &&
            s.length >= 0.3 &&
            s.length <= 3.0);
        return bursts.length >= 3;
    }
  }
}
