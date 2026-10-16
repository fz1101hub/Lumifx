import 'package:flutter_test/flutter_test.dart';
import 'package:lumifx/src/core/color/light_color.dart';
import 'package:lumifx/src/core/effects/engine/effect_player.dart';
import 'package:lumifx/src/core/effects/engine/light_frame.dart';
import 'package:lumifx/src/core/effects/engine/light_output.dart';
import 'package:lumifx/src/core/hue/hue_models.dart';
import 'package:lumifx/src/features/effects/catalog/builtin_scenes.dart';

void main() {
  test('xy back to a colour and forth again', () {
    for (final colour in const [
      LightColor(1, 0, 0),
      LightColor(0, 1, 0),
      LightColor(0, 0, 1),
      LightColor(1, 0.6, 0.1),
      LightColor(0.3, 0.2, 1),
    ]) {
      final xy = colour.toXy();
      final back = LightColor.fromXy(xy.x, xy.y).toXy();
      expect(back.x, closeTo(xy.x, 0.01), reason: '$colour');
      expect(back.y, closeTo(xy.y, 0.01), reason: '$colour');
    }
  });

  test('warm whites are orange, cool whites are blue', () {
    final warm = LightColor.fromMirek(454); // 2200 K
    final cool = LightColor.fromMirek(153); // 6500 K
    expect(warm.r, greaterThan(warm.b));
    expect(cool.b, greaterThan(warm.b));
  });

  test('a light knows what it shows', () {
    final off = HueLight.fromJson({
      'id': 'a',
      'on': {'on': false},
      'dimming': {'brightness': 80.0},
    });
    expect(off.currentFrame.brightness, 0);
    final red = HueLight.fromJson({
      'id': 'b',
      'on': {'on': true},
      'dimming': {'brightness': 50.0},
      'color': {
        'xy': {'x': 0.675, 'y': 0.322},
      },
    });
    expect(red.currentFrame.brightness, 0.5);
    expect(red.currentFrame.color.r, 1);
    expect(red.currentFrame.color.b, lessThan(0.2));
  });

  test('a gentle start shows the lights as they were, then the effect', () {
    final player = EffectPlayer(
      effect: ocean,
      lightIds: const ['a', 'b'],
      output: const NullLightOutput(),
    );
    const before = [
      LightFrame(LightColor(1, 1, 1), 0.9),
      LightFrame.off,
    ];
    player.fadeInFrom(before, over: const Duration(seconds: 2));
    player.advance(Duration.zero);
    expect(player.currentFrames.first.brightness, closeTo(0.9, 0.01));
    expect(player.currentFrames.last.brightness, closeTo(0, 0.01));
    player.advance(const Duration(seconds: 3));
    expect(player.currentFrames.first.color, isNot(const LightColor(1, 1, 1)));
  });
}
