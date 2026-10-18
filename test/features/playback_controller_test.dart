import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lumifx/src/core/audio/audio_input.dart';
import 'package:lumifx/src/core/camera/screen_sampler.dart';
import 'package:lumifx/src/core/color/light_color.dart';
import 'package:lumifx/src/core/hue/hue_bridge_client.dart';
import 'package:lumifx/src/core/hue/hue_models.dart';
import 'package:lumifx/src/core/screen_wake.dart';
import 'package:lumifx/src/core/sound/melody.dart';
import 'package:lumifx/src/core/sound/melodies.dart';
import 'package:lumifx/src/core/effects/effect.dart';
import 'package:lumifx/src/core/effects/effect_event.dart';
import 'package:lumifx/src/features/effects/catalog/builtin_stories.dart';
import 'package:lumifx/src/features/bridge/bridge_controller.dart';
import 'package:lumifx/src/features/bridge/credential_store.dart';
import 'package:lumifx/src/features/effects/catalog/builtin_interactive.dart';
import 'package:lumifx/src/features/effects/catalog/builtin_scenes.dart';
import 'package:lumifx/src/features/effects/catalog/effect_catalog.dart';
import 'package:lumifx/src/features/effects/playback_controller.dart';
import 'package:lumifx/src/features/music_box/melody_lights.dart';
import 'package:lumifx/src/features/library/preferences_controller.dart';
import 'package:lumifx/src/features/playlists/playlist.dart';
import 'package:lumifx/src/features/timers/light_timer.dart';
import 'package:lumifx/src/features/tv/camera_input.dart';

