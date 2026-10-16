import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lumifx/src/core/audio/audio_input.dart';
import 'package:lumifx/src/core/color/light_color.dart';
import 'package:lumifx/src/core/hue/hue_bridge_client.dart';
import 'package:lumifx/src/core/hue/hue_models.dart';
import 'package:lumifx/src/core/screen_wake.dart';
import 'package:lumifx/src/features/bridge/bridge_controller.dart';
import 'package:lumifx/src/features/bridge/credential_store.dart';
import 'package:lumifx/src/features/effects/catalog/builtin_interactive.dart';
import 'package:lumifx/src/features/effects/catalog/builtin_scenes.dart';
import 'package:lumifx/src/features/effects/playback_controller.dart';
import 'package:lumifx/src/features/library/preferences_controller.dart';

import '../support/fake_audio_input.dart';

http.Response _json(Object body) => http.Response(jsonEncode(body), 200);

class _RecordingWake implements ScreenWake {
  final calls = <bool>[];

  @override
  Future<void> keepOn(bool on) async => calls.add(on);
}

/// A bridge with a color bulb (on, red), a white-ambiance bulb (on, warm
/// white) and a smart plug, all in one room.
class _FakeBridge {
  final puts = <(String, Map<String, Object?>)>[];

  /// When set, room loading waits for it: used to stop mid-start.
  Completer<void>? holdRefresh;
  int refreshes = 0;

  http.Client get client => MockClient((request) async {
        if (request.method == 'PUT') {
          puts.add((
            request.url.pathSegments.last,
            jsonDecode(request.body) as Map<String, Object?>,
          ));
          return _json({'data': <Object>[]});
        }
        switch (request.url.path) {
          case '/clip/v2/resource/light':
            refreshes++;
            await holdRefresh?.future;
            return _json({
              'data': [
                {
                  'id': 'color',
                  'owner': {'rid': 'd1', 'rtype': 'device'},
                  'metadata': {'name': 'Color bulb'},
                  'on': {'on': true},
                  'dimming': {'brightness': 80.0},
                  'color': {
                    'xy': {'x': 0.65, 'y': 0.3},
                  },
                  'color_temperature': {
                    'mirek': null,
                    'mirek_valid': false,
                    'mirek_schema': {
                      'mirek_minimum': 153,
                      'mirek_maximum': 500
                    },
                  },
                },
                {
                  'id': 'white',
                  'owner': {'rid': 'd2', 'rtype': 'device'},
                  'metadata': {'name': 'White bulb'},
                  'on': {'on': true},
                  'dimming': {'brightness': 40.0},
                  'color_temperature': {
                    'mirek': 366,
                    'mirek_valid': true,
                    'mirek_schema': {
                      'mirek_minimum': 153,
                      'mirek_maximum': 454
                    },
                  },
                },
                {
                  'id': 'plug',
                  'owner': {'rid': 'd3', 'rtype': 'device'},
                  'metadata': {'name': 'Plug'},
                  'on': {'on': false},
                },
              ],
            });
          case '/clip/v2/resource/room':
            return _json({
              'data': [
                {
                  'id': 'room',
                  'metadata': {'name': 'Den'},
                  'children': [
                    {'rid': 'd1', 'rtype': 'device'},
                    {'rid': 'd2', 'rtype': 'device'},
                    {'rid': 'd3', 'rtype': 'device'},
                  ],
                  'services': <Object>[],
                },
              ],
            });
        }
        return _json({'data': <Object>[]});
      });
}

