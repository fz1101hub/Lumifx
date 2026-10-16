import 'package:flutter_test/flutter_test.dart';
import 'package:lumifx/src/core/color/light_color.dart';
import 'package:lumifx/src/core/effects/engine/light_frame.dart';
import 'package:lumifx/src/core/effects/engine/light_output.dart';
import 'package:lumifx/src/core/hue/hue_models.dart';
import 'package:lumifx/src/features/effects/playback_controller.dart';

class _Recording implements LightOutput {
  final updates = <Map<String, LightFrame>>[];

  @override
  void update(Map<String, LightFrame> frames, Duration tick) =>
      updates.add(frames);

  @override
  Future<void> close() async {}
}

void main() {
  final strip = HueLight.fromJson({
    'id': 'strip',
    'metadata': {'name': 'TV strip'},
    'on': {'on': true},
    'dimming': {'brightness': 50.0},
    'color': {
      'xy': {'x': 0.3, 'y': 0.3},
    },
    'gradient': {'points_capable': 5, 'points': <Object>[]},
  });
  final bulb = HueLight.fromJson({
    'id': 'bulb',
    'metadata': {'name': 'Bulb'},
    'on': {'on': true},
    'dimming': {'brightness': 50.0},
    'color': {
      'xy': {'x': 0.3, 'y': 0.3},
    },
  });

  test('gradient lights are read and get three segments', () {
    expect(strip.gradientPoints, 5);
    expect(strip.segments, HueLight.maxSegments);
    expect(bulb.segments, 1);
    expect(lightOfSlot('strip#2'), 'strip');
    expect(lightOfSlot('bulb'), 'bulb');
  });

  test('segment frames become one gradient command per light', () {
    final commands = lightCommands(
      {'strip': strip, 'bulb': bulb},
      {
        'strip#1': const LightFrame(LightColor(0, 1, 0), 0.5),
        'strip#0': const LightFrame(LightColor(1, 0, 0), 1.0),
        'strip#2': const LightFrame(LightColor(0, 0, 1), 0.25),
        'bulb': const LightFrame(LightColor(1, 1, 1), 0.8),
      },
      transition: const Duration(milliseconds: 300),
    );
    expect(commands.keys, unorderedEquals(['strip', 'bulb']));
    final json = commands['strip']!.toJson();
    final points = (json['gradient']! as Map)['points']! as List;
    expect(points, hasLength(3));
    expect(json['dimming'], {'brightness': 100.0},
        reason: 'the brightest segment sets the light');
    // In order: red first, even though it came second.
    final first = ((points.first as Map)['color'] as Map)['xy'] as Map;
    expect(first['x'], greaterThan(0.6));
    expect(json['dynamics'], {'duration': 300});
    expect(commands['bulb']!.toJson().containsKey('gradient'), isFalse);
  });

  test('a strip showing a gradient gets it back when the effect stops', () {
    final showing = HueLight.fromJson({
      'id': 'strip',
      'on': {'on': true},
      'dimming': {'brightness': 40.0},
      'color': {
        'xy': {'x': 0.3, 'y': 0.3},
      },
      'gradient': {
        'points_capable': 5,
        'points': [
          {
            'color': {
              'xy': {'x': 0.6, 'y': 0.3},
            },
          },
          {
            'color': {
              'xy': {'x': 0.2, 'y': 0.1},
            },
          },
        ],
      },
    });
    final json = showing.restoreCommand.toJson();
    expect((json['gradient']! as Map)['points'], hasLength(2));
    expect(json.containsKey('color'), isFalse);
    expect(strip.restoreCommand.toJson().containsKey('gradient'), isFalse,
        reason: 'a strip showing one colour gets that colour back');
  });

  test('a dark strip is switched off', () {
    final command = HueLightCommand.gradient(
      const [LightColor(1, 0, 0), LightColor(0, 1, 0)],
      const [0, 0.001],
    );
    expect(command.toJson(), {
      'on': {'on': false},
    });
  });

  test('the rate limiter sees one frame per strip, the command all three', () {
    final inner = _Recording();
    final segments = <String, Map<String, LightFrame>>{};
    final output = GradientLightOutput(inner, segments);
    output.update({
      'strip#0': const LightFrame(LightColor(1, 0, 0), 1),
      'strip#1': const LightFrame(LightColor(0, 1, 0), 1),
      'strip#2': const LightFrame(LightColor(0, 0, 1), 1),
      'bulb': const LightFrame(LightColor(1, 1, 1), 1),
    }, const Duration(milliseconds: 100));
    expect(inner.updates.single.keys, unorderedEquals(['strip', 'bulb']));
    expect(segments['strip'], hasLength(3));

    // The same colours in another order still count as a change.
    output.update({
      'strip#0': const LightFrame(LightColor(0, 0, 1), 1),
      'strip#1': const LightFrame(LightColor(0, 1, 0), 1),
      'strip#2': const LightFrame(LightColor(1, 0, 0), 1),
      'bulb': const LightFrame(LightColor(1, 1, 1), 1),
    }, const Duration(milliseconds: 100));
    final before = inner.updates.first['strip']!;
    final after = inner.updates.last['strip']!;
    expect(
      (before.color.r - after.color.r).abs() +
          (before.color.b - after.color.b).abs(),
      greaterThan(0.1),
    );
  });
}
