import 'package:flutter_test/flutter_test.dart';
import 'package:lumifx/src/core/color/light_color.dart';
import 'package:lumifx/src/core/effects/effect.dart';
import 'package:lumifx/src/core/effects/effect_event.dart';
import 'package:lumifx/src/core/effects/engine/effect_renderer.dart';
import 'package:lumifx/src/core/effects/engine/effect_player.dart';
import 'package:lumifx/src/core/effects/engine/light_frame.dart';
import 'package:lumifx/src/core/effects/engine/light_output.dart';

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
