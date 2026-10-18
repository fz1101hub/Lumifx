import 'package:flutter_test/flutter_test.dart';
import 'package:lumifx/src/core/color/light_color.dart';
import 'package:lumifx/src/core/effects/effect.dart';
import 'package:lumifx/src/core/effects/effect_event.dart';
import 'package:lumifx/src/core/effects/engine/effect_renderer.dart';
import 'package:lumifx/src/core/effects/engine/effect_player.dart';
import 'package:lumifx/src/core/effects/engine/light_frame.dart';
import 'package:lumifx/src/core/effects/engine/light_output.dart';
import 'package:lumifx/src/features/effects/catalog/builtin_scenes.dart';

class _RecordingOutput implements LightOutput {
  final updates = <Map<String, LightFrame>>[];

  @override
  void update(Map<String, LightFrame> frames, Duration tick) =>
      updates.add(frames);

  @override
  Future<void> close() async {}
}

const _sweep = LightingEffect(
  id: 'sweep',
  name: 'Sweep',
  kind: EffectKind.story,
  events: [
    EffectEvent(
      at: Duration.zero,
      duration: Duration(seconds: 10),
      type: EffectEventTypes.travel,
      parameters: {'pattern': 'sweep'},
    ),
  ],
);

void main() {
  group('EffectPlayer', () {
    test('a flash shows at once over the effect, then fades away', () {
      final output = _RecordingOutput();
      final player = EffectPlayer(
        effect: ocean,
        lightIds: const ['a', 'b'],
        output: output,
      );
      player.advance(const Duration(seconds: 1));
      const red = LightColor(1, 0, 0);
      player.flashNow(red, length: const Duration(milliseconds: 600));
      // Not playing: shown with the next frame, not on its own.
      player.advance(const Duration(milliseconds: 100));
      for (final frame in player.currentFrames) {
        expect(frame.color, red);
        expect(frame.brightness, 1);
      }
      // Fading over the last third, then gone.
      player.advance(const Duration(milliseconds: 400));
      for (final frame in player.currentFrames) {
        expect(frame.color.r, greaterThan(frame.color.b));
        expect(frame.color, isNot(red));
      }
      player.advance(const Duration(milliseconds: 200));
      final ocean0 = EffectPlayer(
        effect: ocean,
        lightIds: const ['a', 'b'],
        output: _RecordingOutput(),
      )..advance(const Duration(milliseconds: 1700));
      expect(player.currentFrames, ocean0.currentFrames);
    });

    test('a flash can light just one lamp along the room', () {
      final player = EffectPlayer(
        effect: ocean,
        lightIds: const ['a', 'b', 'c'],
        output: _RecordingOutput(),
      );
      player.advance(const Duration(seconds: 1));
      const red = LightColor(1, 0, 0);
      player.flashNow(red, at: 1);
      player.advance(const Duration(milliseconds: 100));
      expect(player.currentFrames[2].color, red);
      expect(player.currentFrames[0].color, isNot(red));
      expect(player.currentFrames[1].color, isNot(red));
      player.flashNow(red, at: 0.5);
      player.advance(const Duration(milliseconds: 100));
      expect(player.currentFrames[1].color, red);
      expect(player.currentFrames[2].color, isNot(red));
    });

    test('maps frames to light ids in order', () {
      final output = _RecordingOutput();
      final player = EffectPlayer(
        effect: _sweep,
        lightIds: const ['a', 'b', 'c'],
        output: output,
      );
      player.advance(const Duration(seconds: 1));
      expect(output.updates.single.keys, ['a', 'b', 'c']);
      expect(output.updates.single['a']!.brightness,
          greaterThan(output.updates.single['c']!.brightness));
    });

    test('crossfading to another effect restarts it without a jump', () {
      final output = _RecordingOutput();
      final player = EffectPlayer(
        effect: fireplace,
        lightIds: const ['a', 'b'],
        output: output,
      );
      player.advance(const Duration(seconds: 3));
      final before = player.currentFrames;
      player.crossfadeTo(ocean, over: const Duration(seconds: 2));
      expect(player.effect.id, 'ocean');
      expect(player.position, Duration.zero);
      // A tenth of the way in, the lights are still close to the fire.
      player.advance(const Duration(milliseconds: 200));
      final early = player.currentFrames;
      for (var i = 0; i < 2; i++) {
        expect(
            (early[i].brightness - before[i].brightness).abs(), lessThan(0.15));
      }
      // Past the fade, the new effect renders on its own.
      player.advance(const Duration(seconds: 2));
      final reference =
          EffectRenderer(ocean, slotCount: 2, seed: 1).render(player.position);
      expect(player.currentFrames.first.brightness,
          closeTo(reference.first.brightness, 1e-9));
    });

    test('blendFrames goes from one frame to the other', () {
      const a = LightFrame(LightColor(1, 0, 0), 0);
      const b = LightFrame(LightColor(0, 0, 1), 1);
      final mid = blendFrames(a, b, 0.5);
      expect(mid.brightness, 0.5);
      expect(mid.color.r, 0.5);
      expect(mid.color.b, 0.5);
    });

    test('speed scales effect time', () {
      final player = EffectPlayer(
        effect: _sweep,
        lightIds: const ['a'],
        output: const NullLightOutput(),
        controls: const EffectControls(speed: 2),
      );
      player.advance(const Duration(seconds: 1));
      expect(player.position, const Duration(seconds: 2));
      player.controls = player.controls.copyWith(speed: 0.5);
      player.advance(const Duration(seconds: 2));
      expect(player.position, const Duration(seconds: 3));
    });
  });

  test('play after stop is a no-op (no leaked timer)', () async {
    final output = _RecordingOutput();
    final player = EffectPlayer(
      effect: _sweep,
      lightIds: const ['a'],
      output: output,
      tick: const Duration(milliseconds: 10),
    );
    await player.stop();
    player.play();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(output.updates, isEmpty);
    expect(player.state, PlaybackState.stopped);
  });

  test('masterLevel scales every frame (used by the sleep-timer fade)', () {
    _RecordingOutput run(double level) {
      final output = _RecordingOutput();
      EffectPlayer(
        effect: _sweep,
        lightIds: const ['a', 'b', 'c'],
        output: output,
        seed: 3,
      )
        ..masterLevel = level
        ..advance(const Duration(seconds: 1));
      return output;
    }

    final full = run(1).updates.single;
    final half = run(0.5).updates.single;
    for (final id in ['a', 'b', 'c']) {
      expect(half[id]!.brightness, closeTo(full[id]!.brightness / 2, 1e-9));
      expect(half[id]!.color, full[id]!.color);
    }
  });

  group('soft flashes', () {
    test('softenFrames limits the brightness step and eases the colour', () {
      const dark = LightFrame(LightColor(0, 0, 0.2), 0.1);
      const strike = LightFrame(LightColor.white, 1);
      final eased = softenFrames([dark], [strike], 0.02).single;
      expect(eased.brightness, closeTo(0.15, 1e-9));
      // 5.6% of the way from dark blue to white.
      expect(eased.color.r, closeTo(0.0556, 1e-3));
      expect(eased.color.b, closeTo(0.2 + 0.8 * 0.0556, 1e-3));
      // Small changes pass through untouched.
      const almost = LightFrame(LightColor.white, 0.12);
      expect(softenFrames([dark], [almost], 0.02).single, almost);
      // No previous frame: nothing to ease from.
      expect(softenFrames(null, [strike], 0.02).single, strike);
    });

    test('a thunderstorm never jumps when flashes are softened', () {
      double largestStep({required bool soft}) {
        final output = _RecordingOutput();
        final player = EffectPlayer(
          effect: thunderstorm,
          lightIds: const ['a', 'b', 'c', 'd'],
          output: output,
          seed: 7,
          tick: const Duration(milliseconds: 20),
        )..softFlashes = soft;
        player.advance(Duration.zero);
        for (var i = 0; i < 45 * 50; i++) {
          player.advance(const Duration(milliseconds: 20));
        }
        var largest = 0.0;
        for (var i = 1; i < output.updates.length; i++) {
          for (final id in ['a', 'b', 'c', 'd']) {
            final step = (output.updates[i][id]!.brightness -
                    output.updates[i - 1][id]!.brightness)
                .abs();
            if (step > largest) {
              largest = step;
            }
          }
        }
        return largest;
      }

      expect(largestStep(soft: false), greaterThan(0.3),
          reason: 'lightning should strike within one 20 ms tick');
      expect(largestStep(soft: true),
          lessThanOrEqualTo(EffectPlayer.softFlashRate * 0.02 + 1e-9));
    });
  });

  group('RateLimitedLightOutput', () {
    test('a failed command is retried on the next tick', () async {
      var fail = true;
      final sent = <String>[];
      final output = RateLimitedLightOutput(
        send: (id, frame, transition) async {
          sent.add(id);
          if (fail) {
            throw StateError('429');
          }
        },
      );
      const frame = LightFrame(LightColor.white, 0.5);
      output.update({'a': frame}, const Duration(milliseconds: 200));
      await Future<void>.delayed(Duration.zero);
      fail = false;
      output.update({'a': frame}, const Duration(milliseconds: 200));
      await Future<void>.delayed(Duration.zero);
      expect(sent, ['a', 'a']);
    });

    test('never exceeds the command budget', () async {
      final sent = <String>[];
      var now = DateTime(2026);
      final output = RateLimitedLightOutput(
        send: (id, frame, transition) async => sent.add(id),
        commandsPerSecond: 10,
        clock: () => now,
      );
      var color = 0.0;
      for (var i = 0; i < 50; i++) {
        now = now.add(const Duration(milliseconds: 100));
        color = 1 - color;
        output.update({
          for (final id in ['a', 'b', 'c', 'd', 'e'])
            id: LightFrame(LightColor(color, 0, 0), 0.8),
        }, const Duration(milliseconds: 100));
        await Future<void>.delayed(Duration.zero);
      }
      // 5 seconds at 10 commands per second, plus the initial burst.
      expect(sent.length, lessThanOrEqualTo(52));
      expect(sent.toSet(), {'a', 'b', 'c', 'd', 'e'});
    });

    test('does not resend unchanged frames', () async {
      final sent = <String>[];
      final output = RateLimitedLightOutput(
        send: (id, frame, transition) async => sent.add(id),
      );
      const frame = LightFrame(LightColor.white, 0.5);
      for (var i = 0; i < 20; i++) {
        output.update({'a': frame}, const Duration(milliseconds: 100));
        await Future<void>.delayed(Duration.zero);
      }
      expect(sent, ['a']);
    });
  });
}
