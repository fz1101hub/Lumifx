import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumifx/l10n/generated/app_localizations.dart';
import 'package:lumifx/src/core/speech/speaker.dart';
import 'package:lumifx/src/features/bridge/bridge_controller.dart';
import 'package:lumifx/src/features/bridge/credential_store.dart';
import 'package:lumifx/src/features/effects/catalog/builtin_scenes.dart';
import 'package:lumifx/src/features/effects/catalog/builtin_stories.dart';
import 'package:lumifx/src/features/effects/catalog/effect_catalog.dart';
import 'package:lumifx/src/features/effects/playback_controller.dart';
import 'package:lumifx/src/features/effects/read_aloud.dart';
import 'package:lumifx/src/features/library/effect_library.dart';
import 'package:lumifx/src/features/library/preferences_controller.dart';

import '../support/fake_audio_input.dart';
import '../support/fake_camera_input.dart';
import '../support/fake_sound_player.dart';

class _FakeSpeaker implements Speaker {
  final said = <(String, String)>[];
  int stops = 0;

  @override
  Future<void> speak(String text, String language) async =>
      said.add((text, language));

  @override
  Future<void> stop() async => stops++;
}

Future<void> _wait([int ms = 50]) =>
    Future<void>.delayed(Duration(milliseconds: ms));

void main() {
  late PreferencesController preferences;
  late PlaybackController playback;
  late _FakeSpeaker speaker;
  late ReadAloud readAloud;
  var locale = const Locale('it');

  setUp(() async {
    final bridge = BridgeController(store: InMemoryCredentialStore());
    await bridge.initialize();
    preferences = PreferencesController(store: InMemoryKeyValueStore());
    await preferences.setReadAloud(true);
    playback = PlaybackController(
      effect: emeraldTrickster,
      bridge: bridge,
      preferences: preferences,
      audioInput: FakeAudioInput(),
      resolveEffect: effectById,
      sound: FakeSoundPlayer(),
      camera: FakeCameraInput(),
    );
    speaker = _FakeSpeaker();
    locale = const Locale('it');
    readAloud = ReadAloud(
      playback: playback,
      preferences: preferences,
      library: EffectLibrary(preferences),
      speaker: speaker,
      locale: () => locale,
    )..start();
  });

  tearDown(() async {
    readAloud.dispose();
    await playback.stop(restore: false);
    playback.dispose();
  });

  final italian = lookupAppLocalizations(const Locale('it'));

  test('reads each line once, in the app language, as the story reaches it',
      () async {
    await playback.start();
    await _wait();
    expect(speaker.said, [(italian.narrationEmeraldTrickster1, 'it-IT')]);

    // The golden spark at 8 s comes with the second line.
    playback.player!.advance(const Duration(seconds: 8));
    await _wait();
    expect(speaker.said.map((s) => s.$1), [
      italian.narrationEmeraldTrickster1,
      italian.narrationEmeraldTrickster2,
    ]);

    // More frames inside the same line say nothing new.
    playback.player!.advance(const Duration(seconds: 1));
    await _wait();
    expect(speaker.said, hasLength(2));
  });

  test('quiet when paused, and picks up without repeating itself', () async {
    await playback.start();
    await _wait();
    await playback.pause();
    expect(speaker.stops, 1);

    await playback.resume();
    await _wait();
    expect(speaker.said, hasLength(1), reason: 'the same line, not again');
  });

  test('says nothing with the setting off, and stops when turned off',
      () async {
    await preferences.setReadAloud(false);
    await playback.start();
    await _wait();
    expect(speaker.said, isEmpty);

    await preferences.setReadAloud(true);
    await _wait();
    expect(speaker.said, hasLength(1));
    await preferences.setReadAloud(false);
    expect(speaker.stops, 1);
  });

  test('a story played again starts from its first words', () async {
    await playback.start();
    await _wait();
    await playback.stop(restore: false);
    await _wait();
    await playback.start();
    await _wait();
    expect(speaker.said.map((s) => s.$1), [
      italian.narrationEmeraldTrickster1,
      italian.narrationEmeraldTrickster1,
    ]);
  });

  test('another story cuts the words of the last one short', () async {
    await playback.start();
    await _wait();
    expect(speaker.stops, 0);
    await playback.switchEffect(enchantedFairy);
    await _wait();
    expect(speaker.stops, 1, reason: 'not queued after the old line');
    expect(speaker.said.map((s) => s.$1), [
      italian.narrationEmeraldTrickster1,
      italian.narrationEnchantedFairy1,
    ]);
  });

  test('scenes have no words to read', () async {
    await playback.switchEffect(ocean);
    await playback.start();
    await _wait();
    expect(speaker.said, isEmpty);
  });

  test('an unsupported phone language falls back to English', () async {
    locale = const Locale('sv');
    await playback.start();
    await _wait();
    final english = lookupAppLocalizations(const Locale('en'));
    expect(speaker.said, [(english.narrationEmeraldTrickster1, 'en-US')]);
  });

  test('every app language has a voice', () {
    for (final l in AppLocalizations.supportedLocales) {
      expect(speechLanguage(l.languageCode), startsWith(l.languageCode));
    }
  });
}
