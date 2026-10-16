import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumifx/src/core/camera/screen_sampler.dart';
import 'package:lumifx/src/core/color/light_color.dart';
import 'package:lumifx/src/core/effects/engine/effect_renderer.dart';
import 'package:lumifx/src/features/effects/catalog/builtin_interactive.dart';
import 'package:lumifx/src/features/tv/camera_input.dart';
import 'package:lumifx/src/features/tv/tv_sync_controller.dart';

import '../support/fake_camera_input.dart';

const _red = LightColor(1, 0, 0);
const _green = LightColor(0, 1, 0);
const _blue = LightColor(0, 0, 1);

void main() {
  test('the lights share the zones out left to right', () {
    const screen = ScreenColors(
      [_red, _red, _green, _green, _blue, _blue],
      [1, 1, 1, 1, 0.5, 0.5],
    );
    final three = EffectRenderer(tvSync, slotCount: 3, seed: 1)
        .render(const Duration(seconds: 1), screen: screen);
    expect(three.map((f) => f.color), [_red, _green, _blue]);
    expect(three.last.brightness, closeTo(0.02 + 0.98 * 0.5, 1e-9));

    // More lights than zones: neighbours share one.
    final eight = EffectRenderer(tvSync, slotCount: 8, seed: 1)
        .render(const Duration(seconds: 1), screen: screen);
    expect(eight.first.color, _red);
    expect(eight.last.color, _blue);

    // One light: the whole picture.
    final one = EffectRenderer(tvSync, slotCount: 1, seed: 1)
        .render(const Duration(seconds: 1), screen: screen);
    expect(one.single.brightness, closeTo(0.02 + 0.98 * (5 / 6), 1e-9));

    // No picture yet: the dim background.
    final none = EffectRenderer(tvSync, slotCount: 3, seed: 1)
        .render(const Duration(seconds: 1));
    expect(none.every((f) => f.brightness <= 0.1), isTrue);
  });

  test('a black picture dims the lights without changing their colour', () {
    final dark = EffectRenderer(tvSync, slotCount: 2, seed: 1).render(
      const Duration(seconds: 1),
      screen: const ScreenColors([LightColor.black], [0]),
    );
    for (final frame in dark) {
      expect(frame.brightness, closeTo(0.02, 1e-9));
      expect(frame.color, isNot(LightColor.black));
    }
  });

  test('colours are smoothed, and dropped when the camera stalls', () {
    fakeAsync((async) {
      final camera = FakeCameraInput();
      final tv = TvSyncController(camera);
      tv.start();
      async.flushMicrotasks();
      expect(tv.status, TvSyncStatus.watching);
      expect(tv.colors, isNull, reason: 'nothing seen yet');
      expect(tv.buildPreview(), isNotNull);

      camera.show(const ScreenColors([_red], [1]));
      expect(tv.colors!.colors.single, _red);
      camera.show(const ScreenColors([_blue], [0]));
      expect(tv.colors!.colors.single, const LightColor(0.5, 0, 0.5));
      expect(tv.colors!.levels.single, 0.5);

      async.elapse(const Duration(seconds: 2));
      expect(tv.colors, isNull, reason: 'no frames for a while');

      tv.stop();
      async.flushMicrotasks();
      expect(tv.status, TvSyncStatus.idle);
      expect(camera.isRunning, isFalse);
      camera.show(const ScreenColors([_red], [1]));
      expect(tv.colors, isNull);
      tv.dispose();
    });
  });

  test('a stop while the camera opens wins', () {
    fakeAsync((async) {
      final camera = FakeCameraInput();
      final tv = TvSyncController(camera);
      tv.start();
      tv.stop();
      async.flushMicrotasks();
      expect(tv.status, TvSyncStatus.idle);
      expect(camera.isRunning, isFalse);
      tv.dispose();
    });
  });

  test('refused or missing cameras are told apart', () {
    fakeAsync((async) {
      final tv =
          TvSyncController(FakeCameraInput(result: CameraStartResult.denied));
      tv.start();
      async.flushMicrotasks();
      expect(tv.status, TvSyncStatus.denied);
      expect(tv.colors, isNull);

      final none = TvSyncController(const NoCameraInput());
      none.start();
      async.flushMicrotasks();
      expect(none.status, TvSyncStatus.unavailable);
      tv.dispose();
      none.dispose();
    });
  });
}
