import 'dart:math' as math;
import 'dart:typed_data';

/// Ambient sounds made from noise and a few oscillators: no recordings, so
/// nothing to license. Mono, [sampleRate] Hz, -1..1.
const sampleRate = 22050;

/// The sounds LumiFX can lay under an effect.
enum Ambience { rain, fire, waves, wind, underwater, bubbling, cave, forest }

/// One-off sounds, played on top.
enum SoundCue { thunder }

/// A seamless loop of [ambience], [seconds] long.
Float32List synthesizeAmbience(Ambience ambience,
    {double seconds = 12, int seed = 1}) {
  const fade = 1.0;
  final total = ((seconds + fade) * sampleRate).round();
  final random = math.Random(seed + ambience.index * 7919);
  final raw = switch (ambience) {
    Ambience.rain => _rain(total, random),
    Ambience.fire => _fire(total, random),
    Ambience.waves => _waves(total, random),
    Ambience.wind => _wind(total, random),
    Ambience.underwater => _underwater(total, random),
    Ambience.bubbling => _bubbling(total, random),
    Ambience.cave => _cave(total, random),
    Ambience.forest => _forest(total, random),
  };
  return _loop(_normalize(raw, 0.6), (seconds * sampleRate).round());
}

/// A [cue] about [seconds] long, fading to silence.
Float32List synthesizeCue(SoundCue cue, {int seed = 1}) => switch (cue) {
      SoundCue.thunder => _normalize(_thunder(math.Random(seed)), 0.9),
    };

