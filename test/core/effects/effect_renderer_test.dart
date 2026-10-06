import 'package:flutter_test/flutter_test.dart';
import 'package:lumifx/src/core/color/light_color.dart';
import 'package:lumifx/src/core/effects/effect.dart';
import 'package:lumifx/src/core/effects/effect_event.dart';
import 'package:lumifx/src/core/effects/engine/effect_renderer.dart';
import 'package:lumifx/src/features/effects/catalog/builtin_stories.dart';
import 'package:lumifx/src/features/effects/catalog/effect_catalog.dart';

const _knownTypes = {
  EffectEventTypes.ambientPalette,
  EffectEventTypes.magicFlash,
  EffectEventTypes.travel,
  EffectEventTypes.surprise,
  EffectEventTypes.dim,
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
        final renderer = EffectRenderer(effect, slotCount: 4, seed: 3);
        final step = renderer.cycleLength ~/ 200;
        for (var t = Duration.zero; t < renderer.cycleLength; t += step) {
          for (final frame in renderer.render(t)) {
            expect(frame.brightness, inInclusiveRange(0, 1),
                reason: '${effect.id} at $t');
          }
        }
      }
    });
  });
}