Future<(PlaybackController, _FakeBridge, _RecordingWake)> _setUp({
  bool restoreLights = true,
  FakeAudioInput? audio,
  FakeAudioInput? phoneAudio,
  MusicSource musicSource = MusicSource.microphone,
  PreferencesController? preferences,
  bool music = false,
  Duration sleepFade = const Duration(seconds: 20),
}) async {
  final fake = _FakeBridge();
  final bridge = BridgeController(
    store: InMemoryCredentialStore(
      const HueCredentials(
        bridge: HueBridgeInfo(id: 'b', host: '10.0.0.2'),
        applicationKey: 'key',
      ),
    ),
    clientFactory: (pin, key) => HueBridgeClient(
        host: pin.host, client: fake.client, applicationKey: key),
  );
  await bridge.initialize();
  preferences ??= PreferencesController(store: InMemoryKeyValueStore());
  await preferences.setLastTarget('group:room');
  await preferences.setRestoreLights(restoreLights);
  await preferences.setMusicSource(musicSource);
  final wake = _RecordingWake();
  final controller = PlaybackController(
    effect: music ? moodGlow : ocean,
    bridge: bridge,
    preferences: preferences,
    audioInput: audio ?? FakeAudioInput(),
    phoneAudioInput: phoneAudio,
    screenWake: wake,
    sleepFade: sleepFade,
  );
  return (controller, fake, wake);
}

Future<void> _wait([int ms = 400]) =>
    Future<void>.delayed(Duration(milliseconds: ms));

