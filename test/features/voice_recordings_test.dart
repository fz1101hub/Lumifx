import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumifx/src/core/speech/speaker.dart';
import 'package:lumifx/src/core/speech/voice_recordings.dart';
import 'package:lumifx/src/features/bridge/bridge_controller.dart';
import 'package:lumifx/src/features/bridge/credential_store.dart';
import 'package:lumifx/src/features/effects/playback_controller.dart';
import 'package:lumifx/src/features/effects/read_aloud.dart';
import 'package:lumifx/src/features/library/effect_library.dart';
import 'package:lumifx/src/features/library/preferences_controller.dart';
import 'package:lumifx/src/features/library/user_scene.dart';
import 'package:lumifx/src/features/library/user_story.dart';

import '../support/fake_audio_input.dart';
import '../support/fake_camera_input.dart';
import '../support/fake_sound_player.dart';

class _FakeSpeaker implements Speaker {
  final said = <String>[];

  @override
  Future<void> speak(String text, String language) async => said.add(text);

  @override
  Future<void> stop() async {}
}

class _FakeVoicePlayer implements VoicePlayer {
  final played = <String>[];
  int stops = 0;

  @override
  Future<void> play(String path) async => played.add(path);

  @override
  Future<void> stop() async => stops++;
}

final _story = UserStory(
  id: 'story:7',
  name: 'Grandma tells',
  colors: const ['#000033', '#112266'],
  motion: SceneMotion.calm,
  length: 30,
  moments: const [
    StoryMoment(at: 0, kind: StoryMomentKind.wordsOnly, words: 'Once upon'),
    StoryMoment(at: 5, kind: StoryMomentKind.spark, words: 'a time'),
  ],
);

void main() {
  late Directory temp;

  setUp(() async => temp = await Directory.systemTemp.createTemp('voices'));
  tearDown(() async => temp.delete(recursive: true));

  test('recordings are kept per story and second, and found again', () async {
    final voices = FileVoiceRecordings(() async => temp);
    await voices.load();
    expect(voices.hasAny('story:7'), isFalse);
    final path = await voices.newPath('story:7', 5);
    expect(path, endsWith('/story_7/5.m4a'));
    await File(path).writeAsBytes([1, 2, 3]);
    voices.saved('story:7', 5);
    expect(voices.pathOf('story:7', 5), path);
    expect(voices.pathOf('story:7', 0), isNull);

    // An empty file (a recording cut short) does not count.
    await File(await voices.newPath('story:7', 9)).writeAsBytes([]);
    final again = FileVoiceRecordings(() async => temp);
    await again.load();
    expect(again.pathOf('story:7', 5), path);
    expect(again.pathOf('story:7', 9), isNull);

    await again.delete('story:7', 5);
    expect(File(path).existsSync(), isFalse);
    expect(again.hasAny('story:7'), isFalse);
    await again.newPath('story:7', 1);
    await again.deleteStory('story:7');
    expect(Directory('${temp.path}/story_7').existsSync(), isFalse);
  });

  test('a recorded line plays in its place, read aloud or not', () async {
    final bridge = BridgeController(store: InMemoryCredentialStore());
    await bridge.initialize();
    final preferences = PreferencesController(store: InMemoryKeyValueStore());
    await preferences.saveUserStory(_story);
    final library = EffectLibrary(preferences);
    final playback = PlaybackController(
      effect: library.byId('story:7')!,
      bridge: bridge,
      preferences: preferences,
      audioInput: FakeAudioInput(),
      resolveEffect: library.byId,
      sound: FakeSoundPlayer(),
      camera: FakeCameraInput(),
    );
    final voices = FileVoiceRecordings(() async => temp);
    await voices.load();
    final recording = await voices.newPath('story:7', 0);
    await File(recording).writeAsBytes([1]);
    voices.saved('story:7', 0);
    final speaker = _FakeSpeaker();
    final player = _FakeVoicePlayer();
    final readAloud = ReadAloud(
      playback: playback,
      preferences: preferences,
      library: library,
      speaker: speaker,
      locale: () => const Locale('en'),
      voices: voices,
      voicePlayer: player,
    )..start();

    await playback.start();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(player.played, [recording], reason: 'read aloud is off');
    playback.player!.advance(const Duration(seconds: 5));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(speaker.said, isEmpty, reason: 'no voice for an unrecorded line');

    await preferences.setReadAloud(true);
    await playback.stop(restore: false);
    await playback.start();
    playback.player!.advance(const Duration(seconds: 5));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(speaker.said, ['a time'], reason: 'the phone reads the rest');
    expect(player.played, [recording, recording]);

    await playback.pause();
    expect(player.stops, greaterThan(0));
    readAloud.dispose();
    await playback.stop(restore: false);
    playback.dispose();
  });
}
