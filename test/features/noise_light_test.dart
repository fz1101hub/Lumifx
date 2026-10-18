import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumifx/src/core/effects/engine/effect_renderer.dart';
import 'package:lumifx/src/features/fun/noise_light.dart';

const _rate = 44100;

/// [seconds] of a 440 Hz tone at [amplitude] (0..1), in buffers of 4096
/// bytes like a microphone's.
List<Uint8List> _tone(double amplitude, double seconds) {
  final count = (seconds * _rate).round();
  final bytes = ByteData(count * 2);
  for (var i = 0; i < count; i++) {
    final s = amplitude * math.sin(2 * math.pi * 440 * i / _rate);
    bytes.setInt16(i * 2, (s * 32767).round(), Endian.little);
  }
  final all = bytes.buffer.asUint8List();
  return [
    for (var i = 0; i < all.length; i += 4096)
      Uint8List.sublistView(all, i, math.min(i + 4096, all.length)),
  ];
}

/// Feeds [buffers]; the zones it went through.
List<NoiseZone> _feed(NoiseWatch watch, List<Uint8List> buffers) => [
      for (final pcm in buffers)
        if (watch.add(pcm)) watch.zone,
    ];

void main() {
  test('a calm room stays green; shouting turns it red, then calm again', () {
    final watch = NoiseWatch(sampleRate: _rate);
    expect(_feed(watch, _tone(0.001, 2)), isEmpty);
    expect(watch.zone, NoiseZone.calm);
    expect(watch.level, lessThan(0.3));

    expect(_feed(watch, _tone(0.5, 2)), [NoiseZone.tooLoud]);
    expect(watch.level, greaterThan(0.85));

    // Calm again: it waits a while before going back to green.
    final zones = _feed(watch, _tone(0.001, 1));
    expect(zones, isEmpty);
    expect(_feed(watch, _tone(0.001, 4)).last, NoiseZone.calm);
  });

  test('a single clap does not change the lamps', () {
    final watch = NoiseWatch(sampleRate: _rate);
    _feed(watch, _tone(0.001, 1));
    expect(_feed(watch, [..._tone(0.8, 0.2), ..._tone(0.001, 2)]), isEmpty);
    expect(watch.zone, NoiseZone.calm);
  });

  test('the limit sets how much noise is fine', () {
    final talking = _tone(0.03, 2);
    final quiet = NoiseWatch(sampleRate: _rate, limit: NoiseLimit.quiet);
    final lively = NoiseWatch(sampleRate: _rate, limit: NoiseLimit.lively);
    _feed(quiet, talking);
    _feed(lively, talking);
    expect(quiet.zone.index, greaterThan(lively.zone.index));
    expect(lively.zone, NoiseZone.calm);
  });

  test('each zone lights the room in its colour', () {
    for (final zone in NoiseZone.values) {
      final effect = zone.effect('Noise light');
      expect(NoiseZone.of(effect), zone);
      expect(effect.hasRapidFlashes, isFalse);
      final frame = EffectRenderer(effect, slotCount: 2, seed: 1)
          .render(const Duration(seconds: 3))
          .first;
      expect(frame.color.toHex(), zone.color);
    }
  });
}