void main() {
  test('plays on dimmable lights only and adapts commands to each', () async {
    final (controller, fake, wake) = await _setUp();
    expect(
      [for (final slot in controller.lightNames) (slot as NamedSlot).name],
      ['Color bulb', 'White bulb'],
    );

    await controller.start();
    expect(controller.status, PlaybackStatus.playing);
    expect(wake.calls, [true]);
    await _wait();

    final byLight = <String, List<Map<String, Object?>>>{};
    for (final (id, body) in fake.puts) {
      (byLight[id] ??= []).add(body);
    }
    expect(byLight.keys, isNot(contains('plug')));
    expect(byLight['color']!.first, contains('color'));
    final white = byLight['white']!.first;
    expect(white, isNot(contains('color')));
    final mirek = (white['color_temperature']! as Map)['mirek']! as int;
    expect(mirek, inInclusiveRange(153, 454));
    await controller.stop(restore: false);
    controller.dispose();
  });

  test('stop puts the lights back as they were', () async {
    final (controller, fake, wake) = await _setUp();
    await controller.start();
    await _wait(250);
    await controller.stop();
    expect(controller.status, PlaybackStatus.idle);
    expect(wake.calls.last, isFalse);
    fake.puts.clear();
    await _wait(900);

    final restored = {for (final (id, body) in fake.puts) id: body};
    expect(restored['color'], {
      'on': {'on': true},
      'dimming': {'brightness': 80.0},
      'color': {
        'xy': {'x': 0.65, 'y': 0.3},
      },
      'dynamics': {'duration': 400},
    });
    expect(restored['white'], {
      'on': {'on': true},
      'dimming': {'brightness': 40.0},
      'color_temperature': {'mirek': 366},
      'dynamics': {'duration': 400},
    });
    expect(restored, isNot(contains('plug')));
    controller.dispose();
  });

  test('the sleep timer fades out, then switches the lights off for good',
      () async {
    final (controller, fake, wake) =
        await _setUp(sleepFade: const Duration(milliseconds: 200));
    final notices = <PlaybackNotice>[];
    controller.notices.listen(notices.add);
    controller.setSleepTimer(const Duration(milliseconds: 300));
    await controller.start();
    expect(controller.sleepRemaining, isNotNull);
    expect(controller.isFadingOut, isFalse);

    await _wait(350);
    expect(controller.isFadingOut, isTrue);
    expect(controller.status, PlaybackStatus.playing);
    await _wait(350);
    expect(controller.status, PlaybackStatus.idle);
    expect(controller.isFadingOut, isFalse);
    expect(notices.map((n) => n.kind),
        contains(PlaybackNoticeKind.sleepTimerDone));
    expect(wake.calls.last, isFalse);

    // Instead of restoring the previous state, every light is switched off
    // (with a gentle transition), the plug included untouched.
    await _wait(900);
    final last = {for (final (id, body) in fake.puts) id: body};
    const off = {
      'on': {'on': false},
      'dynamics': {'duration': 2000},
    };
    expect(last['color'], off);
    expect(last['white'], off);
    expect(last, isNot(contains('plug')));
    controller.dispose();
  });

  test('changing the sleep timer while playing restarts the countdown',
      () async {
    final (controller, _, _) = await _setUp();
    await controller.start();
    expect(controller.sleepRemaining, isNull);
    controller.setSleepTimer(const Duration(minutes: 30));
    expect(controller.sleepRemaining!.inMinutes, 29);
    controller.setSleepTimer(null);
    expect(controller.sleepRemaining, isNull);
    await controller.stop();
    controller.dispose();
  });

  test('a light can be left out of the effect, never the last one', () async {
    final (controller, fake, _) = await _setUp();
    expect(controller.groupLights.map((l) => l.light.id), ['color', 'white']);
    await controller.toggleLight('white');
    Iterable<String> enabled() =>
        controller.groupLights.where((l) => l.enabled).map((l) => l.light.id);
    expect(enabled(), ['color']);
    await controller.toggleLight('color'); // the last one stays
    expect(enabled(), ['color']);
    expect(controller.lightNames, hasLength(1));

    await controller.start();
    await _wait(250);
    expect(fake.puts.map((p) => p.$1).toSet(), {'color'});

    // Bringing the light back while playing restarts on both.
    await controller.toggleLight('white');
    await _wait(250);
    expect(controller.status, PlaybackStatus.playing);
    expect(fake.puts.map((p) => p.$1).toSet(), {'color', 'white'});
    await controller.stop();
    controller.dispose();
  });

  test('choosing a colour variant switches a running player in place',
      () async {
    final (controller, _, _) = await _setUp();
    await controller.start();
    final player = controller.player!;
    expect(controller.variantId, isNull);
    await controller.setVariant('lagoon');
    expect(controller.player, same(player));
    expect(controller.status, PlaybackStatus.playing);
    expect(player.effect.events.first.parameters['palette'],
        ocean.variants.first.palette);
    await controller.setVariant(null);
    expect(player.effect.events.first.parameters['palette'],
        ocean.events.first.parameters['palette']);
    await controller.stop();
    controller.dispose();
  });

  test('restoring can be turned off', () async {
    final (controller, fake, _) = await _setUp(restoreLights: false);
    await controller.start();
    await _wait(250);
    await controller.stop();
    fake.puts.clear();
    await _wait(900);
    expect(fake.puts, isEmpty);
    controller.dispose();
  });

  test('going to the background stops playback', () async {
    final (controller, _, wake) = await _setUp();
    await controller.start();
    await controller.pause();
    expect(controller.status, PlaybackStatus.paused);
    expect(wake.calls, [true, false]);
    await controller.handleAppPaused();
    expect(controller.status, PlaybackStatus.idle);
    expect(controller.player, isNull);
    controller.dispose();
  });

  test('a stop during start cancels it', () async {
    final (controller, fake, _) = await _setUp();
    fake.holdRefresh = Completer<void>();
    final starting = controller.start();
    await _wait(50);
    expect(controller.status, PlaybackStatus.starting);

    await controller.stop();
    fake.holdRefresh!.complete();
    await starting;
    expect(controller.status, PlaybackStatus.idle);
    expect(controller.player, isNull);
    controller.dispose();
  });

  test('double taps do not start twice', () async {
    final (controller, fake, _) = await _setUp();
    final refreshesBefore = fake.refreshes;
    await Future.wait([controller.toggle(), controller.toggle()]);
    expect(fake.refreshes - refreshesBefore, 1);
    expect(controller.status, PlaybackStatus.playing);
    await controller.stop(restore: false);
    controller.dispose();
  });

  test('a stop while the microphone is starting wins, even in preview',
      () async {
    final (controller, _, wake) = await _setUp(
      music: true,
      audio: FakeAudioInput(startDelay: const Duration(milliseconds: 200)),
    );
    await controller.changeTarget(null); // preview: no bridge round trip
    final starting = controller.start();
    await _wait(40);
    expect(controller.status, PlaybackStatus.starting);
    await controller.stop();
    await starting;
    await _wait(50);
    expect(controller.status, PlaybackStatus.idle);
    expect(controller.player, isNull);
    expect(wake.calls.contains(true), isFalse);
    controller.dispose();
  });

  test('a microphone that dies mid-effect is reported', () async {
    final input = FakeAudioInput();
    final (controller, _, _) = await _setUp(music: true, audio: input);
    await controller.changeTarget(null);
    final notices = <PlaybackNotice>[];
    controller.notices.listen(notices.add);
    await controller.start();
    expect(controller.status, PlaybackStatus.playing);
    await input.endStream();
    await _wait(20);
    expect(notices.single.kind, PlaybackNoticeKind.microphoneStopped);
    await controller.stop();
    controller.dispose();
  });

  test('a refused microphone keeps Music Sync idle and explains why', () async {
    final (controller, _, _) =
        await _setUp(music: true, audio: FakeAudioInput(granted: false));
    final notices = <PlaybackNotice>[];
    controller.notices.listen(notices.add);
    await controller.start();
    await _wait(10);
    expect(controller.status, PlaybackStatus.idle);
    expect(notices.single.kind, PlaybackNoticeKind.microphoneDenied);
    controller.dispose();
  });

  test('Music Sync follows the phone audio preference where possible',
      () async {
    final microphone = FakeAudioInput();
    final phone = FakeAudioInput();
    final (controller, _, _) = await _setUp(
      music: true,
      audio: microphone,
      phoneAudio: phone,
      musicSource: MusicSource.phoneAudio,
    );
    expect(controller.musicSource, MusicSource.phoneAudio);
    await controller.changeTarget(null);
    await controller.start();
    expect(controller.status, PlaybackStatus.playing);
    expect(phone.started, isTrue);
    expect(microphone.started, isFalse);
    await controller.stop();
    controller.dispose();

    // Without phone audio (iOS, old Android) the microphone is used.
    final mic2 = FakeAudioInput();
    final (fallback, _, _) = await _setUp(
      music: true,
      audio: mic2,
      musicSource: MusicSource.phoneAudio,
    );
    expect(fallback.musicSource, MusicSource.microphone);
    await fallback.changeTarget(null);
    await fallback.start();
    expect(mic2.started, isTrue);
    await fallback.stop();
    fallback.dispose();
  });

  test('switching the source while playing moves to the new one', () async {
    final microphone = FakeAudioInput();
    final phone = FakeAudioInput();
    final preferences = PreferencesController(store: InMemoryKeyValueStore());
    final (controller, _, _) = await _setUp(
      music: true,
      audio: microphone,
      phoneAudio: phone,
      preferences: preferences,
    );
    await controller.changeTarget(null);
    await controller.start();
    expect(microphone.started, isTrue);
    expect(phone.started, isFalse);

    await preferences.setMusicSource(MusicSource.phoneAudio);
    await _wait(50);
    expect(controller.status, PlaybackStatus.playing);
    expect(microphone.stopped, isTrue);
    expect(phone.started, isTrue);
    expect(controller.music?.isListening, isTrue);
    await controller.stop();
    controller.dispose();
  });

  test('a refused phone audio capture explains itself', () async {
    final (controller, _, _) = await _setUp(
      music: true,
      phoneAudio: FakeAudioInput(granted: false),
      musicSource: MusicSource.phoneAudio,
    );
    final notices = <PlaybackNotice>[];
    controller.notices.listen(notices.add);
    await controller.changeTarget(null);
    await controller.start();
    await _wait(10);
    expect(controller.status, PlaybackStatus.idle);
    expect(notices.single.kind, PlaybackNoticeKind.phoneAudioDenied);
    controller.dispose();
  });

  test('changing the target while playing restarts on the new one', () async {
    final (controller, _, _) = await _setUp();
    await controller.start();
    await controller.changeTarget(null);
    expect(controller.status, PlaybackStatus.playing);
    expect(controller.lightNames, hasLength(previewLightCount));
    await controller.stop();
    controller.dispose();
  });

  test('white for colors follows the warm-cool direction', () {
    final warm =
        HueLightCommand.mirekFor(const LightColor(1, 0.5, 0.1), 153, 500);
    final cool =
        HueLightCommand.mirekFor(const LightColor(0.6, 0.8, 1), 153, 500);
    expect(warm, greaterThan(cool));
    // Within the light's own range.
    expect(HueLightCommand.mirekFor(const LightColor(0, 0, 1), 200, 300),
        inInclusiveRange(200, 300));
  });
}
