import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
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
  bool music = false,
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
  final preferences = PreferencesController(store: InMemoryKeyValueStore());
  await preferences.setLastTarget('group:room');
  await preferences.setRestoreLights(restoreLights);
  final wake = _RecordingWake();
  final controller = PlaybackController(
    effect: music ? moodGlow : ocean,
    bridge: bridge,
    preferences: preferences,
    audioInput: audio ?? FakeAudioInput(),
    screenWake: wake,
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
