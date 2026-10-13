import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumifx/src/core/audio/audio_analyzer.dart';
import 'package:lumifx/src/core/audio/fft.dart';

const _rate = 44100;

Iterable<double> _sine(double hz, double seconds, {double amplitude = 0.5}) =>
    Iterable.generate((seconds * _rate).round(),
        (i) => amplitude * math.sin(2 * math.pi * hz * i / _rate));

/// A kick drum every beat over a quiet pad: a 55 Hz thump with a fast
/// decay and a noisy attack.
List<double> _clickTrack(double bpm, double seconds, {int seed = 1}) {
  final random = math.Random(seed);
  final samples = List<double>.generate((seconds * _rate).round(), (i) {
    final t = i / _rate;
    return 0.02 * math.sin(2 * math.pi * 330 * t);
  });
  final beat = 60 / bpm;
  for (var start = 0.5; start < seconds; start += beat) {
    final first = (start * _rate).round();
    for (var i = 0; i < (0.12 * _rate) && first + i < samples.length; i++) {
      final t = i / _rate;
      final envelope = math.exp(-t * 30);
      final noise = t < 0.01 ? (random.nextDouble() * 2 - 1) * 0.4 : 0;
      samples[first + i] +=
          envelope * (0.8 * math.sin(2 * math.pi * 55 * t) + noise);
    }
  }
  return samples;
}

void main() {
  test('FFT puts a pure tone in its bin', () {
    const n = 256;
    final re = Float64List.fromList(
        [for (var i = 0; i < n; i++) math.cos(2 * math.pi * 10 * i / n)]);
    final im = Float64List(n);
    fft(re, im);
    final magnitudes = [
      for (var k = 0; k < n ~/ 2; k++) math.sqrt(re[k] * re[k] + im[k] * im[k]),
    ];
    final peak = magnitudes.indexOf(magnitudes.reduce(math.max));
    expect(peak, 10);
    expect(magnitudes[10], closeTo(n / 2, 1e-6));
  });

  test('FFT rejects lengths that are not powers of two', () {
    expect(() => fft(Float64List(3), Float64List(3)), throwsArgumentError);
  });

  test('silence produces no levels and no beats', () {
    final analyzer = AudioAnalyzer()..addSamples(List.filled(_rate, 0.0));
    final f = analyzer.features;
    expect(f.level, 0);
    expect(f.bass, 0);
    expect(f.beatCount, 0);
  });

  test('a low tone is bass, a high tone is treble', () {
    final low = AudioAnalyzer()..addSamples(_sine(80, 1));
    expect(low.features.bass, greaterThan(0.8));
    expect(low.features.treble, lessThan(0.2));

    final high = AudioAnalyzer()..addSamples(_sine(5000, 1));
    expect(high.features.treble, greaterThan(0.8));
    expect(high.features.bass, lessThan(0.2));
  });

  test('detects the beats of a 120 BPM kick and estimates the tempo', () {
    final analyzer = AudioAnalyzer()..addSamples(_clickTrack(120, 8.4));
    // Kicks at 0.5, 1.0, ... 8.0 s: 16 of them.
    expect(analyzer.features.beatCount, inInclusiveRange(15, 17));
    expect(analyzer.features.bpm, closeTo(120, 6));
  });

  test('tempo follows a faster track', () {
    final analyzer = AudioAnalyzer()..addSamples(_clickTrack(150, 8.5));
    expect(analyzer.features.bpm, closeTo(150, 8));
  });

  test('PCM bytes split at odd offsets decode like whole chunks', () {
    final samples = _clickTrack(120, 2).toList();
    final bytes = ByteData(samples.length * 2);
    for (var i = 0; i < samples.length; i++) {
      bytes.setInt16(
          i * 2, (samples[i].clamp(-1.0, 1.0) * 32767).round(), Endian.little);
    }
    final all = bytes.buffer.asUint8List();

    final whole = AudioAnalyzer()..addPcm16(all);
    final split = AudioAnalyzer();
    for (var i = 0; i < all.length; i += 777) {
      split.addPcm16(
          Uint8List.sublistView(all, i, math.min(i + 777, all.length)));
    }
    expect(split.features.beatCount, whole.features.beatCount);
    expect(split.features.bass, closeTo(whole.features.bass, 1e-9));
  });

  test('steady noise does not produce a stream of beats', () {
    final random = math.Random(3);
    final analyzer = AudioAnalyzer()
      ..addSamples(
          List.generate(5 * _rate, (_) => (random.nextDouble() * 2 - 1) * 0.2));
    expect(analyzer.features.beatCount, lessThan(4));
    expect(analyzer.features.level, greaterThan(0.5));
  });

  test('still finds kicks over a noisy background', () {
    final random = math.Random(5);
    final track = _clickTrack(128, 8.5);
    for (var i = 0; i < track.length; i++) {
      track[i] += (random.nextDouble() * 2 - 1) * 0.08;
    }
    final analyzer = AudioAnalyzer()..addSamples(track);
    expect(analyzer.features.beatCount, inInclusiveRange(15, 19));
    expect(analyzer.features.bpm, closeTo(128, 8));
  });
}
