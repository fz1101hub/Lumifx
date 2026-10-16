import 'package:flutter_test/flutter_test.dart';
import 'package:lumifx/src/core/audio/audio_input.dart';
import 'package:lumifx/src/core/effects/engine/effect_renderer.dart';
import 'package:lumifx/src/features/library/preferences_controller.dart';
import 'package:lumifx/src/features/library/user_scene.dart';
import 'package:lumifx/src/features/playlists/playlist.dart';

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
    await first.setVariant('aurora', 'rose_gold');
    await first.setVariant('ocean', 'lagoon');
    await first.setVariant('ocean', null);
    await first.setLightExcluded('r1', 'l2', true);
    await first.setLightExcluded('r1', 'l3', true);
    await first.setLightExcluded('r1', 'l2', false);
    await first.setMusicSource(MusicSource.phoneAudio);
    await first.saveUserScene(const UserScene(
      id: 'user:1',
      name: 'Mine',
      colors: ['#FF0000', '#00FF00', '#0000FF'],
      motion: SceneMotion.flicker,
    ));
    await first.savePlaylist(const Playlist(
      id: 'p1',
      name: 'Evening',
      effectIds: ['ocean', 'user:1'],
      each: Duration(minutes: 5),
      shuffle: true,
    ));

    final second = PreferencesController(store: store);
    await second.load();
    expect(second.musicSource, MusicSource.phoneAudio);
    expect(second.userScenes.single.colors, hasLength(3));
    expect(second.userScenes.single.motion, SceneMotion.flicker);
    final playlist = second.playlists.single;
    expect(playlist.name, 'Evening');
    expect(playlist.effectIds, ['ocean', 'user:1']);
    expect(playlist.each, const Duration(minutes: 5));
    expect(playlist.shuffle, isTrue);

    // Deleting the scene takes it out of the playlist too.
    await second.deleteUserScene('user:1');
    expect(second.userScenes, isEmpty);
    expect(second.playlists.single.effectIds, ['ocean']);
    expect(second.softFlashes, isTrue);
    expect(second.flashWarningShown, isTrue);
    expect(second.variantOf('aurora'), 'rose_gold');
    expect(second.variantOf('ocean'), isNull);
    expect(second.excludedLights('r1'), ['l3']);
    expect(second.excludedLights('r2'), isEmpty);
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
