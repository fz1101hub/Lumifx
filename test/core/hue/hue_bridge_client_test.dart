import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lumifx/src/core/color/light_color.dart';
import 'package:lumifx/src/core/hue/hue_bridge_client.dart';
import 'package:lumifx/src/core/hue/hue_exceptions.dart';
import 'package:lumifx/src/core/hue/hue_models.dart';

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status,
        headers: {'content-type': 'application/json'});

Map<String, Object> _light(String id, String device, String name) => {
      'id': id,
      'type': 'light',
      'owner': {'rid': device, 'rtype': 'device'},
      'metadata': {'name': name, 'archetype': 'sultan_bulb'},
      'on': {'on': true},
      'dimming': {'brightness': 42.5},
      'color': {
        'xy': {'x': 0.4, 'y': 0.4},
      },
      'color_temperature': {'mirek': 300},
    };

void main() {
  group('pairing', () {
    test('reports when the link button has not been pressed', () async {
      final client = HueBridgeClient(
        host: '192.168.1.2',
        client: MockClient((request) async => _json([
              {
                'error': {
                  'type': 101,
                  'address': '',
                  'description': 'link button not pressed',
                },
              },
            ])),
      );
      expect(client.pair(), throwsA(isA<LinkButtonNotPressedException>()));
    });

    test('returns the application and client keys', () async {
      late Map<String, Object?> sent;
      final client = HueBridgeClient(
        host: '192.168.1.2',
        client: MockClient((request) async {
          expect(request.url.toString(), 'https://192.168.1.2/api');
          sent = jsonDecode(request.body) as Map<String, Object?>;
          return _json([
            {
              'success': {'username': 'app-key', 'clientkey': 'ABCDEF'},
            },
          ]);
        }),
      );
      final result = await client.pair(deviceName: 'a-very-long-phone-name-here');
      expect(result.applicationKey, 'app-key');
      expect(result.clientKey, 'ABCDEF');
      expect(sent['generateclientkey'], true);
      expect((sent['devicetype']! as String).length, lessThanOrEqualTo(40));
    });
  });

  test('fetchInfo reads the bridge id from the public config', () async {
    final client = HueBridgeClient(
      host: '10.0.0.5',
      client: MockClient((request) async {
        expect(request.url.path, '/api/0/config');
        return _json({'name': 'Living', 'bridgeid': '001788FFFE6A1B2C'});
      }),
    );
    final info = await client.fetchInfo();
    expect(info.id, '001788fffe6a1b2c');
    expect(info.name, 'Living');
  });

  test('fetchHome resolves room devices and zone lights to light ids',
      () async {
    final client = HueBridgeClient(
      host: '10.0.0.5',
      applicationKey: 'key',
      client: MockClient((request) async {
        expect(request.headers['hue-application-key'], 'key');
        switch (request.url.path) {
          case '/clip/v2/resource/light':
            return _json({
              'errors': <Object>[],
              'data': [
                _light('l1', 'd1', 'Sofa'),
                _light('l2', 'd2', 'Desk'),
                _light('l3', 'd3', 'Hall'),
              ],
            });
          case '/clip/v2/resource/room':
            return _json({
              'errors': <Object>[],
              'data': [
                {
                  'id': 'r1',
                  'metadata': {'name': 'Living room', 'archetype': 'living_room'},
                  'children': [
                    {'rid': 'd1', 'rtype': 'device'},
                    {'rid': 'd2', 'rtype': 'device'},
                    {'rid': 'd-switch', 'rtype': 'device'},
                  ],
                  'services': [
                    {'rid': 'g1', 'rtype': 'grouped_light'},
                  ],
                },
              ],
            });
          case '/clip/v2/resource/zone':
            return _json({
              'errors': <Object>[],
              'data': [
                {
                  'id': 'z1',
                  'metadata': {'name': 'Upstairs'},
                  'children': [
                    {'rid': 'l3', 'rtype': 'light'},
                    {'rid': 'l1', 'rtype': 'light'},
                  ],
                  'services': [
                    {'rid': 'g2', 'rtype': 'grouped_light'},
                  ],
                },
              ],
            });
        }
        return _json({}, 404);
      }),
    );

    final home = await client.fetchHome();
    expect(home.lights, hasLength(3));
    expect(home.lights['l1']!.name, 'Sofa');
    expect(home.lights['l1']!.brightness, 42.5);
    expect(home.lights['l1']!.supportsColor, isTrue);

    final room = home.rooms.single;
    expect(room.name, 'Living room');
    expect(room.lightIds, ['l1', 'l2']);
    expect(room.groupedLightId, 'g1');

    expect(home.zones.single.lightIds, ['l3', 'l1']);
  });

  test('setLight sends a v2 state update', () async {
    late http.Request captured;
    final client = HueBridgeClient(
      host: '10.0.0.5',
      applicationKey: 'key',
      client: MockClient((request) async {
        captured = request;
        return _json({'errors': <Object>[], 'data': <Object>[]});
      }),
    );
    await client.setLight(
      'l1',
      HueLightCommand.fromColor(
        const LightColor(1, 0, 0),
        0.5,
        transition: const Duration(milliseconds: 300),
      ),
    );
    expect(captured.method, 'PUT');
    expect(captured.url.path, '/clip/v2/resource/light/l1');
    final body = jsonDecode(captured.body) as Map<String, Object?>;
    expect(body['on'], {'on': true});
    expect(body['dimming'], {'brightness': 50.0});
    expect(body['dynamics'], {'duration': 300});
    expect((body['color']! as Map)['xy'], isNotNull);
  });

  test('a dark frame turns the light off', () {
    final command = HueLightCommand.fromColor(LightColor.white, 0);
    expect(command.toJson(), {
      'on': {'on': false},
    });
  });

  test('rejected keys surface as UnauthorizedException', () async {
    final client = HueBridgeClient(
      host: '10.0.0.5',
      applicationKey: 'stale',
      client: MockClient((request) async => _json({
            'errors': [
              {'description': 'unauthorized user'},
            ],
          }, 403)),
    );
    expect(client.fetchHome(), throwsA(isA<UnauthorizedException>()));
  });

  test('credentials round-trip through JSON', () {
    const credentials = HueCredentials(
      bridge: HueBridgeInfo(id: 'abc123def456', host: '10.0.0.5', name: 'Hue'),
      applicationKey: 'key',
      clientKey: 'psk',
      certificateFingerprint: 'ff00',
    );
    final copy = HueCredentials.fromJson(credentials.toJson());
    expect(copy.bridge, credentials.bridge);
    expect(copy.applicationKey, 'key');
    expect(copy.clientKey, 'psk');
    expect(copy.certificateFingerprint, 'ff00');
  });
}
