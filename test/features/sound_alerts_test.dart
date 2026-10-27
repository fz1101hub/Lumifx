import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumifx/src/features/alerts/sound_alerts.dart';

const _rate = 44100;

/// [seconds] of the sum of [partials] (frequency, amplitude); silence
/// without any.
List<double> _sound(double seconds,
    [List<(double, double)> partials = const []]) {
  final n = (seconds * _rate).round();
  return [
    for (var i = 0; i < n; i++)
      partials.fold(0.0,
          (sum, p) => sum + p.$2 * math.sin(2 * math.pi * p.$1 * i / _rate)),
  ];
}

Uint8List _pcm(List<double> samples) {
  final data = ByteData(samples.length * 2);
  for (var i = 0; i < samples.length; i++) {
    data.setInt16(
        i * 2, (samples[i].clamp(-1.0, 1.0) * 32767).round(), Endian.little);
  }
  return data.buffer.asUint8List();
}

/// What [watch] hears in [samples], fed in phone-sized chunks.
List<SoundAlert> _hear(SoundWatch watch, List<double> samples) {
  final pcm = _pcm(samples);
  final heard = <SoundAlert>[];
  for (var i = 0; i < pcm.length; i += 3001) {
    heard.addAll(watch
        .add(Uint8List.sublistView(pcm, i, math.min(pcm.length, i + 3001))));
  }
  return heard;
}

List<double> _cry() =>
    _sound(0.8, [(440, 0.3), (880, 0.2), (1320, 0.15), (1760, 0.08)]);

void main() {
  test('a smoke alarm: three beeps near 3 kHz', () {
    final samples = [
      for (var i = 0; i < 3; i++) ...[
        ..._sound(0.5, [(3150, 0.5)]),
        ..._sound(0.5),
      ],
      ..._sound(1.5),
    ];
    expect(
        _hear(SoundWatch(sampleRate: _rate), samples), [SoundAlert.smokeAlarm]);
  });

  test('a doorbell: ding, then dong a third lower', () {
    final samples = [
      ..._sound(0.5),
      ..._sound(0.5, [(880, 0.4)]),
      ..._sound(0.7, [(698, 0.4)]),
      ..._sound(1.0),
    ];
    expect(
        _hear(SoundWatch(sampleRate: _rate), samples), [SoundAlert.doorbell]);
  });

  test('a baby crying: bursts of a voice rich in harmonics', () {
    final samples = [
      for (var i = 0; i < 4; i++) ...[..._cry(), ..._sound(0.4)],
    ];
    expect(
        _hear(SoundWatch(sampleRate: _rate), samples), [SoundAlert.babyCrying]);
  });

  test('a steady tone, noise or one note tell about nothing', () {
    final random = math.Random(1);
    final samples = [
      ..._sound(3, [(1000, 0.4)]),
      for (var i = 0; i < _rate * 2; i++) (random.nextDouble() - 0.5) * 0.4,
      ..._sound(0.6, [(880, 0.4)]),
      ..._sound(1.0),
    ];
    expect(_hear(SoundWatch(sampleRate: _rate), samples), isEmpty);
  });

  test('only the sounds watched, and each once in a while', () {
    final beeps = [
      for (var i = 0; i < 3; i++) ...[
        ..._sound(0.5, [(3150, 0.5)]),
        ..._sound(0.5),
      ],
      ..._sound(1.5),
    ];
    final watch =
        SoundWatch(sampleRate: _rate, watching: {SoundAlert.doorbell});
    expect(_hear(watch, beeps), isEmpty);
    watch.watching = {SoundAlert.smokeAlarm};
    expect(_hear(watch, [...beeps, ...beeps]), [SoundAlert.smokeAlarm],
        reason: 'not again within half a minute');
  });

  test('the alert flashes at most twice a second, in its colour', () {
    for (final alert in SoundAlert.values) {
      final effect = alert.effect(alert.name);
      expect(SoundAlert.of(effect), alert);
      expect(effect.hasRapidFlashes, isFalse);
      expect(alert.every, greaterThanOrEqualTo(0.5));
    }
  });
}
