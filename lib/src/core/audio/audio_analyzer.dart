import 'dart:math' as math;
import 'dart:typed_data';

import 'fft.dart';

/// What the lights react to, all levels normalised to 0..1.
class AudioFeatures {
  const AudioFeatures({
    this.level = 0,
    this.bass = 0,
    this.mid = 0,
    this.treble = 0,
    this.beatCount = 0,
    this.secondsSinceBeat = double.infinity,
    this.bpm,
  });

  static const silent = AudioFeatures();

  /// Overall loudness.
  final double level;

  /// 20-250 Hz: kick drums, bass lines.
  final double bass;

  /// 250-2000 Hz: voices, most instruments.
  final double mid;

  /// 2-8 kHz: hi-hats, cymbals, sibilance.
  final double treble;

  /// Increments on every detected beat.
  final int beatCount;
  final double secondsSinceBeat;

  /// Estimated tempo, once a few regular beats have been heard.
  final double? bpm;

  AudioFeatures aged(double seconds) => AudioFeatures(
        level: level,
        bass: bass,
        mid: mid,
        treble: treble,
        beatCount: beatCount,
        secondsSinceBeat: secondsSinceBeat + seconds,
        bpm: bpm,
      );

  AudioFeatures scaled(double gain) => AudioFeatures(
        level: (level * gain).clamp(0.0, 1.0),
        bass: (bass * gain).clamp(0.0, 1.0),
        mid: (mid * gain).clamp(0.0, 1.0),
        treble: (treble * gain).clamp(0.0, 1.0),
        beatCount: beatCount,
        secondsSinceBeat: secondsSinceBeat,
        bpm: bpm,
      );
}

/// Turns a mono 16-bit PCM stream into [AudioFeatures].
///
/// Every [hopSize] samples it analyses the last [frameSize] samples: a
/// Hann-windowed FFT gives band energies, which are normalised against a
/// slowly decaying peak (automatic gain, so quiet and loud rooms both work),
/// and spectral flux against its recent average gives beat onsets.
class AudioAnalyzer {
  AudioAnalyzer({
    this.sampleRate = 44100,
    this.frameSize = 1024,
    this.hopSize = 512,
  })  : _window = Float64List.fromList([
          for (var i = 0; i < frameSize; i++)
            0.5 - 0.5 * math.cos(2 * math.pi * i / (frameSize - 1)),
        ]),
        _samples = Float64List(frameSize),
        _previousMagnitudes = Float64List(frameSize ~/ 2 + 1);

  final int sampleRate;
  final int frameSize;
  final int hopSize;

  final Float64List _window;
  final Float64List _samples;
  final Float64List _previousMagnitudes;
  int _filled = 0;
  int _write = 0; // next index in the circular sample buffer
  int _sinceHop = 0;
  int? _pendingByte;
  int _hops = 0;

  final _peaks = List<double>.filled(4, _minimumPeak);
  final _smoothed = List<double>.filled(4, 0);
  final _fluxHistory = <double>[];
  final _beatIntervals = <double>[];
  double _previousFlux = 0;
  int _beatCount = 0;
  double? _lastBeatAt;

  AudioFeatures _features = AudioFeatures.silent;

  AudioFeatures get features => _features;

  double get _hopSeconds => hopSize / sampleRate;
  double get _now => _hops * _hopSeconds;

  /// Below this RMS the input is treated as silence.
  static const _noiseGate = 0.0015;
  static const _minimumPeak = 0.01;
  static const _minimumBeatGap = 0.28; // seconds, i.e. at most ~214 BPM

  /// Feeds little-endian 16-bit mono samples, in chunks of any size.
  /// Returns true if at least one analysis step ran.
  bool addPcm16(Uint8List bytes) {
    var analysed = false;
    var i = 0;
    if (_pendingByte != null && bytes.isNotEmpty) {
      analysed |= _addSample(_pcm(_pendingByte!, bytes[0]));
      _pendingByte = null;
      i = 1;
    }
    for (; i + 1 < bytes.length; i += 2) {
      analysed |= _addSample(_pcm(bytes[i], bytes[i + 1]));
    }
    if (i < bytes.length) {
      _pendingByte = bytes[i];
    }
    return analysed;
  }

  /// Feeds samples in -1..1.
  bool addSamples(Iterable<double> samples) {
    var analysed = false;
    for (final sample in samples) {
      analysed |= _addSample(sample);
    }
    return analysed;
  }

  static double _pcm(int low, int high) {
    final value = (high << 8) | low;
    return (value >= 0x8000 ? value - 0x10000 : value) / 32768;
  }