/// 16-bit PCM WAV of [samples].
Uint8List wavOf(Float32List samples) {
  final data = ByteData(44 + samples.length * 2);
  void ascii(int offset, String text) {
    for (var i = 0; i < text.length; i++) {
      data.setUint8(offset + i, text.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  data.setUint32(4, 36 + samples.length * 2, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little); // PCM
  data.setUint16(22, 1, Endian.little); // mono
  data.setUint32(24, sampleRate, Endian.little);
  data.setUint32(28, sampleRate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  data.setUint32(40, samples.length * 2, Endian.little);
  for (var i = 0; i < samples.length; i++) {
    data.setInt16(44 + i * 2, (samples[i].clamp(-1.0, 1.0) * 32767).round(),
        Endian.little);
  }
  return data.buffer.asUint8List();
}

// --- building blocks -------------------------------------------------------

double _white(math.Random r) => r.nextDouble() * 2 - 1;

/// One-pole low-pass: [a] near 1 is darker.
class _LowPass {
  _LowPass(this.a);

  double a;
  double _y = 0;

  double call(double x) => _y = a * _y + (1 - a) * x;
}

/// Brown noise: integrated white noise that leaks back to zero.
class _Brown {
  double _y = 0;

  double call(math.Random r) {
    _y = (_y + _white(r) * 0.02) * 0.998;
    return _y * 6;
  }
}

/// Adds a decaying burst of filtered noise starting at [at].
void _burst(Float32List out, math.Random r, int at,
    {required double seconds, required double level, double tone = 0.0}) {
  final n = (seconds * sampleRate).round();
  final lp = _LowPass(tone);
  var previous = 0.0;
  for (var i = 0; i < n && at + i < out.length; i++) {
    final envelope = math.exp(-i / (n / 5));
    final noise = lp(_white(r));
    // A touch of high-pass so clicks are crisp, not thumps.
    final crisp = noise - previous * 0.5;
    previous = noise;
    out[at + i] += crisp * envelope * level;
  }
}

/// Adds a short tone sliding from [from] to [to] Hz.
void _chirp(Float32List out, int at,
    {required double from,
    required double to,
    required double seconds,
    required double level,
    double vibrato = 0}) {
  final n = (seconds * sampleRate).round();
  var phase = 0.0;
  for (var i = 0; i < n && at + i < out.length; i++) {
    final t = i / n;
    final f = from + (to - from) * t + vibrato * math.sin(i / 120);
    phase += 2 * math.pi * f / sampleRate;
    final envelope = math.sin(math.pi * t) * math.exp(-t * 2);
    out[at + i] += math.sin(phase) * envelope * level;
  }
}

/// Random start times, about [perSecond] a second.
Iterable<int> _events(math.Random r, int length, double perSecond) sync* {
  var t = 0.0;
  while (true) {
    t += -math.log(1 - r.nextDouble()) / perSecond;
    final at = (t * sampleRate).round();
    if (at >= length) {
      return;
    }
    yield at;
  }
}

// --- the sounds -------------------------------------------------------------

Float32List _rain(int n, math.Random r) {
  final out = Float32List(n);
  final hiss = _LowPass(0.55);
  final body = _LowPass(0.92);
  for (var i = 0; i < n; i++) {
    final w = _white(r);
    out[i] = hiss(w) * 0.5 + body(w) * 0.35;
  }
  for (final at in _events(r, n, 40)) {
    _burst(out, r, at,
        seconds: 0.012 + r.nextDouble() * 0.02, level: 0.25 * r.nextDouble());
  }
  return out;
}

Float32List _fire(int n, math.Random r) {
  final out = Float32List(n);
  final brown = _Brown();
  final roar = _LowPass(0.97);
  for (var i = 0; i < n; i++) {
    out[i] = roar(brown(r)) * 0.6;
  }
  for (final at in _events(r, n, 9)) {
    _burst(out, r, at,
        seconds: 0.004 + r.nextDouble() * 0.015,
        level: 0.4 + r.nextDouble() * 0.6);
  }
  // Now and then a louder pop.
  for (final at in _events(r, n, 0.6)) {
    _burst(out, r, at, seconds: 0.05, level: 1.2, tone: 0.3);
  }
  return out;
}

Float32List _waves(int n, math.Random r) {
  final out = Float32List(n);
  final lp = _LowPass(0.8);
  final deep = _LowPass(0.985);
  const period = 7.5;
  for (var i = 0; i < n; i++) {
    final t = i / sampleRate;
    final phase = (t / period) % 1;
    // Rises fast, washes out slowly.
    final swell = phase < 0.3
        ? math.sin(phase / 0.3 * math.pi / 2)
        : math.exp(-(phase - 0.3) * 4);
    final w = _white(r);
    out[i] = lp(w) * (0.15 + swell * 0.7) + deep(w) * 3 * (0.4 + swell);
  }
  return out;
}

Float32List _wind(int n, math.Random r) {
  final out = Float32List(n);
  final band = _LowPass(0.9);
  final low = _LowPass(0.995);
  for (var i = 0; i < n; i++) {
    final t = i / sampleRate;
    final gust = 0.5 +
        0.5 * math.sin(2 * math.pi * t / 9) * math.sin(2 * math.pi * t / 4.3);
    band.a = 0.86 + 0.1 * gust;
    final w = _white(r);
    final banded = band(w) - low(w);
    out[i] = banded * (0.3 + gust * 0.9);
  }
  return out;
}

Float32List _underwater(int n, math.Random r) {
  final out = Float32List(n);
  final brown = _Brown();
  final muffle = _LowPass(0.995);
  for (var i = 0; i < n; i++) {
    out[i] = muffle(brown(r)) * 1.5;
  }
  for (final at in _events(r, n, 0.8)) {
    _chirp(out, at,
        from: 250 + r.nextDouble() * 200,
        to: 700 + r.nextDouble() * 500,
        seconds: 0.06,
        level: 0.25);
  }
  return out;
}

Float32List _bubbling(int n, math.Random r) {
  final out = Float32List(n);
  final brown = _Brown();
  final muffle = _LowPass(0.99);
  for (var i = 0; i < n; i++) {
    out[i] = muffle(brown(r)) * 0.8;
  }
  for (final at in _events(r, n, 7)) {
    _chirp(out, at,
        from: 200 + r.nextDouble() * 300,
        to: 500 + r.nextDouble() * 700,
        seconds: 0.03 + r.nextDouble() * 0.05,
        level: 0.3 + r.nextDouble() * 0.3);
  }
  return out;
}

Float32List _cave(int n, math.Random r) {
  final out = Float32List(n);
  final brown = _Brown();
  final hum = _LowPass(0.998);
  for (var i = 0; i < n; i++) {
    out[i] = hum(brown(r)) * 2;
  }
  for (final at in _events(r, n, 0.9)) {
    final f = 1200 + r.nextDouble() * 900;
    _chirp(out, at, from: f, to: f * 0.7, seconds: 0.09, level: 0.35);
    // A faint echo.
    _chirp(out, at + (0.18 * sampleRate).round(),
        from: f, to: f * 0.7, seconds: 0.09, level: 0.1);
  }
  return out;
}

Float32List _forest(int n, math.Random r) {
  final out = _wind(n, r);
  for (var i = 0; i < n; i++) {
    out[i] *= 0.4;
  }
  for (final at in _events(r, n, 1.4)) {
    final f = 2600 + r.nextDouble() * 1600;
    final notes = 1 + r.nextInt(3);
    for (var k = 0; k < notes; k++) {
      _chirp(out, at + k * (0.11 * sampleRate).round(),
          from: f,
          to: f * (1.1 + r.nextDouble() * 0.3),
          seconds: 0.08,
          level: 0.18,
          vibrato: 80);
    }
  }
  return out;
}

Float32List _thunder(math.Random r) {
  final n = (4.5 * sampleRate).round();
  final out = Float32List(n);
  final brown = _Brown();
  final rumble = _LowPass(0.985);
  // The crack, then a rolling rumble with a few swells.
  _burst(out, r, 0, seconds: 0.25, level: 0.9, tone: 0.2);
  final swells = [for (var k = 0; k < 4; k++) r.nextDouble() * 3.2 + 0.2];
  for (var i = 0; i < n; i++) {
    final t = i / sampleRate;
    var envelope = math.exp(-t * 0.9) * math.min(1, t * 8);
    for (final s in swells) {
      envelope += 0.5 * math.exp(-math.pow((t - s) * 3, 2).toDouble());
    }
    out[i] += rumble(brown(r)) * 3 * envelope;
  }
  // Fade the tail to silence.
  final tail = (0.8 * sampleRate).round();
  for (var i = 0; i < tail; i++) {
    out[n - tail + i] *= 1 - i / tail;
  }
  return out;
}

/// Scales so the loudest sample is [peak].
Float32List _normalize(Float32List samples, double peak) {
  var max = 0.0;
  for (final s in samples) {
    max = math.max(max, s.abs());
  }
  if (max > 0) {
    final k = peak / max;
    for (var i = 0; i < samples.length; i++) {
      samples[i] *= k;
    }
  }
  return samples;
}

/// The first [length] samples, with the extra tail cross-faded into the
/// start so the loop has no seam.
Float32List _loop(Float32List samples, int length) {
  final fade = samples.length - length;
  final out = Float32List.fromList(samples.sublist(0, length));
  for (var i = 0; i < fade; i++) {
    final t = i / fade;
    out[i] = out[i] * t + samples[length + i] * (1 - t);
  }
  return out;
}
