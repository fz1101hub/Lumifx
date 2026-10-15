import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lumifx/src/app.dart';
import 'package:lumifx/src/core/hue/hue_bridge_client.dart';
import 'package:lumifx/src/core/hue/hue_discovery.dart';
import 'package:lumifx/src/core/hue/hue_models.dart';
import 'package:lumifx/src/features/bridge/bridge_controller.dart';
import 'package:lumifx/src/features/bridge/credential_store.dart';
import 'package:lumifx/src/features/library/preferences_controller.dart';

import '../support/fake_audio_input.dart';

class _FakeDiscovery implements BridgeDiscovery {
  @override
  Stream<HueBridgeInfo> discover({Duration timeout = Duration.zero}) =>
      Stream.value(
        const HueBridgeInfo(id: '001788fffe123456', host: '10.0.0.9'),
      );
}

/// Preferences of a user who has already seen the flashing-lights warning.
PreferencesController _warnedPreferences() =>
    PreferencesController(store: InMemoryKeyValueStore())
      ..setFlashWarningShown(true);

Future<void> _pumpApp(WidgetTester tester) async {
  final bridge = BridgeController(store: InMemoryCredentialStore());
  await tester.runAsync(bridge.initialize);
  await tester.pumpWidget(
    LumiFxApp(
      bridge: bridge,
      discovery: _FakeDiscovery(),
      preferences: PreferencesController(store: InMemoryKeyValueStore()),
      audioInput: FakeAudioInput(),
    ),
  );
}

