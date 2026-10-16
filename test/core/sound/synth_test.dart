import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumifx/src/core/sound/soundscape.dart';
import 'package:lumifx/src/core/sound/synth.dart';
import 'package:lumifx/src/features/effects/catalog/builtin_interactive.dart';
import 'package:lumifx/src/features/effects/catalog/builtin_scenes.dart';
import 'package:lumifx/src/features/effects/catalog/effect_catalog.dart';

double _rms(Float32List s) =>
    math.sqrt(s.fold<double>(0, (a, x) => a + x * x) / s.length);

void main() {
  test('every ambience is a quiet-enough, seamless loop of the right length',
      () {
    for (final ambience in Ambience.values) {
      final loop = synthesizeAmbience(ambience, seconds: 4);
      expect(loop.length, 4 * sampleRate, reason: ambience.name);
      expect(loop.every((s) => s.abs() <= 1), isTrue, reason: ambience.name);
      expect(_rms(loop), greaterThan(0.01), reason: '${ambience.name} silent');
      // No click where the loop wraps around: the jump from the last
      // sample to the first is no bigger than the sound's own steps.
      var biggestStep = 0.0;
      for (var i = 1; i < loop.length; i++) {
        biggestStep = math.max(biggestStep, (loop[i] - loop[i - 1]).abs());
      }
      expect((loop.first - loop.last).abs(), lessThanOrEqualTo(biggestStep),
          reason: ambience.name);
    }
  });

  test('thunder starts loud and dies away', () {
    final thunder = synthesizeCue(SoundCue.thunder);
    final firstSecond = Float32List.sublistView(thunder, 0, sampleRate);
    final lastQuarter = Float32List.sublistView(
        thunder, thunder.length - sampleRate ~/ 4, thunder.length);
    expect(_rms(firstSecond), greaterThan(_rms(lastQuarter) * 5));
    expect(thunder.last.abs(), lessThan(0.01));
  });

  test('a WAV header the players accept', () {
    final wav = wavOf(Float32List.fromList([0, 1, -1]));
    expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
    expect(wav.length, 44 + 6);
    final data = ByteData.sublistView(wav);
    expect(data.getUint32(24, Endian.little), sampleRate);
    expect(data.getInt16(46, Endian.little), 32767);
    expect(data.getInt16(48, Endian.little), -32767);
  });

  test('effects sound like what they show; Music Sync stays silent', () {
    expect(soundscapeOf(fireplace).ambiences, [Ambience.fire]);
    expect(soundscapeOf(thunderstorm).thunder, isTrue);
    expect(soundscapeOf(beatPulse).isSilent, isTrue);
    // Every listed id exists, so no sound is attached to nothing.
    for (final effect in effectCatalog) {
      soundscapeOf(effect);
    }
    expect(effectById('haunted_manor'), isNotNull);
  });
}
