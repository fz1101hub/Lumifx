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
      final result =
          await client.pair(deviceName: 'a-very-long-phone-name-here');
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
                  'metadata': {
                    'name': 'Living room',
                    'archetype': 'living_room'
                  },
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

  test('fetchHome reads the scenes of each group; recallScene shows one',
      () async {
    final puts = <(String, String)>[];
    final client = HueBridgeClient(
      host: '10.0.0.5',
      applicationKey: 'key',
      client: MockClient((request) async {
        if (request.method == 'PUT') {
          puts.add((request.url.path, request.body));
          return _json({'data': <Object>[]});
        }
        switch (request.url.path) {
          case '/clip/v2/resource/scene':
            return _json({
              'errors': <Object>[],
              'data': [
                {
                  'id': 's1',
                  'metadata': {'name': 'Movie night'},
                  'group': {'rid': 'r1', 'rtype': 'room'},
                  'status': {'active': 'static'},
                },
                {
                  'id': 's2',
                  'metadata': {'name': 'Bright'},
                  'group': {'rid': 'z1', 'rtype': 'zone'},
                  'status': {'active': 'inactive'},
                  'palette': {
                    'color': [
                      {
                        'color': {
                          'xy': {'x': 0.6, 'y': 0.3},
                        },
                      },
                    ],
                  },
                },
              ],
            });
        }
        return _json({'errors': <Object>[], 'data': <Object>[]});
      }),
    );
    final home = await client.fetchHome();
    expect(home.scenes.map((s) => s.name), ['Movie night', 'Bright']);
    expect(home.scenesOf('r1').single.isActive, isTrue);
    expect(home.scenesOf('z1').single.isActive, isFalse);
    expect(home.scenesOf('nope'), isEmpty);

    expect(home.scenesOf('r1').single.isDynamic, isFalse);
    expect(home.scenesOf('z1').single.isDynamic, isTrue);

    await client.recallScene('s1');
    expect(puts.single.$1, '/clip/v2/resource/scene/s1');
    expect(jsonDecode(puts.single.$2), {
      'recall': {'action': 'active'},
    });
    await client.recallScene('s2', dynamic: true);
    expect(jsonDecode(puts.last.$2), {
      'recall': {'action': 'dynamic_palette'},
    });
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

  group('entertainment areas', () {
    test('create posts the area and returns its id', () async {
      late http.Request captured;
      final client = HueBridgeClient(
        host: '10.0.0.5',
        applicationKey: 'key',
        client: MockClient((request) async {
          captured = request;
          return _json({
            'errors': <Object>[],
            'data': [
              {'rid': 'area-1', 'rtype': 'entertainment_configuration'},
            ],
          });
        }),
      );
      final id = await client.createEntertainmentArea(
        const HueEntertainmentAreaDraft(
          name: 'Den',
          configurationType: 'screen',
          locations: [
            HueServiceLocation(
              serviceId: 'e1',
              positions: [HuePosition(-0.5, 0.25, 1)],
            ),
          ],
        ),
      );
      expect(id, 'area-1');
      expect(captured.method, 'POST');
      expect(jsonDecode(captured.body), {
        'type': 'entertainment_configuration',
        'metadata': {'name': 'Den'},
        'configuration_type': 'screen',
        'locations': {
          'service_locations': [
            {
              'service': {'rid': 'e1', 'rtype': 'entertainment'},
              'positions': [
                {'x': -0.5, 'y': 0.25, 'z': 1.0},
              ],
            },
          ],
        },
      });
    });

    test('update and delete target the area', () async {
      final calls = <String>[];
      final client = HueBridgeClient(
        host: '10.0.0.5',
        applicationKey: 'key',
        client: MockClient((request) async {
          calls.add('${request.method} ${request.url.path}');
          return _json({'errors': <Object>[], 'data': <Object>[]});
        }),
      );
      await client.updateEntertainmentArea(
        'a1',
        const HueEntertainmentAreaDraft(name: 'X', locations: []),
      );
      await client.deleteEntertainmentArea('a1');
      expect(calls, [
        'PUT /clip/v2/resource/entertainment_configuration/a1',
        'DELETE /clip/v2/resource/entertainment_configuration/a1',
      ]);
    });

    test('existing placements are read back for editing', () async {
      final client = HueBridgeClient(
        host: '10.0.0.5',
        applicationKey: 'key',
        client: MockClient((request) async {
          if (request.url.path ==
              '/clip/v2/resource/entertainment_configuration') {
            return _json({
              'data': [
                {
                  'id': 'a1',
                  'metadata': {'name': 'Den'},
                  'channels': <Object>[],
                  'locations': {
                    'service_locations': [
                      {
                        'service': {'rid': 'e1', 'rtype': 'entertainment'},
                        'positions': [
                          {'x': 0.5, 'y': -0.5, 'z': 0},
                        ],
                      },
                      {
                        // Older firmware: a single `position`.
                        'service': {'rid': 'e2', 'rtype': 'entertainment'},
                        'position': {'x': -2, 'y': 0, 'z': 0},
                      },
                    ],
                  },
                },
              ],
            });
          }
          return _json({'data': <Object>[]});
        }),
      );
      final area = (await client.fetchHome()).entertainmentAreas.single;
      expect(area.locations[0].positions.single, const HuePosition(0.5, -0.5));
      // Out-of-range values are clamped.
      expect(area.locations[1].positions.single, const HuePosition(-1, 0));
    });
  });

  group('robustness', () {
    test('a light whose color has no xy still loads', () async {
      final client = HueBridgeClient(
        host: '10.0.0.5',
        applicationKey: 'key',
        client: MockClient((request) async {
          if (request.url.path == '/clip/v2/resource/light') {
            return _json({
              'data': [
                {
                  'id': 'odd',
                  'owner': {'rid': 'd', 'rtype': 'device'},
                  'on': {'on': true},
                  'color': {'gamut_type': 'C'},
                },
              ],
            });
          }
          return _json({'data': <Object>[]});
        }),
      );
      final light = (await client.fetchHome()).lights['odd']!;
      expect(light.supportsColor, isTrue);
      expect(light.color, isNull);
      expect(light.name, 'Light');
    });

    test('fetchInfo rejects malformed bridge ids', () async {
      final client = HueBridgeClient(
        host: '10.0.0.5',
        client: MockClient((_) async => _json({'bridgeid': 'abc'})),
      );
      expect(client.fetchInfo(), throwsA(isA<HueException>()));
    });

    test('short bridge ids do not break the display name', () {
      expect(const HueBridgeInfo(id: 'abc', host: 'h').displayName,
          'Hue Bridge abc');
    });

    test('429 carries its status code', () async {
      final client = HueBridgeClient(
        host: '10.0.0.5',
        applicationKey: 'key',
        client: MockClient((_) async => http.Response('{}', 429)),
      );
      await expectLater(
        client.fetchHome(),
        throwsA(
            isA<HueException>().having((e) => e.statusCode, 'statusCode', 429)),
      );
    });
  });
}
