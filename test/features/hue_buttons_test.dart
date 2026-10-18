import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lumifx/src/core/hue/hue_bridge_client.dart';
import 'package:lumifx/src/core/hue/hue_buttons.dart';
import 'package:lumifx/src/core/hue/hue_models.dart';
import 'package:lumifx/src/features/bridge/bridge_controller.dart';
import 'package:lumifx/src/features/bridge/credential_store.dart';
import 'package:lumifx/src/features/buttons/hue_button_listener.dart';
import 'package:lumifx/src/features/effects/catalog/builtin_scenes.dart';
import 'package:lumifx/src/features/effects/catalog/effect_catalog.dart';
import 'package:lumifx/src/features/effects/playback_controller.dart';
import 'package:lumifx/src/features/library/effect_library.dart';
import 'package:lumifx/src/features/library/preferences_controller.dart';

import '../support/fake_audio_input.dart';

String _press(String id, String event, {bool old = false}) => jsonEncode([
      {
        'type': 'update',
        'data': [
          {
            'id': id,
            'type': 'button',
            'button': old
                ? {'last_event': event}
                : {
                    'button_report': {'event': event, 'updated': 'now'},
                  },
          },
          {
            'id': 'l1',
            'type': 'light',
            'on': {'on': true},
          },
        ],
      },
    ]);

