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

class _NoDiscovery implements BridgeDiscovery {
  @override
  Stream<HueBridgeInfo> discover({Duration timeout = Duration.zero}) =>
      const Stream.empty();
}

http.Response _json(Object body) => http.Response(jsonEncode(body), 200);

Map<String, Object> _light(String id, String device, String name) => {
      'id': id,
      'owner': {'rid': device, 'rtype': 'device'},
      'metadata': {'name': name},
      'on': {'on': true},
    };

void main() {
  testWidgets('creates an entertainment area from settings', (tester) async {
    final requests = <http.Request>[];
    final bridge = BridgeController(
      store: InMemoryCredentialStore(
        const HueCredentials(
          bridge: HueBridgeInfo(id: '001788fffe123456', host: '127.0.0.1'),
          applicationKey: 'key',
          clientKey: '00112233445566778899AABBCCDDEEFF',
        ),
      ),
      clientFactory: (pin, key) => HueBridgeClient(
        host: pin.host,
        applicationKey: key,
        client: MockClient((request) async {
          requests.add(request);
          if (request.method == 'POST') {
            return _json({
              'data': [
                {'rid': 'new-area', 'rtype': 'entertainment_configuration'},
              ],
            });
          }
          switch (request.url.path) {
            case '/clip/v2/resource/light':
              return _json({
                'data': [
                  _light('l1', 'd1', 'Floor lamp'),
                  _light('l2', 'd2', 'Gradient strip'),
                  _light('l3', 'd3', 'Bridge plug'),
                ],
              });
            case '/clip/v2/resource/entertainment':
              return _json({
                'data': [
                  {
                    'id': 'e1',
                    'owner': {'rid': 'd1', 'rtype': 'device'},
                    'renderer': true,
                  },
                  {
                    'id': 'e2',
                    'owner': {'rid': 'd2', 'rtype': 'device'},
                    'renderer': true,
                    'renderer_reference': {'rid': 'l2', 'rtype': 'light'},
                    'max_streams': 3,
                  },
                  {
                    'id': 'e3',
                    'owner': {'rid': 'd3', 'rtype': 'device'},
                    'renderer': false,
                  },
                ],
              });
          }
          return _json({'data': <Object>[]});
        }),
      ),
    );
    await tester.runAsync(bridge.initialize);
    expect(bridge.home!.entertainmentServices, hasLength(3));

    await tester.pumpWidget(LumiFxApp(
      bridge: bridge,
      discovery: _NoDiscovery(),
      preferences: PreferencesController(store: InMemoryKeyValueStore()),
      audioInput: FakeAudioInput(),
    ));
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Entertainment streaming'));
    await tester.pumpAndSettle();
    expect(
        find.text('No areas yet. Create one to get started.'), findsOneWidget);

    await tester.tap(find.text('New area'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Living room');
    final list = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.text('Gradient strip'), 200,
        scrollable: list);
    // Lights that cannot render are not offered.
    expect(find.text('Bridge plug'), findsNothing);
    expect(find.text('Gradient · 3 segments'), findsOneWidget);

    await tester.tap(find.text('Floor lamp'));
    await tester.tap(find.text('Gradient strip'));
    await tester.pumpAndSettle();
    expect(find.text('Lights (2/10)'), findsOneWidget);

    // Drag the floor lamp to the far left of the map, then to the back:
    // vertical drags must move the light, not scroll the page.
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('placement-e1')), -200,
        scrollable: list);
    await tester.drag(
        find.byKey(const ValueKey('placement-e1')), const Offset(-2000, 0));
    await tester.pumpAndSettle();
    final mapBefore = tester.getRect(find.byType(AspectRatio));
    await tester.drag(
        find.byKey(const ValueKey('placement-e1')), const Offset(0, 2000));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(AspectRatio)), mapBefore,
        reason: 'the page must not scroll while dragging a light');

    await tester.runAsync(() async {
      await tester.tap(find.text('Save'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();

    final post = requests.singleWhere((r) => r.method == 'POST');
    expect(post.url.path, '/clip/v2/resource/entertainment_configuration');
    final body = jsonDecode(post.body) as Map<String, Object?>;
    expect(body['type'], 'entertainment_configuration');
    expect(body['metadata'], {'name': 'Living room'});
    expect(body['configuration_type'], 'music');
    final locations =
        ((body['locations']! as Map)['service_locations']! as List)
            .cast<Map<String, Object?>>();
    expect(locations.map((l) => (l['service']! as Map)['rid']), ['e1', 'e2']);
    final lampPositions = (locations[0]['positions']! as List).cast<Map>();
    expect(lampPositions.single['x'], -1.0);
    expect(lampPositions.single['y'], -1.0);
    // A gradient light gets one position per segment.
    expect(locations[1]['positions'], hasLength(3));

    // Back on the list after saving.
    expect(find.text('New area'), findsOneWidget);
  });
}
