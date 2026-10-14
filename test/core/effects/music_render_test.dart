import 'package:flutter_test/flutter_test.dart';
import 'package:lumifx/src/core/audio/audio_analyzer.dart';
import 'package:lumifx/src/core/effects/effect.dart';
import 'package:lumifx/src/core/effects/effect_event.dart';
import 'package:lumifx/src/core/effects/engine/effect_renderer.dart';
import 'package:lumifx/src/features/effects/catalog/builtin_interactive.dart';

LightingEffect _music(String mode) => LightingEffect(
      id: mode,
      name: mode,
      kind: EffectKind.interactive,
      events: [
        EffectEvent(
          at: Duration.zero,
          duration: const Duration(minutes: 1),
          type: EffectEventTypes.music,
          parameters: {
            'mode': mode,
            'palette': <String>['#FF0000', '#00FF00', '#0000FF'],
            'brightnessMin': 0.0,
          },
        ),
      ],
    );

void main() {
  test('music effects are flagged as using the microphone', () {
    expect(beatPulse.usesMicrophone, isTrue);
    expect(beatPulse.kind, EffectKind.interactive);
  });

  test('without audio, music events render nothing', () {
    final frames = EffectRenderer(_music('pulse'), slotCount: 3)
        .render(const Duration(seconds: 1));
    expect(frames.every((f) => f.isOff), isTrue);
  });

  test('pulse flashes right after a beat and fades', () {
    final renderer = EffectRenderer(_music('pulse'), slotCount: 2);
    double brightness(double sinceBeat) => renderer
        .render(Duration.zero,
            audio: AudioFeatures(beatCount: 3, secondsSinceBeat: sinceBeat))
        .first
        .brightness;
    expect(brightness(0), closeTo(1, 1e-9));
    expect(brightness(0.3), lessThan(0.5));
    expect(brightness(2), lessThan(0.01));
  });

  test('pulse changes color on every beat', () {
    final renderer = EffectRenderer(_music('pulse'), slotCount: 1);
    final colors = {
      for (var beat = 0; beat < 3; beat++)
        renderer
            .render(Duration.zero,
                audio: AudioFeatures(beatCount: beat, secondsSinceBeat: 0))
            .single
            .color,
    };
    expect(colors, hasLength(3));
  });

  test('spectrum maps bass to the left and treble to the right', () {
    final renderer = EffectRenderer(_music('spectrum'), slotCount: 3);
    final bassy = renderer.render(Duration.zero,
        audio: const AudioFeatures(bass: 1, mid: 0, treble: 0));
    expect(bassy.first.brightness, greaterThan(0.7));
    expect(bassy.last.brightness, lessThan(0.1));

    final bright = renderer.render(Duration.zero,
        audio: const AudioFeatures(bass: 0, mid: 0, treble: 1));
    expect(bright.last.brightness, greaterThan(0.7));
    expect(bright.first.brightness, lessThan(0.1));
  });

  test('chase moves the lit lamp with each beat', () {
    final renderer = EffectRenderer(_music('chase'), slotCount: 4);
    int brightest(int beat) {
      final frames = renderer.render(Duration.zero,
          audio: AudioFeatures(beatCount: beat, secondsSinceBeat: 0, level: 1));
      var best = 0;
      for (var i = 1; i < frames.length; i++) {
        if (frames[i].brightness > frames[best].brightness) {
          best = i;
        }
      }
      return best;
    }

    expect([for (var b = 0; b < 5; b++) brightest(b)], [0, 1, 2, 3, 0]);
  });

  test('energy follows loudness', () {
    final renderer = EffectRenderer(_music('energy'), slotCount: 2);
    final quiet = renderer
        .render(Duration.zero, audio: const AudioFeatures(level: 0.1))
        .first;
    final loud = renderer
        .render(Duration.zero, audio: const AudioFeatures(level: 0.9))
        .first;
    expect(loud.brightness, greaterThan(quiet.brightness + 0.4));
  });

  test('NaN audio levels count as silence, not full brightness', () {
    final renderer = EffectRenderer(_music('energy'), slotCount: 1);
    final frame = renderer
        .render(Duration.zero, audio: const AudioFeatures(level: double.nan))
        .single;
    expect(frame.brightness, lessThan(0.01));
  });
}
