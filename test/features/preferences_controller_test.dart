import 'package:flutter_test/flutter_test.dart';
import 'package:lumifx/src/core/effects/engine/effect_renderer.dart';
import 'package:lumifx/src/features/library/preferences_controller.dart';

void main() {
  test('favorites toggle, newest first', () async {
    final preferences = PreferencesController(store: InMemoryKeyValueStore());
    await preferences.toggleFavorite('ocean');
    await preferences.toggleFavorite('disco');
    expect(preferences.favorites, ['disco', 'ocean']);
    await preferences.toggleFavorite('ocean');
    expect(preferences.favorites, ['disco']);
  });

  test('recents are unique, newest first and capped', () async {
    final preferences = PreferencesController(store: InMemoryKeyValueStore());
    for (var i = 0; i < 12; i++) {
      await preferences.recordPlayed('effect-$i');
    }
    await preferences.recordPlayed('effect-5');
    expect(preferences.recents.first, 'effect-5');
    expect(preferences.recents, hasLength(PreferencesController.maxRecents));
    expect(preferences.recents.where((id) => id == 'effect-5'), hasLength(1));
  });

  test('everything survives a restart', () async {
    final store = InMemoryKeyValueStore();
    final first = PreferencesController(store: store);
    await first.toggleFavorite('ocean');
    await first.recordPlayed('disco');
    await first.setLastTarget('area:123');
    await first.setDefaultControls(
      const EffectControls(brightness: 0.4, intensity: 0.6, speed: 2),
    );
    await first.setSoftFlashes(true);
    await first.setFlashWarningShown(true);

    final second = PreferencesController(store: store);
    await second.load();
    expect(second.softFlashes, isTrue);
    expect(second.flashWarningShown, isTrue);
    expect(second.favorites, ['ocean']);
    expect(second.recents, ['disco']);
    expect(second.lastTarget, 'area:123');
    expect(second.defaultControls.brightness, 0.4);
    expect(second.defaultControls.intensity, 0.6);
    expect(second.defaultControls.speed, 2);
  });

  test('corrupt data is ignored', () async {
    final store = InMemoryKeyValueStore()
      ..values['lumifx.preferences.v1'] = '{not json';
    final preferences = PreferencesController(store: store);
    await preferences.load();
    expect(preferences.favorites, isEmpty);
  });
}
