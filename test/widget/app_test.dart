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
      preferences: PreferencesController(store: InMemoryKeyValueStore()),
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
      preferences: PreferencesController(store: InMemoryKeyValueStore()),
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

  streamingTests();
}

Future<BridgeController> _connectedBridge(
  WidgetTester tester, {
  String? clientKey,
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
        switch (request.url.path) {
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
