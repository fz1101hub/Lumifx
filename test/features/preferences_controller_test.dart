import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumifx/src/features/bedtime/dream_diary.dart';
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

  test('dreams are kept per child, newest first, and read back', () async {
    final store = InMemoryKeyValueStore();
    final first = PreferencesController(store: store);
    await first.saveDream(Dream.told(
        id: 'd1', child: '', date: DateTime(2026, 10, 26, 7), words: 'snow'));
    await first.saveDream(Dream.told(
        id: 'd2', child: '', date: DateTime(2026, 10, 27, 7), words: 'qwerty'));
    await first.saveDream(Dream.told(
        id: 'd3', child: 'c2', date: DateTime(2026, 10, 27, 7), words: 'fire'));
    expect([for (final d in first.dreamsOf('')) d.id], ['d2', 'd1']);
    expect(first.dreamsOf('')[0].colors, Dream.dreamy,
        reason: 'no known word: dreamy colours');

    final second = PreferencesController(store: store);
    await second.load();
    expect(second.dreamsOf('c2').single.words, 'fire');
    expect(second.dreamsOf('c2').single.motion, SceneMotion.flicker);
    await second.deleteDream('d1');
    expect([for (final d in second.dreamsOf('')) d.id], ['d2']);
    expect(Dream.fromJson({'id': 'x'}), isNull);
  });

  test('bedtimes are kept per child, one per evening', () async {
    final store = InMemoryKeyValueStore();
    final first = PreferencesController(store: store);
    first.recordBedtime(DateTime(2026, 10, 26, 20, 40));
    first.recordBedtime(DateTime(2026, 10, 26, 21, 5));
    first.recordBedtime(DateTime(2026, 10, 28, 0, 20));
    first.recordBedtime(DateTime(2026, 10, 27, 20, 30), child: 'c2');
    expect(first.bedtimesOf(''), [
      DateTime(2026, 10, 26, 21, 5),
      DateTime(2026, 10, 28, 0, 20),
    ]);
    await Future<void>.delayed(Duration.zero);

    final second = PreferencesController(store: store);
    await second.load();
    expect(second.bedtimesOf('c2'), [DateTime(2026, 10, 27, 20, 30)]);
    expect(second.bedtimesOf(''), hasLength(2));
  });

  test('the games remember their best and the language chosen', () async {
    final store = InMemoryKeyValueStore();
    final first = PreferencesController(store: store);
    expect(first.recordCountingScore(4), isTrue);
    expect(first.recordCountingScore(3), isFalse);
    expect(first.recordPianoEcho(5), isTrue);
    expect(first.recordPianoEcho(4), isFalse);
    await first.setLearnLanguage('fr');
    expect(first.kidsActivities, isNull);
    await first.setKidsActivities(['piano']);
    expect(first.napMinutes, isNull);
    expect(first.teethTune, isTrue);
    await first.setNapMinutes(90);
    await first.setGoalTeam('brazil');
    await first.setToothFairy((child: 'c1', at: DateTime(2026, 10, 28, 6)));
    expect(first.speechVoiceFor('it-IT'), isNull);
    await first.setSpeechVoice('it-IT', 'com.apple.voice.enhanced.it-IT.Luca');
    await first.setSpeechVoice('de-DE', 'de-de-x-deb-local');
    await first.setSpeechVoice('de-DE', null);
    await first.setNoiseLimit('quiet');
    await first.setTeethTune(false);

    final second = PreferencesController(store: store);
    await second.load();
    expect(second.countingBest, 4);
    expect(second.learnLanguage, 'fr');
    expect(second.kidsActivities, ['piano']);
    expect(second.napMinutes, 90);
    expect(second.goalTeam, 'brazil');
    expect(second.toothFairy?.child, 'c1');
    expect(second.toothFairy?.at, DateTime(2026, 10, 28, 6));
    expect(
        second.speechVoices, {'it-IT': 'com.apple.voice.enhanced.it-IT.Luca'},
        reason: 'German went back to the automatic voice');
    expect(second.noiseLimit, 'quiet');
    expect(second.teethTune, isFalse);
    expect(second.pianoEchoBest, 5);
  });

  test('corrupt data is ignored', () async {
    final store = InMemoryKeyValueStore()
      ..values['lumifx.preferences.v1'] = '{not json';
    final preferences = PreferencesController(store: store);
    await preferences.load();
    expect(preferences.favorites, isEmpty);
  });

  test('a change while loading never wipes what was saved', () async {
    final store = _SlowStore();
    final first = PreferencesController(store: store);
    await first.load();
    await first.toggleFavorite('ocean');
    await first.addChild('Mia');
    await first.setKidsLocked(true);

    // The next start: the read is slow and something changes meanwhile.
    final second = PreferencesController(store: store);
    store.hold();
    final loading = second.load();
    await second.toggleFavorite('fireplace');
    expect(store.values.values.single, contains('ocean'),
        reason: 'nothing written while loading');
    store.release();
    await loading;
    await Future<void>.delayed(Duration.zero);

    final third = PreferencesController(store: store);
    await third.load();
    expect(third.favorites, contains('ocean'));
    expect(third.children.map((c) => c.name), contains('Mia'));
    expect(third.kidsLocked, isTrue);
  });
}

class _SlowStore extends InMemoryKeyValueStore {
  Completer<void>? _gate;

  void hold() => _gate = Completer<void>();
  void release() => _gate?.complete();

  @override
  Future<String?> read(String key) async {
    final value = values[key];
    await _gate?.future;
    return value;
  }
}