import '../support/fake_audio_input.dart';
import '../support/fake_camera_input.dart';
import '../support/fake_sound_player.dart';

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
  final posts = <(String, Map<String, Object?>)>[];

  /// Light reads and writes in order: `GET` and `PUT <id>`.
  final log = <String>[];

  /// Scenes created, as the bridge lists them.
  final scenes = <Map<String, Object?>>[];

  /// Requests to the older API (schedules).
  final v1 = <(String, Map<String, Object?>)>[];

  /// When set, room loading waits for it: used to stop mid-start.
  Completer<void>? holdRefresh;
  int refreshes = 0;

  http.Client get client => MockClient((request) async {
        if (request.method == 'POST' && request.url.path.startsWith('/api/')) {
          v1.add((
            request.url.path,
            jsonDecode(request.body) as Map<String, Object?>,
          ));
          return http.Response(
              jsonEncode([
                {
                  'success': {'id': '${v1.length}'},
                },
              ]),
              200);
        }
        if (request.method == 'POST') {
          final body = jsonDecode(request.body) as Map<String, Object?>;
          if (request.url.path == '/clip/v2/resource/scene') {
            scenes.add({
              ...body,
              'id': 'new-scene',
              'id_v1': '/scenes/V1scene',
            });
          }
          posts.add((
            request.url.path,
            jsonDecode(request.body) as Map<String, Object?>,
          ));
          return _json({
            'data': [
              {'rid': 'new-scene', 'rtype': 'scene'},
            ],
          });
        }
        if (request.method == 'PUT') {
          log.add('PUT ${request.url.pathSegments.last}');
          puts.add((
            request.url.pathSegments.last,
            jsonDecode(request.body) as Map<String, Object?>,
          ));
          return _json({'data': <Object>[]});
        }
        switch (request.url.path) {
          case '/clip/v2/resource/light':
            log.add('GET');
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
          case '/clip/v2/resource/scene':
            return _json({'data': scenes});
          case '/clip/v2/resource/room':
            return _json({
              'data': [
                {
                  'id': 'room',
                  'id_v1': '/groups/1',
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
          case '/clip/v2/resource/zone':
            return _json({
              'data': [
                {
                  'id': 'zone',
                  'metadata': {'name': 'Corner'},
                  'children': [
                    {'rid': 'color', 'rtype': 'light'},
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
  LightingEffect? effect,
  math.Random? random,
  FakeSoundPlayer? sound,
  FakeCameraInput? camera,
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
    effect: effect ?? (music ? moodGlow : ocean),
    bridge: bridge,
    preferences: preferences,
    audioInput: audio ?? FakeAudioInput(),
    phoneAudioInput: phoneAudio,
    screenWake: wake,
    resolveEffect: effectById,
    random: random,
    sound: sound ?? FakeSoundPlayer(),
    camera: camera ?? FakeCameraInput(),
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

  test('a lullaby told to switch off fades out and switches off at its end',
      () async {
    const tune = LightingEffect(
      id: 'gen:melody:test:1',
      name: 'Tune',
      kind: EffectKind.scene,
      isLooping: false,
      loopDuration: Duration(milliseconds: 600),
      events: [
        EffectEvent(
          at: Duration.zero,
          duration: Duration(milliseconds: 600),
          type: EffectEventTypes.ambientPalette,
          parameters: {
            'palette': <String>['#FFD36B', '#FFB23F'],
            'brightnessMin': 0.4,
            'brightnessMax': 0.6,
          },
        ),
      ],
    );
    final (controller, fake, _) = await _setUp(
        effect: tune, sleepFade: const Duration(milliseconds: 200));
    final notices = <PlaybackNotice>[];
    controller.notices.listen(notices.add);
    await controller.start();
    controller.switchOffAtEnd();

    await _wait(900);
    expect(controller.isFadingOut || controller.status == PlaybackStatus.idle,
        isTrue,
        reason: 'the end hands over to the fade, not to a stop');
    await _wait(600);
    expect(controller.status, PlaybackStatus.idle);
    expect(notices.map((n) => n.kind),
        contains(PlaybackNoticeKind.sleepTimerDone));
    await _wait(900);
    final last = {for (final (id, body) in fake.puts) id: body};
    expect(last['color'], {
      'on': {'on': false},
      'dynamics': {'duration': 2000},
    });
    controller.dispose();
  });

  test('a tune keeps its own pace whatever the speed set', () async {
    final tune = melodyEffect(twinkle, times: 1, name: 'Twinkle');
    final (controller, _, _) = await _setUp(effect: tune);
    controller.setControls(controller.controls.copyWith(speed: 3));
    await controller.start();
    expect(controller.player!.controls.speed, 1);
    expect(controller.effectiveSpeed, 1);
    expect(controller.controls.speed, 3, reason: 'the setting is kept');
    await controller.switchEffect(fireplace);
    expect(controller.player!.controls.speed, 3);
    await controller.stop(restore: false);
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

  test('switching effects while playing cross-fades without restoring',
      () async {
    final (controller, _, _) = await _setUp();
    await controller.start();
    final player = controller.player;
    await controller.switchEffect(sunset);
    expect(controller.effect.id, 'sunset');
    expect(controller.status, PlaybackStatus.playing);
    expect(identical(controller.player, player), isTrue,
        reason: 'same player and output: nothing is put back');
    expect(player!.effect.id, 'sunset');
    await controller.stop();
    controller.dispose();
  });

  test('switching to a Music Sync effect starts listening, and back stops',
      () async {
    final input = FakeAudioInput();
    final (controller, _, _) = await _setUp(audio: input);
    await controller.changeTarget(null);
    await controller.start();
    expect(input.started, isFalse);
    await controller.switchEffect(moodGlow);
    expect(input.started, isTrue);
    expect(controller.music?.isListening, isTrue);
    await controller.switchEffect(ocean);
    expect(input.stopped, isTrue);
    await controller.stop();
    controller.dispose();
  });

  test('TV Sync watches the TV and the lights take its colours', () async {
    final camera = FakeCameraInput();
    final (controller, _, wake) = await _setUp(effect: tvSync, camera: camera);
    await controller.changeTarget(null);
    await controller.start();
    expect(controller.status, PlaybackStatus.playing);
    expect(controller.tvSync?.isWatching, isTrue);
    expect(camera.isRunning, isTrue);
    expect(wake.calls.last, isTrue, reason: 'the screen stays on');

    // Before the first frame: the dim background.
    final player = controller.player!;
    player.advance(const Duration(milliseconds: 10));
    expect(player.currentFrames.every((f) => f.brightness < 0.2), isTrue);

    camera.show(const ScreenColors(
      [LightColor(1, 0, 0), LightColor(0, 0, 1)],
      [1, 1],
    ));
    // Past the gentle start's fade-in.
    player.advance(const Duration(seconds: 3));
    final frames = player.currentFrames;
    expect(frames.first.color.r, closeTo(1, 0.01));
    expect(frames.first.color.b, lessThan(0.1));
    expect(frames.last.color.b, closeTo(1, 0.01));
    expect(frames.last.color.r, lessThan(0.1));
    expect(frames.first.brightness, greaterThan(0.8));

    await controller.pause();
    expect(camera.isRunning, isFalse, reason: 'no camera while paused');
    await controller.resume();
    expect(camera.isRunning, isTrue);
    expect(camera.starts, 2);

    await controller.switchEffect(ocean);
    expect(camera.isRunning, isFalse);
    await controller.switchEffect(tvSync);
    expect(camera.isRunning, isTrue);

    await controller.stop();
    expect(camera.isRunning, isFalse);
    controller.dispose();
  });

  test('a refused camera keeps TV Sync idle and explains why', () async {
    final camera = FakeCameraInput(result: CameraStartResult.denied);
    final (controller, _, _) = await _setUp(effect: tvSync, camera: camera);
    final notices = <PlaybackNotice>[];
    controller.notices.listen(notices.add);
    await controller.start();
    await _wait(10);
    expect(controller.status, PlaybackStatus.idle);
    expect(notices.single.kind, PlaybackNoticeKind.cameraDenied);

    camera.result = CameraStartResult.unavailable;
    await controller.start();
    await _wait(10);
    expect(notices.last.kind, PlaybackNoticeKind.cameraFailed);
    controller.dispose();
  });

  test('TV Sync stops in the background, where the camera closes', () async {
    final camera = FakeCameraInput();
    final (controller, _, _) = await _setUp(effect: tvSync, camera: camera);
    controller.keepPlayingInBackground = true;
    await controller.start();
    expect(controller.status, PlaybackStatus.playing);
    await controller.handleAppPaused();
    expect(controller.status, PlaybackStatus.idle);
    expect(camera.isRunning, isFalse);
    controller.dispose();
  });

  test('starting again waits for the lights to be put back first', () async {
    final (controller, fake, _) = await _setUp();
    await controller.start();
    await _wait(250);
    final stoppedAt = fake.log.length;
    unawaited(controller.stop());
    await controller.start();
    expect(controller.status, PlaybackStatus.playing);
    final after = fake.log.sublist(stoppedAt);
    final read = after.indexOf('GET');
    expect(read, greaterThan(0));
    // Both lights got their own state back before the new start read
    // them, so it does not keep the effect's colours as theirs.
    expect(after.sublist(0, read), containsAll(['PUT color', 'PUT white']));
    await controller.stop();
    controller.dispose();
  });

  test('a playlist that cannot start leaves no playlist behind', () async {
    final (controller, _, _) = await _setUp(
      audio: FakeAudioInput(granted: false),
    );
    await controller.playPlaylist(const Playlist(
      id: 'p',
      name: 'Party',
      effectIds: ['mood_glow', 'ocean'],
    ));
    expect(controller.status, PlaybackStatus.idle);
    expect(controller.playlist, isNull);
    controller.dispose();
  });

  test('switching effects while starting closes the camera it opened',
      () async {
    final camera = FakeCameraInput();
    final (controller, fake, _) = await _setUp(effect: tvSync, camera: camera);
    fake.holdRefresh = Completer<void>();
    final starting = controller.start();
    await _wait(20);
    expect(controller.status, PlaybackStatus.starting);
    expect(camera.isRunning, isTrue);
    await controller.switchEffect(ocean);
    fake.holdRefresh!.complete();
    await starting;
    await _wait(20);
    expect(controller.status, PlaybackStatus.playing);
    expect(camera.isRunning, isFalse);
    await controller.stop();
    controller.dispose();
  });

  test('bedtime: the story, then the night glow, then lights off', () async {
    final (controller, fake, _) =
        await _setUp(sleepFade: const Duration(milliseconds: 100));
    final before = controller.controls;
    await controller.startBedtime(
      sleepingDragon,
      storyFor: const Duration(milliseconds: 300),
      glowFor: const Duration(milliseconds: 300),
      brightness: 0.4,
    );
    expect(controller.status, PlaybackStatus.playing);
    expect(controller.effect.id, 'sleeping_dragon');
    expect(controller.inBedtime, isTrue);
    expect(controller.controls.brightness, 0.4);
    expect(controller.sleepTimer, const Duration(milliseconds: 600));
    expect(controller.isShownBy('sleeping_dragon'), isTrue);

    await _wait(400);
    expect(controller.effect.id, PlaybackController.bedtimeGlowId);
    expect(controller.isShownBy('sleeping_dragon'), isTrue,
        reason: 'the story\'s player follows bedtime');

    await _wait(1300);
    expect(controller.status, PlaybackStatus.idle);
    expect(controller.inBedtime, isFalse);
    // The lights are off, and bedtime leaves nothing behind.
    final last = {for (final (id, body) in fake.puts) id: body};
    expect((last['color']!['on']! as Map)['on'], isFalse);
    expect(controller.controls, before);
    expect(controller.sleepTimer, isNull);
    controller.dispose();
  });

  test('choosing another effect ends bedtime and puts things back', () async {
    final (controller, _, _) = await _setUp();
    controller.setSleepTimer(const Duration(minutes: 45));
    await controller.startBedtime(
      sleepingDragon,
      storyFor: const Duration(minutes: 10),
      glowFor: const Duration(minutes: 20),
      brightness: 0.3,
    );
    expect(controller.sleepTimer, const Duration(minutes: 30));
    await controller.switchEffect(ocean);
    expect(controller.inBedtime, isFalse);
    expect(controller.controls.brightness, isNot(0.3));
    expect(controller.sleepTimer, const Duration(minutes: 45),
        reason: 'the user\'s own timer comes back');
    await controller.stop();
    controller.dispose();
  });

  test('an effect is scheduled on the bridge as a dynamic scene', () async {
    final (controller, fake, _) = await _setUp();
    expect(controller.canScheduleOnBridge, isFalse, reason: 'not playing');
    await controller.start();
    expect(controller.canScheduleOnBridge, isTrue);
    await controller.scheduleOnBridge(
      name: 'Evening ocean',
      hour: 20,
      minute: 0,
      days: const [0, 1, 2, 3, 4, 5, 6],
      stopHour: 22,
      stopMinute: 0,
    );
    // The scene keeps moving by itself...
    expect(fake.scenes.single['auto_dynamic'], isTrue);
    // ...and the bridge recalls it on the room, then switches it off.
    final [(startPath, start), (_, stop)] = fake.v1;
    expect(startPath, '/api/key/schedules');
    expect(start['localtime'], 'W127/T20:00:00');
    expect((start['command']! as Map)['address'], '/api/key/groups/1/action');
    expect((start['command']! as Map)['body'], {'scene': 'V1scene'});
    expect(stop['localtime'], 'W127/T22:00:00');
    await controller.stop();
    controller.dispose();
  });

  test('stories cannot be scheduled: the bridge cannot play them', () async {
    final (controller, _, _) = await _setUp(effect: sleepingDragon);
    await controller.start();
    expect(controller.canSaveAsHueScene, isTrue);
    expect(controller.canScheduleOnBridge, isFalse);
    await controller.stop();
    controller.dispose();
  });

  test('a one-shot effect stops at its end and puts the lights back', () async {
    final (controller, fake, _) = await _setUp();
    final notices = <PlaybackNotice>[];
    controller.notices.listen(notices.add);
    final timer = LightTimer.teeth.effect(
      name: 'Teeth',
      length: const Duration(milliseconds: 300),
    );
    await controller.switchEffect(timer);
    await controller.start();
    expect(controller.status, PlaybackStatus.playing);
    // Faster than real time: the ending is six seconds long.
    controller.player!.advance(const Duration(seconds: 7));
    await _wait(400);
    expect(controller.status, PlaybackStatus.idle);
    expect(notices.single.kind, PlaybackNoticeKind.finished);
    expect(notices.single.name, 'Teeth');
    await _wait(700);
    expect(fake.puts.map((p) => p.$1), containsAll(['color', 'white']),
        reason: 'the lights got their state back');
    controller.dispose();
  });

  test('effects made for one use are not kept as recently played', () async {
    final preferences = PreferencesController(store: InMemoryKeyValueStore());
    final (controller, _, _) = await _setUp(preferences: preferences);
    await controller.changeTarget(null);
    await controller.switchEffect(LightTimer.focus.effect(name: 'Focus'));
    await controller.start();
    await controller.switchEffect(ocean);
    expect(preferences.recents, ['ocean']);
    await controller.stop();
    controller.dispose();
  });

  test('a playlist moves on by itself, pauses its clock and ends on stop',
      () async {
    final (controller, _, _) = await _setUp();
    await controller.changeTarget(null);
    const playlist = Playlist(
      id: 'p',
      name: 'Evening',
      effectIds: ['fireplace', 'gone', 'ocean'],
      each: Duration(milliseconds: 300),
    );
    await controller.playPlaylist(playlist);
    expect(controller.status, PlaybackStatus.playing);
    expect(controller.effect.id, 'fireplace');
    expect(controller.playlistEffects.map((e) => e.id), ['fireplace', 'ocean'],
        reason: 'effects that no longer exist are skipped');

    await _wait(400);
    expect(controller.effect.id, 'ocean');
    expect(controller.playlistIndex, 1);

    // Paused for longer than an effect lasts: the clock waits too.
    await _wait(100);
    await controller.pause();
    await _wait(500);
    expect(controller.effect.id, 'ocean');
    await controller.resume();
    await _wait(320);
    expect(controller.effect.id, 'fireplace', reason: 'loops around');

    await controller.switchEffect(sunset);
    expect(controller.playlist, isNull,
        reason: 'choosing an effect by hand leaves the playlist');
    await controller.stop();
    controller.dispose();
  });

  test('a shuffled playlist never repeats the same effect twice in a row',
      () async {
    final (controller, _, _) = await _setUp(random: math.Random(7));
    await controller.changeTarget(null);
    const playlist = Playlist(
      id: 'p',
      name: 'Mix',
      effectIds: ['fireplace', 'ocean', 'aurora'],
      shuffle: true,
    );
    await controller.playPlaylist(playlist);
    var previous = controller.effect.id;
    for (var i = 0; i < 12; i++) {
      await controller.nextInPlaylist();
      expect(controller.effect.id, isNot(previous));
      previous = controller.effect.id;
    }
    await controller.stop();
    controller.dispose();
  });

  test('what the lights show can be saved as a Hue scene', () async {
    final (controller, fake, _) = await _setUp();
    expect(controller.canSaveAsHueScene, isFalse);
    await controller.start();
    controller.player!.advance(const Duration(seconds: 2));
    expect(controller.canSaveAsHueScene, isTrue);
    await controller.saveAsHueScene('Deep blue evening, a very long name');
    final (path, body) = fake.posts.single;
    expect(path, '/clip/v2/resource/scene');
    expect((body['metadata']! as Map)['name'], hasLength(32));
    expect(body['group'], {'rid': 'room', 'rtype': 'room'});
    final actions = (body['actions']! as List).cast<Map<String, Object?>>();
    // The plug is no part of effects, so no part of the scene.
    expect([for (final a in actions) (a['target']! as Map)['rid']],
        ['color', 'white']);
    final colour = actions.first['action']! as Map;
    expect(colour.containsKey('color'), isTrue);
    expect(colour.containsKey('dynamics'), isFalse);
    final white = actions.last['action']! as Map;
    expect(white.containsKey('color'), isFalse,
        reason: 'a white bulb gets a colour temperature');
    expect(white.containsKey('color_temperature'), isTrue);
    await controller.stop();
    controller.dispose();
  });

  test('an ambient effect can be saved as a scene that keeps moving', () async {
    final (controller, fake, _) = await _setUp();
    await controller.start();
    final palette = controller.dynamicPalette!;
    expect(palette.colors, hasLength(4), reason: "Ocean's palette");
    expect(palette.speed, inInclusiveRange(0.05, 1.0));
    await controller.saveAsHueScene('Waves', dynamic: true);
    final (_, body) = fake.posts.single;
    expect(body['auto_dynamic'], isTrue);
    expect(body['speed'], closeTo(palette.speed, 0.001));
    final colours = ((body['palette']! as Map)['color']! as List);
    expect(colours, hasLength(4));
    expect((colours.first as Map).containsKey('dimming'), isTrue);
    await controller.stop();
    controller.dispose();

    // Stories have events the bridge cannot play: no dynamic palette.
    final (story, _, _) = await _setUp(effect: emeraldTrickster);
    expect(story.dynamicPalette, isNull);
    story.dispose();
  });

  test('several rooms play together, each light once', () async {
    final (controller, fake, _) = await _setUp();
    await controller
        .changeTarget(PlaybackController.severalRoomsKey(['room', 'zone']));
    expect(controller.playsSeveralRooms, isTrue);
    expect(controller.targetName, 'Den + Corner');
    expect(controller.roomGroups.map((g) => g.id), ['room', 'zone']);
    // The colour bulb is in both: it shows up once.
    expect(controller.lightNames.length, 2);
    await controller.start();
    expect(controller.status, PlaybackStatus.playing);
    expect(controller.player!.lightIds, ['color', 'white']);
    expect(controller.canSaveAsHueScene, isFalse,
        reason: 'a Hue scene belongs to one room');
    await controller.stop();
    controller.dispose();

    // A room that disappears from the bridge is left out; with none left
    // it is the preview again.
    final (gone, _, _) = await _setUp();
    await gone.changeTarget(PlaybackController.severalRoomsKey(['nope']));
    expect(gone.selectedTarget, isNull);
    gone.dispose();
  });

  test('effects play their sounds, which follow pause, switch and stop',
      () async {
    final sound = FakeSoundPlayer();
    final preferences = PreferencesController(store: InMemoryKeyValueStore());
    final (controller, _, _) = await _setUp(
      effect: thunderstorm,
      sound: sound,
      preferences: preferences,
    );
    await controller.changeTarget(null);
    await controller.start();
    expect(sound.calls.last, 'play rain');
    expect(sound.playing!.thunder, isTrue);
    await controller.pause();
    expect(sound.calls.last, 'pause');
    await controller.resume();
    expect(sound.calls.last, 'resume');
    await controller.switchEffect(ocean);
    expect(sound.calls.last, 'play waves');

    // Turned off, then back on, while playing.
    await preferences.setSoundOn(false);
    expect(sound.calls.last, 'stop');
    await preferences.setSoundOn(true);
    expect(sound.calls.last, 'play waves');
    await preferences.setSoundVolume(0.2);
    expect(sound.volume, 0.2);

    await controller.stop();
    expect(sound.calls.last, 'stop');
    controller.dispose();
  });

  test('notes and thunder on top stop with the effect or the sound', () async {
    final sound = FakeSoundPlayer();
    final preferences = PreferencesController(store: InMemoryKeyValueStore());
    final (controller, _, _) =
        await _setUp(sound: sound, preferences: preferences);
    await controller.changeTarget(null);
    await controller.start();
    await controller.note(60, Instrument.musicBox);
    expect(sound.calls.last, 'note 60');
    var stops = sound.cueStops;
    await controller.pause();
    expect(sound.cueStops, greaterThan(stops),
        reason: 'paused, nothing rings on');
    await controller.resume();
    stops = sound.cueStops;
    await controller.stop();
    expect(sound.cueStops, greaterThan(stops),
        reason: 'stopped, nothing rings on');

    // The piano plays no soundscape: switching sound off still silences it.
    stops = sound.cueStops;
    await preferences.setSoundOn(false);
    expect(sound.cueStops, greaterThan(stops));
    controller.dispose();
  });

  test('silent effects and Music Sync play no sound', () async {
    final sound = FakeSoundPlayer();
    final (controller, _, _) = await _setUp(music: true, sound: sound);
    await controller.changeTarget(null);
    await controller.start();
    expect(sound.calls, isEmpty);
    await controller.stop();
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
