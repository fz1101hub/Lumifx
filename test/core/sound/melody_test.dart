import 'package:flutter_test/flutter_test.dart';
import 'package:lumifx/src/core/color/light_color.dart';
import 'package:lumifx/src/core/effects/effect_event.dart';
import 'package:lumifx/src/core/effects/engine/effect_renderer.dart';
import 'package:lumifx/src/core/sound/melodies.dart';
import 'package:lumifx/src/core/sound/melody.dart';
import 'package:lumifx/src/core/sound/soundscape.dart';
import 'package:lumifx/src/core/sound/synth.dart';
import 'package:lumifx/src/features/music_box/melody_lights.dart';

void main() {
  test('six tunes, each findable, each within a comfortable range', () {
    final all = [...lullabies, ...carols];
    expect({for (final m in all) m.id}, hasLength(6));
    for (final melody in all) {
      expect(melodyById(melody.id), same(melody));
      final (low, high) = melody.range;
      expect(low, greaterThanOrEqualTo(48), reason: melody.id);
      expect(high, lessThanOrEqualTo(84), reason: melody.id);
      expect(melody.length, greaterThanOrEqualTo(const Duration(seconds: 8)),
          reason: melody.id);
      expect(melody.length, lessThan(const Duration(seconds: 60)),
          reason: melody.id);
    }
    expect(
        lullabies.map((m) => m.instrument), everyElement(Instrument.musicBox));
    expect(carols.map((m) => m.instrument), everyElement(Instrument.bells));
  });

  test('the timeline follows the beats, and repeats', () {
    final once = twinkle.timeline();
    expect(once.first, (Duration.zero, twinkle.beat, 60));
    expect(once[6].$2, twinkle.beat * 2, reason: 'the long G');
    final thrice = twinkle.timeline(times: 3);
    expect(thrice, hasLength(once.length * 3));
    expect(thrice[once.length].$1, twinkle.length);
  });

  test('the tune is made of sound, as long as the notes and a ring', () {
    final samples = synthesizeMelody(frereJacques, times: 2);
    final expected = (frereJacques.length * 2 +
                const Duration(seconds: 1, milliseconds: 500))
            .inMicroseconds *
        sampleRate ~/
        1000000;
    expect(samples.length, expected);
    var peak = 0.0;
    for (final s in samples) {
      peak = s.abs() > peak ? s.abs() : peak;
    }
    expect(peak, closeTo(0.7, 0.001));
    // The first note sounds right away.
    final start = samples.sublist(200, 2000).map((s) => s.abs());
    expect(start.reduce((a, b) => a > b ? a : b), greaterThan(0.1));
  });

  test('every note lights the lamp of its pitch, in time with the sound', () {
    final effect = melodyEffect(brahms, times: 3, name: 'Brahms');
    final flashes = effect.events
        .where((e) => e.type == EffectEventTypes.magicFlash)
        .toList();
    expect(flashes, hasLength(brahms.timeline().length * 3));
    for (final flash in flashes) {
      final position = flash.parameters['position']! as double;
      expect(position, inInclusiveRange(0, 1));
    }
    expect(effect.isLooping, isFalse);
    expect(effect.isGenerated, isTrue);
    expect(effect.hasRapidFlashes, isFalse);
    expect(effect.cycleLength, brahms.length * 3 + const Duration(seconds: 2));

    final scape = soundscapeOf(effect);
    expect(scape.melody, same(brahms));
    expect(scape.melodyTimes, 3);
    expect(scape.isSilent, isFalse);
  });

  test('a flash at a position lights that lamp', () {
    final effect = melodyEffect(twinkle, times: 1, name: 'x');
    final renderer = EffectRenderer(effect, slotCount: 5, seed: 1);
    // The highest note (A, the sixth note) at the far right.
    final at = twinkle.timeline()[4].$1 + const Duration(milliseconds: 150);
    final frames = renderer.render(at);
    final last = frames.last;
    final first = frames.first;
    expect(last.brightness, greaterThan(first.brightness));
    expect(last.color, isNot(LightColor.fromHex('#141A4A')));
  });
}
