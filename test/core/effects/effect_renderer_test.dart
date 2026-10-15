import 'package:flutter_test/flutter_test.dart';
import 'package:lumifx/src/core/color/light_color.dart';
import 'package:lumifx/src/core/effects/effect.dart';
import 'package:lumifx/src/core/effects/effect_event.dart';
import 'package:lumifx/src/core/effects/engine/effect_renderer.dart';
import 'package:lumifx/src/features/effects/catalog/builtin_scenes.dart';
import 'package:lumifx/src/features/effects/catalog/builtin_stories.dart';
import 'package:lumifx/src/features/effects/catalog/effect_catalog.dart';

const _knownTypes = {
  EffectEventTypes.ambientPalette,
  EffectEventTypes.magicFlash,
  EffectEventTypes.travel,
  EffectEventTypes.surprise,
  EffectEventTypes.dim,
  EffectEventTypes.lightning,
  EffectEventTypes.beat,
  EffectEventTypes.music,
  EffectEventTypes.footsteps,
};

LightingEffect _effect(List<EffectEvent> events, {Duration? loop}) =>
    LightingEffect(
      id: 'test',
      name: 'Test',
      kind: EffectKind.story,
      events: events,
      loopDuration: loop,
    );

const _greenAmbient = EffectEvent(
  at: Duration.zero,
  duration: Duration(seconds: 10),
  type: EffectEventTypes.ambientPalette,
  parameters: {
    'palette': <String>['#00FF00'],
    'brightnessMin': 0.5,
    'brightnessMax': 0.5,
  },
);