  bool _addSample(double sample) {
    _samples[_write] = sample;
    _write = (_write + 1) % frameSize;
    if (_filled < frameSize) {
      _filled++;
    }
    if (++_sinceHop >= hopSize && _filled == frameSize) {
      _sinceHop = 0;
      _analyse();
      return true;
    }
    return false;
  }

  void _analyse() {
    _hops++;
    final re = Float64List(frameSize);
    final im = Float64List(frameSize);
    var energy = 0.0;
    for (var i = 0; i < frameSize; i++) {
      // Oldest sample first: the circular buffer starts at the write index.
      final sample = _samples[(_write + i) % frameSize];
      energy += sample * sample;
      re[i] = sample * _window[i];
    }
    final rms = math.sqrt(energy / frameSize);
    fft(re, im);

    final bins = frameSize ~/ 2 + 1;
    final magnitudes = Float64List(bins);
    for (var k = 0; k < bins; k++) {
      magnitudes[k] =
          math.sqrt(re[k] * re[k] + im[k] * im[k]) / (frameSize / 4);
    }

    double band(double lowHz, double highHz) {
      final low = math.max(1, (lowHz * frameSize / sampleRate).floor());
      final high = math.min(bins - 1, (highHz * frameSize / sampleRate).ceil());
      var sum = 0.0;
      for (var k = low; k <= high; k++) {
        sum += magnitudes[k] * magnitudes[k];
      }
      return math.sqrt(sum);
    }

    final gated = rms < _noiseGate;
    final raw = [rms, band(20, 250), band(250, 2000), band(2000, 8000)];
    for (var i = 0; i < raw.length; i++) {
      // Peaks fall by half in ~6 s, so the scale follows the room's volume.
      _peaks[i] = math.max(raw[i], math.max(_minimumPeak, _peaks[i] * 0.9987));
      final target = gated ? 0.0 : (raw[i] / _peaks[i]).clamp(0.0, 1.0);
      final rate = target > _smoothed[i] ? 0.6 : 0.2;
      _smoothed[i] += (target - _smoothed[i]) * rate;
    }

    // Spectral flux over 30 Hz-4 kHz, on log-compressed magnitudes.
    final fluxLow = math.max(1, (30 * frameSize / sampleRate).floor());
    final fluxHigh = math.min(bins - 1, (4000 * frameSize / sampleRate).ceil());
    var flux = 0.0;
    for (var k = fluxLow; k <= fluxHigh; k++) {
      final now = math.log(1 + 1000 * magnitudes[k]);
      final before = math.log(1 + 1000 * _previousMagnitudes[k]);
      if (now > before) {
        flux += now - before;
      }
    }
    _previousMagnitudes.setAll(0, magnitudes);
    _detectBeat(gated ? 0 : flux);
    _previousFlux = gated ? 0 : flux;

    final lastBeat = _lastBeatAt;
    _features = AudioFeatures(
      level: _smoothed[0],
      bass: _smoothed[1],
      mid: _smoothed[2],
      treble: _smoothed[3],
      beatCount: _beatCount,
      secondsSinceBeat: lastBeat == null ? double.infinity : _now - lastBeat,
      bpm: _tempo(),
    );
  }

  void _detectBeat(double flux) {
    // About 0.75 s of history.
    final historyLength = (0.75 / _hopSeconds).round();
    if (_fluxHistory.length >= 4) {
      final mean = _fluxHistory.reduce((a, b) => a + b) / _fluxHistory.length;
      var variance = 0.0;
      for (final f in _fluxHistory) {
        variance += (f - mean) * (f - mean);
      }
      final deviation = math.sqrt(variance / _fluxHistory.length);
      final threshold = math.max(mean + 2.5 * deviation, mean * 1.5) + 0.5;
      final lastBeat = _lastBeatAt;
      final gapOk = lastBeat == null || _now - lastBeat >= _minimumBeatGap;
      if (flux > threshold && flux >= _previousFlux && gapOk) {
        if (lastBeat != null) {
          final interval = _now - lastBeat;
          if (interval <= 1.5) {
            _beatIntervals.add(interval);
            if (_beatIntervals.length > 8) {
              _beatIntervals.removeAt(0);
            }
          }
        }
        _lastBeatAt = _now;
        _beatCount++;
      }
    }
    _fluxHistory.add(flux);
    if (_fluxHistory.length > historyLength) {
      _fluxHistory.removeAt(0);
    }
  }

  double? _tempo() {
    if (_beatIntervals.length < 3) {
      return null;
    }
    final sorted = [..._beatIntervals]..sort();
    final median = sorted[sorted.length ~/ 2];
    return 60 / median;
  }
}