void main() {
  test('button presses are read from the event stream', () {
    final events = buttonEventsOf(_press('b1', 'short_release'));
    expect(events.single.buttonId, 'b1');
    expect(events.single.isShortPress, isTrue);
    expect(
        buttonEventsOf(_press('b2', 'initial_press', old: true)).single.event,
        'initial_press');
    expect(buttonEventsOf('not json'), isEmpty);
    expect(buttonEventsOf('{"data": 1}'), isEmpty);
    expect(buttonEventsOf('[{"data": [{"type": "button"}]}]'), isEmpty);
  });

  test('buttons are grouped by switch, in their printed order', () {
    final devices = buttonDevicesOf(
      [
        {
          'id': 'b2',
          'owner': {'rid': 'd1', 'rtype': 'device'},
          'metadata': {'control_id': 2},
        },
        {
          'id': 'b1',
          'owner': {'rid': 'd1', 'rtype': 'device'},
          'metadata': {'control_id': 1},
        },
        {
          'id': 's1',
          'owner': {'rid': 'd2', 'rtype': 'device'},
          'metadata': {'control_id': 1},
        },
        {'id': 'orphan'},
      ],
      [
        {
          'id': 'd1',
          'metadata': {'name': 'Living room dimmer'},
        },
        {
          'id': 'd2',
          'metadata': {'name': 'Bedside button'},
        },
      ],
    );
    expect(
        devices.map((d) => d.name), ['Bedside button', 'Living room dimmer']);
    expect(devices.last.buttons.map((b) => (b.id, b.number)),
        [('b1', 1), ('b2', 2)]);
  });

  test('the client reads presses as the bridge streams them', () async {
    final client = HueBridgeClient(
      host: '10.0.0.5',
      applicationKey: 'key',
      client: MockClient.streaming((request, _) async {
        expect(request.url.path, '/eventstream/clip/v2');
        expect(request.headers['hue-application-key'], 'key');
        return http.StreamedResponse(
          Stream.fromIterable([
            utf8.encode(': hi\n\n'),
            utf8.encode('id: 1:0\ndata: ${_press('b1', 'initial_press')}\n\n'),
            utf8.encode('data: ${_press('b1', 'short_release')}\n\n'),
          ]),
          200,
        );
      }),
    );
    final events = await client.buttonEvents().toList();
    expect(events.map((e) => e.event), ['initial_press', 'short_release']);
  });

  group('listener', () {
    late BridgeController bridge;
    late PreferencesController preferences;
    late PlaybackController playback;
    late HueButtonListener listener;
    late StreamController<HueButtonEvent> stream;
    var opened = 0;

    setUp(() async {
      opened = 0;
      bridge = BridgeController(
        store: InMemoryCredentialStore(
          const HueCredentials(
            bridge: HueBridgeInfo(id: 'b', host: '10.0.0.2'),
            applicationKey: 'key',
          ),
        ),
        clientFactory: (pin, key) => HueBridgeClient(
          host: pin.host,
          applicationKey: key,
          client: MockClient((_) async =>
              http.Response(jsonEncode({'data': <Object>[]}), 200)),
        ),
      );
      await bridge.initialize();
      preferences = PreferencesController(store: InMemoryKeyValueStore());
      playback = PlaybackController(
        effect: ocean,
        bridge: bridge,
        preferences: preferences,
        audioInput: FakeAudioInput(),
        resolveEffect: effectById,
      );
      listener = HueButtonListener(
        bridge: bridge,
        preferences: preferences,
        playback: playback,
        library: EffectLibrary(preferences),
        retry: const Duration(milliseconds: 20),
        events: (_) {
          opened++;
          stream = StreamController<HueButtonEvent>();
          return stream.stream;
        },
      )..start();
    });

    tearDown(() async {
      listener.dispose();
      await playback.stop();
      playback.dispose();
    });

    Future<void> press(String id, [String event = 'short_release']) async {
      stream.add(HueButtonEvent(buttonId: id, event: event));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }

    test('listens only once a button has something to do', () async {
      expect(bridge.isConnected, isTrue);
      expect(listener.isListening, isFalse);
      await preferences.setButtonAction('b1', 'aurora');
      expect(listener.isListening, isTrue);
      await preferences.setButtonAction('b1', null);
      expect(listener.isListening, isFalse);
    });

    test('a press plays its effect, the next stops it', () async {
      await preferences.setButtonAction('b1', 'aurora');
      await press('b1', 'initial_press');
      expect(playback.status, PlaybackStatus.idle, reason: 'only a release');
      await press('b1');
      expect(playback.status, PlaybackStatus.playing);
      expect(playback.effect.id, 'aurora');
      await press('other');
      expect(playback.status, PlaybackStatus.playing);
      await press('b1');
      expect(playback.status, PlaybackStatus.idle);
    });

    test('buttons can stop anything or start bedtime', () async {
      await preferences.setButtonAction('b1', 'aurora');
      await preferences.setButtonAction('b2', PreferencesController.buttonStop);
      await preferences.setButtonAction(
          'b3', PreferencesController.buttonBedtime);
      await press('b1');
      await press('b2');
      expect(playback.status, PlaybackStatus.idle);
      await press('b3');
      expect(playback.inBedtime, isTrue);
      expect(playback.effect.id, preferences.bedtimeStory);
      await press('b3');
      expect(playback.status, PlaybackStatus.idle);
    });

    test('a flashing effect waits for the warning to be seen', () async {
      await preferences.setButtonAction('b1', 'thunderstorm');
      await press('b1');
      expect(playback.status, PlaybackStatus.idle);
      await preferences.setFlashWarningShown(true);
      await press('b1');
      expect(playback.effect.id, 'thunderstorm');
    });

    test('in kids mode a button plays only what a grown-up chose', () async {
      await preferences.setFlashWarningShown(true);
      await preferences.setKidsEffects(['ocean']);
      await preferences.setKidsLocked(true);
      await preferences.setButtonAction('b1', 'thunderstorm');
      await preferences.setButtonAction('b2', 'ocean');
      await preferences.setButtonAction('b3', 'aurora');
      await press('b1');
      expect(playback.status, PlaybackStatus.idle, reason: 'it flashes');
      await press('b3');
      expect(playback.status, PlaybackStatus.idle, reason: 'not chosen');
      await press('b2');
      expect(playback.effect.id, 'ocean');
      expect(playback.status, PlaybackStatus.playing);
    });

    test('a dropped stream reconnects; the background closes it', () async {
      await preferences.setButtonAction('b1', 'aurora');
      expect(opened, 1);
      await stream.close();
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(opened, 2);
      expect(listener.isListening, isTrue);

      listener.pause();
      expect(listener.isListening, isFalse);
      listener.resume();
      expect(listener.isListening, isTrue);
      expect(opened, 3);
    });
  });
}