void main() {
  group('colour variants', () {
    test('withPalette swaps every palette and nothing else', () {
      final rose = aurora.withVariant('rose_gold');
      expect(rose.id, aurora.id);
      expect(rose.events.length, aurora.events.length);
      expect(rose.events.single.parameters['palette'],
          aurora.variants.first.palette);
      expect(rose.events.single.parameters['speed'],
          aurora.events.single.parameters['speed']);
      // Unknown ids keep the original colours.
      expect(aurora.withVariant('nope'), same(aurora));
      expect(aurora.withVariant(null), same(aurora));
      // Disco: beats carry palettes too.
      final neon = disco.withVariant('neon');
      for (final event in neon.events) {
        if (event.parameters.containsKey('palette')) {
          expect(event.parameters['palette'], disco.variants.first.palette);
        }
      }
    });

    test('a variant renders different colours at the same instant', () {
      final classic = EffectRenderer(aurora, slotCount: 3, seed: 1)
          .render(const Duration(seconds: 5));
      final rose =
          EffectRenderer(aurora.withVariant('rose_gold'), slotCount: 3, seed: 1)
              .render(const Duration(seconds: 5));
      expect(rose.first.color, isNot(classic.first.color));
      expect(rose.first.brightness, closeTo(classic.first.brightness, 1e-9));
    });

    test('the renderer can swap effects mid-playback', () {
      final renderer = EffectRenderer(aurora, slotCount: 2, seed: 1);
      final before = renderer.render(const Duration(seconds: 3));
      renderer.effect = aurora.withVariant('ice');
      final after = renderer.render(const Duration(seconds: 3));
      expect(after.first.color, isNot(before.first.color));
      expect(renderer.cycleLength, aurora.cycleLength);
    });
  });

  group('EffectRenderer', () {
    test('is deterministic for the same seed and instant', () {
      final a = EffectRenderer(emeraldTrickster, slotCount: 5, seed: 42);
      final b = EffectRenderer(emeraldTrickster, slotCount: 5, seed: 42);
      for (var ms = 0; ms < 40000; ms += 333) {
        final t = Duration(milliseconds: ms);
        expect(a.render(t), b.render(t), reason: 'at $t');
      }
    });

    test('ambient palette sets every light', () {
      final renderer = EffectRenderer(_effect([_greenAmbient]), slotCount: 3);
      final frames = renderer.render(const Duration(seconds: 2));
      expect(frames, hasLength(3));
      for (final frame in frames) {
        expect(frame.color, const LightColor(0, 1, 0));
        expect(frame.brightness, closeTo(0.5, 1e-9));
      }
    });

    test('ambient background persists until the next ambient event', () {
      final effect = _effect(
        [
          _greenAmbient,
          const EffectEvent(
            at: Duration(seconds: 20),
            duration: Duration(seconds: 5),
            type: EffectEventTypes.ambientPalette,
            parameters: {
              'palette': <String>['#FF0000'],
              'brightnessMin': 0.5,
              'brightnessMax': 0.5,
            },
          ),
        ],
        loop: const Duration(seconds: 30),
      );
      final renderer = EffectRenderer(effect, slotCount: 2);
      // In the gap after the first ambient ends, green still shows.
      expect(renderer.render(const Duration(seconds: 15)).first.color,
          const LightColor(0, 1, 0));
      expect(renderer.render(const Duration(seconds: 22)).first.color,
          const LightColor(1, 0, 0));
      // After the last ambient ends it keeps showing until the loop restarts.
      expect(renderer.render(const Duration(seconds: 28)).first.color,
          const LightColor(1, 0, 0));
    });

    test('a flash on a random light touches exactly one light', () {
      final effect = _effect([
        _greenAmbient,
        const EffectEvent(
          at: Duration(seconds: 1),
          duration: Duration(seconds: 1),
          type: EffectEventTypes.magicFlash,
          parameters: {'color': '#FF0000', 'target': 'random_light'},
        ),
      ]);
      final renderer = EffectRenderer(effect, slotCount: 6, seed: 7);
      final frames = renderer.render(const Duration(milliseconds: 1150));
      final changed =
          frames.where((f) => f.color != const LightColor(0, 1, 0)).toList();
      expect(changed, hasLength(1));
      expect(changed.single.color.r, greaterThan(0.9));
    });

    test('dim lowers brightness of every light', () {
      final effect = _effect([
        _greenAmbient,
        const EffectEvent(
          at: Duration(seconds: 2),
          duration: Duration(seconds: 4),
          type: EffectEventTypes.dim,
          parameters: {'level': 0.1},
        ),
      ]);
      final renderer = EffectRenderer(effect, slotCount: 4);
      for (final frame in renderer.render(const Duration(seconds: 4))) {
        expect(frame.brightness, closeTo(0.05, 1e-9));
      }
    });

    test('sweep travel moves from the first to the last light', () {
      final effect = _effect([
        const EffectEvent(
          at: Duration.zero,
          duration: Duration(seconds: 10),
          type: EffectEventTypes.travel,
          parameters: {'color': '#FFFFFF', 'pattern': 'sweep'},
        ),
      ]);
      final renderer = EffectRenderer(effect, slotCount: 5);
      int brightest(Duration t) {
        final frames = renderer.render(t);
        var best = 0;
        for (var i = 1; i < frames.length; i++) {
          if (frames[i].brightness > frames[best].brightness) {
            best = i;
          }
        }
        return best;
      }

      expect(brightest(const Duration(seconds: 2)), lessThanOrEqualTo(1));
      expect(brightest(const Duration(seconds: 5)), 2);
      expect(brightest(const Duration(seconds: 8)), greaterThanOrEqualTo(3));
    });

    test('random events vary between passes of the loop', () {
      final effect = _effect(
        [
          _greenAmbient,
          const EffectEvent(
            at: Duration(seconds: 1),
            duration: Duration(seconds: 1),
            type: EffectEventTypes.magicFlash,
            parameters: {'color': '#FF0000'},
          ),
        ],
        loop: const Duration(seconds: 10),
      );
      final renderer = EffectRenderer(effect, slotCount: 8, seed: 1);
      final targets = <int>{};
      for (var pass = 0; pass < 10; pass++) {
        final frames =
            renderer.render(Duration(seconds: pass * 10, milliseconds: 1150));
        targets.add(frames.indexWhere((f) => f.color.r > 0.5));
      }
      expect(targets.length, greaterThan(1));
    });

    test('brightness control scales output', () {
      final renderer = EffectRenderer(
        _effect([_greenAmbient]),
        slotCount: 1,
        controls: const EffectControls(brightness: 0.5),
      );
      expect(renderer.render(Duration.zero).single.brightness,
          closeTo(0.25, 1e-9));
    });

    test('works with a single light', () {
      final renderer = EffectRenderer(emeraldTrickster, slotCount: 1);
      for (var ms = 0; ms < 40000; ms += 250) {
        final frames = renderer.render(Duration(milliseconds: ms));
        expect(frames, hasLength(1));
        expect(frames.single.brightness, inInclusiveRange(0, 1));
      }
    });
  });

  group('streaming events', () {
    test('lightning strikes are short and bright', () {
      final effect = _effect([
        _greenAmbient,
        const EffectEvent(
          at: Duration(seconds: 1),
          duration: Duration(seconds: 1),
          type: EffectEventTypes.lightning,
          parameters: {'strikes': 3, 'target': 'all'},
        ),
      ], loop: const Duration(seconds: 10));
      final renderer = EffectRenderer(effect, slotCount: 2, seed: 9);
      var litSamples = 0;
      var peak = 0.0;
      // Sample at 100 Hz, finer than the strikes.
      for (var ms = 1000; ms < 2000; ms += 10) {
        final frame = renderer.render(Duration(milliseconds: ms)).first;
        if (frame.color.b > 0.5) {
          litSamples++;
          peak = frame.brightness > peak ? frame.brightness : peak;
        }
      }
      expect(peak, greaterThan(0.55));
      // Three strikes of at most 130 ms each.
      expect(litSamples, inInclusiveRange(1, 39));
    });

    test('beat pulses once per beat', () {
      final effect = _effect([
        const EffectEvent(
          at: Duration.zero,
          duration: Duration(seconds: 10),
          type: EffectEventTypes.beat,
          parameters: {
            'bpm': 120,
            'palette': <String>['#FF0000'],
            'decay': 0.5,
            'brightnessMin': 0.0,
          },
        ),
      ]);
      final renderer = EffectRenderer(effect, slotCount: 1);
      // 120 BPM: a beat every 500 ms, lit for the first 250 ms.
      double at(int ms) =>
          renderer.render(Duration(milliseconds: ms)).single.brightness;
      expect(at(1000), greaterThan(0.9));
      expect(at(1100), lessThan(at(1000)));
      expect(at(1300), lessThan(0.01));
      expect(at(1500), greaterThan(0.9));
    });

    test('chase lights one slot at a time', () {
      final effect = _effect([
        const EffectEvent(
          at: Duration.zero,
          duration: Duration(seconds: 10),
          type: EffectEventTypes.beat,
          parameters: {'bpm': 60, 'pattern': 'chase', 'brightnessMin': 0.0},
        ),
      ]);
      final renderer = EffectRenderer(effect, slotCount: 4);
      final frames = renderer.render(const Duration(milliseconds: 2050));
      final lit = [for (final f in frames) f.brightness > 0.5];
      expect(lit, [false, false, true, false]);
    });

    test('chance skips an event on some passes only', () {
      final effect = _effect([
        _greenAmbient,
        const EffectEvent(
          at: Duration(seconds: 1),
          duration: Duration(seconds: 1),
          type: EffectEventTypes.magicFlash,
          parameters: {'color': '#FF0000', 'target': 'all', 'chance': 0.5},
        ),
      ], loop: const Duration(seconds: 10));
      final renderer = EffectRenderer(effect, slotCount: 1, seed: 4);
      var fired = 0;
      for (var pass = 0; pass < 40; pass++) {
        final frame = renderer
            .render(Duration(seconds: pass * 10, milliseconds: 1150))
            .single;
        if (frame.color.r > 0.5) {
          fired++;
        }
      }
      expect(fired, inInclusiveRange(8, 32));
    });
  });

  group('footsteps', () {
    LightingEffect steps(Map<String, Object> parameters) => _effect([
          _greenAmbient,
          EffectEvent(
            at: Duration.zero,
            duration: const Duration(seconds: 4),
            type: EffectEventTypes.footsteps,
            parameters: {'color': '#FF0000', ...parameters},
          ),
        ], loop: const Duration(seconds: 10));

    int? stepAt(EffectRenderer renderer, int ms) {
      final frames = renderer.render(Duration(milliseconds: ms));
      final index = frames.indexWhere((f) => f.color.r > 0.3);
      return index < 0 ? null : index;
    }

    test('approach crosses the room one lamp per step', () {
      final renderer = EffectRenderer(
        steps({'steps': 4, 'interval': 1000, 'pattern': 'approach'}),
        slotCount: 4,
        seed: 2,
      );
      // Sample just after each step lands.
      final path = [
        for (var k = 0; k < 4; k++) stepAt(renderer, k * 1000 + 40)
      ];
      expect(path, anyOf(equals([0, 1, 2, 3]), equals([3, 2, 1, 0])));
      // Quiet between steps.
      expect(stepAt(renderer, 600), isNull);
    });

    test('crescendo makes later steps brighter', () {
      final renderer = EffectRenderer(
        steps({'steps': 4, 'interval': 1000, 'crescendo': 1.0}),
        slotCount: 4,
      );
      double peakOf(int k) => renderer
          .render(Duration(milliseconds: k * 1000 + 22))
          .map((f) => f.color.r > 0.3 ? f.brightness : 0.0)
          .reduce((a, b) => a > b ? a : b);
      expect(peakOf(3), greaterThan(peakOf(0) * 2));
    });

    test('shake dims the other lights on a step', () {
      final renderer = EffectRenderer(
        steps({'steps': 2, 'interval': 1000, 'shake': 0.8}),
        slotCount: 3,
      );
      final frames = renderer.render(const Duration(milliseconds: 22));
      final others = frames.where((f) => f.color.r < 0.3);
      expect(others, isNotEmpty);
      for (final frame in others) {
        expect(frame.brightness, lessThan(0.3));
      }
    });
  });

  group('catalog', () {
    test('has unique ids', () {
      final ids = effectCatalog.map((e) => e.id).toSet();
      expect(ids.length, effectCatalog.length);
    });

    test('uses only event types the renderer understands', () {
      for (final effect in effectCatalog) {
        for (final event in effect.events) {
          expect(_knownTypes, contains(event.type),
              reason: '${effect.id} uses ${event.type}');
        }
      }
    });

    test('every effect renders valid frames for its whole cycle', () {
      for (final effect in effectCatalog) {
        for (final slots in [1, 2, 4, 9]) {
          final renderer = EffectRenderer(effect, slotCount: slots, seed: 3);
          final step = renderer.cycleLength ~/ 200;
          for (var t = Duration.zero; t < renderer.cycleLength; t += step) {
            for (final frame in renderer.render(t)) {
              expect(frame.brightness, inInclusiveRange(0, 1),
                  reason: '${effect.id} at $t with $slots lights');
            }
          }
        }
      }
    });

    test('zero lights is rejected', () {
      expect(() => EffectRenderer(emeraldTrickster, slotCount: 0),
          throwsArgumentError);
    });

    test('malformed colours fall back instead of crashing', () {
      final effect = _effect([
        const EffectEvent(
          at: Duration.zero,
          duration: Duration(seconds: 5),
          type: EffectEventTypes.ambientPalette,
          parameters: {
            'palette': <Object>['#FF0000', 'nope', 12, '#00FF00'],
            'brightnessMin': 0.5,
            'brightnessMax': 0.5,
          },
        ),
        const EffectEvent(
          at: Duration(seconds: 1),
          duration: Duration(seconds: 1),
          type: EffectEventTypes.magicFlash,
          parameters: {'color': 'bad', 'target': 'all'},
        ),
      ]);
      final frames = EffectRenderer(effect, slotCount: 2)
          .render(const Duration(milliseconds: 1100));
      expect(frames, hasLength(2));
    });

    test('consecutive beat sections do not dip at the boundary', () {
      final effect = _effect([
        const EffectEvent(
          at: Duration.zero,
          duration: Duration(seconds: 2),
          type: EffectEventTypes.beat,
          parameters: {'bpm': 600, 'brightnessMin': 0.5, 'decay': 1.0},
        ),
        const EffectEvent(
          at: Duration(seconds: 2),
          duration: Duration(seconds: 2),
          type: EffectEventTypes.beat,
          parameters: {'bpm': 600, 'brightnessMin': 0.5, 'decay': 1.0},
        ),
      ]);
      final renderer = EffectRenderer(effect, slotCount: 1);
      final atBoundary =
          renderer.render(const Duration(milliseconds: 1995)).single;
      expect(atBoundary.brightness, greaterThan(0.4));
    });
  });
}