void main() {
  testWidgets('home offers bridge setup and the three experience types',
      (tester) async {
    await _pumpApp(tester);
    expect(find.text('Connect your Hue Bridge'), findsOneWidget);
    expect(find.text('Scenes'), findsOneWidget);
    expect(find.text('Stories'), findsOneWidget);
    expect(find.text('Interactive'), findsOneWidget);
  });

  testWidgets('a story can be previewed without a bridge', (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.text('Stories'));
    await tester.pumpAndSettle();
    expect(find.text('Emerald Trickster'), findsOneWidget);

    await tester.tap(find.text('Emerald Trickster'));
    await tester.pumpAndSettle();
    expect(find.text('Preview only'), findsOneWidget);
    expect(find.text('Lamp 1'), findsOneWidget);

    await tester.tap(find.text('Play'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Pause'), findsOneWidget);

    await tester.tap(find.text('Pause'));
    await tester.pump();
    expect(find.text('Play'), findsOneWidget);

    // Leave the screen so the player stops its timer.
    await tester.pageBack();
    await tester.pumpAndSettle();
  });

  testWidgets('bridge setup lists discovered bridges', (tester) async {
    await _pumpApp(tester);
    await tester.tap(find.text('Connect your Hue Bridge'));
    await tester.pumpAndSettle();
    expect(find.text('Hue Bridge 123456'), findsOneWidget);
    expect(find.text('10.0.0.9'), findsOneWidget);
    expect(find.byType(OutlinedButton), findsOneWidget);
  });

  testWidgets('favorites and recently played appear on the home screen',
      (tester) async {
    await _pumpApp(tester);
    expect(find.text('Favorites'), findsNothing);

    await tester.tap(find.text('Scenes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ocean'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add to favorites'));
    await tester.pump();
    expect(find.byTooltip('Remove from favorites'), findsOneWidget);

    await tester.tap(find.text('Play'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Favorites'), findsOneWidget);
    expect(find.text('Recently played'), findsOneWidget);
    expect(find.text('Ocean'), findsNWidgets(2));
  });

  testWidgets('settings change the controls a new playback starts with',
      (tester) async {
    await _pumpApp(tester);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Connect a Hue Bridge'), findsOneWidget);

    final brightness = find.byType(Slider).first;
    await tester.drag(brightness, const Offset(-1000, 0));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Scenes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ocean'));
    await tester.pumpAndSettle();
    final slider = tester.widget<Slider>(find.byType(Slider).first);
    expect(slider.value, 0);
  });

  testWidgets('Music Sync listens while playing and stops on pause',
      (tester) async {
    final input = FakeAudioInput();
    final bridge = BridgeController(store: InMemoryCredentialStore());
    await tester.runAsync(bridge.initialize);
    await tester.pumpWidget(LumiFxApp(
      bridge: bridge,
      discovery: _FakeDiscovery(),
      // Beat effects flash: the one-time warning has been seen already.
      preferences: _warnedPreferences(),
      audioInput: input,
    ));

    await tester.tap(find.text('Interactive'));
    await tester.pumpAndSettle();
    expect(find.text('Spectrum'), findsOneWidget);
    await tester.tap(find.text('Beat Pulse'));
    await tester.pumpAndSettle();
    expect(find.text('Sensitivity'), findsOneWidget);
    expect(find.text('Speed'), findsNothing);

    await tester.runAsync(() async {
      await tester.tap(find.text('Play'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump(const Duration(milliseconds: 200));
    expect(input.started, isTrue);
    expect(find.textContaining('BPM'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.text('Pause'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    expect(input.stopped, isTrue);

    await tester.pageBack();
    await tester.pumpAndSettle();
  });

  testWidgets('Music Sync explains a refused microphone', (tester) async {
    final bridge = BridgeController(store: InMemoryCredentialStore());
    await tester.runAsync(bridge.initialize);
    await tester.pumpWidget(LumiFxApp(
      bridge: bridge,
      discovery: _FakeDiscovery(),
      preferences: _warnedPreferences(),
      audioInput: FakeAudioInput(granted: false),
    ));
    await tester.tap(find.text('Interactive'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Party Chase'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.text('Play'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    expect(find.textContaining('microphone access'), findsOneWidget);
    expect(find.text('Play'), findsOneWidget);
  });

  testWidgets('a flashing effect warns once, and softening can be chosen',
      (tester) async {
    final bridge = BridgeController(store: InMemoryCredentialStore());
    await tester.runAsync(bridge.initialize);
    final preferences = PreferencesController(store: InMemoryKeyValueStore());
    await tester.pumpWidget(LumiFxApp(
      bridge: bridge,
      discovery: _FakeDiscovery(),
      preferences: preferences,
      audioInput: FakeAudioInput(),
    ));

    // Ocean has no flashes: no warning.
    await tester.tap(find.text('Scenes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ocean'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Play'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Flashing lights'), findsNothing);
    expect(find.text('Pause'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // The lazy list has not built the card yet: scroll until it exists,
    // then bring it fully into view.
    await tester.scrollUntilVisible(find.text('Thunderstorm'), 200);
    await tester.ensureVisible(find.text('Thunderstorm'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thunderstorm'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Play'));
    await tester.pumpAndSettle();
    expect(find.text('Flashing lights'), findsOneWidget);
    // Nothing plays until the user has chosen.
    expect(find.text('Pause'), findsNothing);
    await tester.tap(find.text('Soften flashes'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Pause'), findsOneWidget);
    expect(preferences.softFlashes, isTrue);
    expect(preferences.flashWarningShown, isTrue);
    await tester.tap(find.text('Stop'));
    await tester.pumpAndSettle();

    // Shown once only.
    await tester.tap(find.text('Play'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Flashing lights'), findsNothing);
    expect(find.text('Pause'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
  });

  testWidgets('a sleep timer can be set and shows the time left',
      (tester) async {
    await _pumpApp(tester);
    await tester.tap(find.text('Scenes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ocean'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sleep timer'));
    await tester.pumpAndSettle();
    expect(find.text('Off'), findsOneWidget);
    await tester.tap(find.text('30 min'));
    await tester.pumpAndSettle();
    expect(find.text('30 min'), findsOneWidget);

    await tester.tap(find.text('Play'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Lights off in 30 minutes'), findsOneWidget);
    await tester.tap(find.text('Stop'));
    await tester.pumpAndSettle();
    expect(find.text('30 min'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
  });

  testWidgets('the app speaks Italian', (tester) async {
    final bridge = BridgeController(store: InMemoryCredentialStore());
    await tester.runAsync(bridge.initialize);
    await tester.pumpWidget(LumiFxApp(
      bridge: bridge,
      discovery: _FakeDiscovery(),
      preferences: PreferencesController(store: InMemoryKeyValueStore()),
      audioInput: FakeAudioInput(),
      locale: const Locale('it'),
    ));
    expect(find.text('Collega il tuo Hue Bridge'), findsOneWidget);
    expect(find.text('Scene'), findsOneWidget);
    await tester.tap(find.text('Storie'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Il Burlone di Smeraldo'));
    await tester.pumpAndSettle();
    expect(find.text('Solo anteprima'), findsOneWidget);
    expect(find.text('Lampada 1'), findsOneWidget);
    expect(find.text('Riproduci'), findsOneWidget);
    expect(find.text('Magia e fantasia'), findsNothing);
    // pageBack() looks for the English "Back" tooltip.
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Magia e fantasia'), findsWidgets);
  });

  streamingTests();
}

Future<BridgeController> _connectedBridge(
  WidgetTester tester, {
  String? clientKey,
  List<String>? puts,
}) async {
  http.Response json(Object body) => http.Response(jsonEncode(body), 200);
  final bridge = BridgeController(
    store: InMemoryCredentialStore(
      HueCredentials(
        bridge: const HueBridgeInfo(id: '001788fffe123456', host: '127.0.0.1'),
        applicationKey: 'key',
        clientKey: clientKey,
      ),
    ),
    clientFactory: (pin, key) => HueBridgeClient(
      host: pin.host,
      applicationKey: key,
      client: MockClient((request) async {
        if (request.method == 'PUT') {
          puts?.add(request.url.path);
          return json({'data': <Object>[]});
        }
        switch (request.url.path) {
          case '/clip/v2/resource/scene':
            return json({
              'data': [
                {
                  'id': 's1',
                  'metadata': {'name': 'Movie night'},
                  'group': {'rid': 'r1', 'rtype': 'room'},
                  'status': {'active': 'inactive'},
                },
              ],
            });
          case '/clip/v2/resource/light':
            return json({
              'data': [
                {
                  'id': 'l1',
                  'owner': {'rid': 'd1', 'rtype': 'device'},
                  'metadata': {'name': 'Sofa'},
                  'on': {'on': true},
                  'dimming': {'brightness': 50.0},
                },
              ],
            });
          case '/clip/v2/resource/room':
            return json({
              'data': [
                {
                  'id': 'r1',
                  'metadata': {'name': 'Living room'},
                  'children': [
                    {'rid': 'd1', 'rtype': 'device'},
                  ],
                  'services': <Object>[],
                },
              ],
            });
          case '/clip/v2/resource/entertainment_configuration':
            return json({
              'data': [
                {
                  'id': '1a8d99cc-967b-44f2-9202-43f976c0fa6b',
                  'metadata': {'name': 'TV area'},
                  'status': 'inactive',
                  'channels': [
                    {
                      'channel_id': 0,
                      'position': {'x': 0, 'y': 0, 'z': 0},
                      'members': <Object>[],
                    },
                  ],
                },
              ],
            });
        }
        return json({'data': <Object>[]});
      }),
    ),
  );
  await tester.runAsync(bridge.initialize);
  return bridge;
}

void streamingTests() {
  testWidgets('rooms list the Hue scenes of each group and recall them',
      (tester) async {
    final puts = <String>[];
    final bridge = await _connectedBridge(tester, puts: puts);
    await tester.pumpWidget(LumiFxApp(
      bridge: bridge,
      discovery: _FakeDiscovery(),
      preferences: PreferencesController(store: InMemoryKeyValueStore()),
      audioInput: FakeAudioInput(),
    ));
    await tester.tap(find.text('Rooms & zones'));
    await tester.pumpAndSettle();
    expect(find.text('Living room'), findsOneWidget);
    expect(find.text('Hue scenes'), findsOneWidget);
    await tester.tap(find.text('Movie night'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(puts, contains('/clip/v2/resource/scene/s1'));
    await tester.pumpAndSettle();
  });

  testWidgets('player offers entertainment areas and reports start errors',
      (tester) async {
    final bridge = await _connectedBridge(tester);
    expect(bridge.status, BridgeStatus.connected);
    await tester.pumpWidget(
      LumiFxApp(
        bridge: bridge,
        discovery: _FakeDiscovery(),
        preferences: PreferencesController(store: InMemoryKeyValueStore()),
        audioInput: FakeAudioInput(),
      ),
    );

    await tester.tap(find.text('Stories'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Emerald Trickster'));
    await tester.pumpAndSettle();

    // These credentials predate Entertainment support (no client key), so
    // areas are not offered and the player says why.
    expect(find.textContaining('pair again'), findsOneWidget);
    await tester.tap(find.text('Preview only'));
    await tester.pumpAndSettle();
    expect(find.text('TV area · streaming'), findsNothing);
    expect(find.text('Living room · 1 light'), findsWidgets);

    await tester.tap(find.text('Living room · 1 light').last);
    await tester.pumpAndSettle();
    expect(find.text('Sofa'), findsOneWidget);
  });

  testWidgets('player offers entertainment areas when streaming is possible',
      (tester) async {
    final bridge = await _connectedBridge(tester, clientKey: 'A' * 32);
    await tester.pumpWidget(LumiFxApp(
      bridge: bridge,
      discovery: _FakeDiscovery(),
      preferences: PreferencesController(store: InMemoryKeyValueStore()),
      audioInput: FakeAudioInput(),
    ));
    await tester.tap(find.text('Stories'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Emerald Trickster'));
    await tester.pumpAndSettle();
    expect(find.textContaining('pair again'), findsNothing);

    await tester.tap(find.text('Preview only'));
    await tester.pumpAndSettle();
    expect(find.text('TV area · streaming'), findsWidgets);
    await tester.tap(find.text('TV area · streaming').last);
    await tester.pumpAndSettle();
    expect(find.text('Channel 0'), findsOneWidget);
  });
}
