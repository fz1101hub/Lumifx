import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumifx/src/features/music/sing_colour.dart';

Uint8List _tone(double hz,
    {int sampleRate = 44100, int samples = 1024, double amplitude = 0.5}) {
  final data = ByteData(samples * 2);
  for (var i = 0; i < samples; i++) {
    final s = amplitude * math.sin(2 * math.pi * hz * i / sampleRate);
    data.setInt16(i * 2, (s * 32767).round(), Endian.little);
  }
  return data.buffer.asUint8List();
}

void main() {
  test('the pitch of a sung note is found', () {
    for (final hz in [110.0, 220.0, 440.0, 660.0]) {
      final frame = [
        for (var i = 0; i < 1024; i++) math.sin(2 * math.pi * hz * i / 44100),
      ];
      final found = PitchWatch.pitchOf(frame, 44100)!;
      expect((found - hz).abs() / hz, lessThan(0.02), reason: '$hz Hz');
    }
  });

  test('low notes are red, high ones blue or violet; silence is nothing', () {
    final watch = PitchWatch(sampleRate: 44100);
    final low = watch.add(_tone(98))!;
    expect(low.color.r, greaterThan(low.color.b));
    final high = watch.add(_tone(880))!;
    expect(high.color.b, greaterThan(high.color.r * 0.9));
    expect(watch.add(_tone(440, amplitude: 0.0005)), isNull);
  });

  test('holding a note makes it brighter', () {
    final watch = PitchWatch(sampleRate: 44100);
    final first = watch.add(_tone(330))!.brightness;
    double last = first;
    for (var i = 0; i < 90; i++) {
      last = watch.add(_tone(330))!.brightness;
    }
    expect(last, greaterThan(first + 0.2));
  });
}
