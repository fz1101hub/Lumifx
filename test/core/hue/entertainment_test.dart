import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lumifx/src/core/color/light_color.dart';
import 'package:lumifx/src/core/effects/engine/light_frame.dart';
import 'package:lumifx/src/core/hue/entertainment/dtls/dtls_client.dart';
import 'package:lumifx/src/core/hue/entertainment/entertainment_session.dart';
import 'package:lumifx/src/core/hue/entertainment/hue_stream_message.dart';
import 'package:lumifx/src/core/hue/hue_bridge_client.dart';
import 'package:lumifx/src/core/hue/hue_exceptions.dart';
import 'package:lumifx/src/core/hue/hue_models.dart';

const _areaId = '1a8d99cc-967b-44f2-9202-43f976c0fa6b';
const _applicationId = '7bd2d9a2-9fae-4c25-9d0d-2e8f1a9b0c11';
const _clientKey = '00112233445566778899AABBCCDDEEFF';

http.Response _json(Object body, {Map<String, String> headers = const {}}) =>
    http.Response(jsonEncode(body), 200, headers: headers);

bool get _hasOpenSsl {
  try {
    return Process.runSync('openssl', ['version']).exitCode == 0;
  } on ProcessException {
    return false;
  }
}

const _area = HueEntertainmentArea(
  id: _areaId,
  name: 'TV',
  channels: [
    HueEntertainmentChannel(id: 0, x: 0.8, y: 0, z: 0, lightIds: ['r']),
    HueEntertainmentChannel(id: 1, x: -0.8, y: 0, z: 0, lightIds: ['l']),
    HueEntertainmentChannel(id: 2, x: 0, y: 0.5, z: 0, lightIds: ['c']),
  ],
);

void main() {
  group('HueStream message', () {
    test('has the v2 header, area id and xy+brightness channels', () {
      final message = encodeHueStreamMessage(
        areaId: _areaId,
        sequence: 7,
        channels: {
          0: const LightFrame(LightColor(1, 0, 0), 1),
          3: const LightFrame(LightColor.white, 0.5),
        },
      );
      expect(ascii.decode(message.sublist(0, 9)), 'HueStream');
      expect(message.sublist(9, 11), [2, 0]);
      expect(message[11], 7);
      expect(message[14], 1, reason: 'xy + brightness color space');
      expect(ascii.decode(message.sublist(16, 52)), _areaId);
      expect(message.length, 52 + 2 * 7);

      // First channel: id 0, red, full brightness.
      expect(message[52], 0);
      final x = (message[53] << 8 | message[54]) / 0xFFFF;
      expect(x, closeTo(const LightColor(1, 0, 0).toXy().x, 1e-4));
      expect(message.sublist(57, 59), [0xFF, 0xFF]);

      // Second channel: id 3, half brightness.
      expect(message[59], 3);
      expect((message[64] << 8 | message[65]) / 0xFFFF, closeTo(0.5, 1e-4));
    });

    test('rejects ids that are not UUIDs', () {
      expect(
        () => encodeHueStreamMessage(areaId: 'short', channels: const {}),
        throwsArgumentError,
      );
    });
  });

  test('areas order channels left to right', () {
    expect(entertainmentSlotIds(_area), ['1', '2', '0']);
  });

  test('fetchHome resolves entertainment areas to lights', () async {
    final client = HueBridgeClient(
      host: '10.0.0.5',
      applicationKey: 'key',
      client: MockClient((request) async {
        switch (request.url.path) {
          case '/clip/v2/resource/light':
            return _json({
              'data': [
                {
                  'id': 'light-1',
                  'owner': {'rid': 'device-1', 'rtype': 'device'},
                  'metadata': {'name': 'Play left'},
                  'on': {'on': true},
                },
              ],
            });
          case '/clip/v2/resource/entertainment':
            return _json({
              'data': [
                {
                  'id': 'ent-1',
                  'owner': {'rid': 'device-1', 'rtype': 'device'},
                },
              ],
            });
          case '/clip/v2/resource/entertainment_configuration':
            return _json({
              'data': [
                {
                  'id': _areaId,
                  'metadata': {'name': 'TV area'},
                  'configuration_type': 'screen',
                  'status': 'inactive',
                  'channels': [
                    {
                      'channel_id': 0,
                      'position': {'x': -0.6, 'y': 0.8, 'z': 0.1},
                      'members': [
                        {
                          'service': {'rid': 'ent-1', 'rtype': 'entertainment'},
                          'index': 0,
                        },
                      ],
                    },
                  ],
                },
              ],
            });
        }
        return _json({'data': <Object>[]});
      }),
    );
    final area = (await client.fetchHome()).entertainmentAreas.single;
    expect(area.name, 'TV area');
    expect(area.isStreaming, isFalse);
    expect(area.channels.single.x, -0.6);
    expect(area.channels.single.lightIds, ['light-1']);
  });

  test('refuses to stream without an Entertainment client key', () async {
    final client = HueBridgeClient(
      host: '127.0.0.1',
      applicationKey: 'key',
      client: MockClient((_) async => _json({})),
    );
    expect(
      EntertainmentSession.open(
        client: client,
        credentials: const HueCredentials(
          bridge: HueBridgeInfo(id: 'b', host: '127.0.0.1'),
          applicationKey: 'key',
        ),
        area: _area,
      ),
      throwsA(isA<HueException>()),
    );
  });

  test('streams HueStream messages to a DTLS server', () async {
    final probe = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = probe.port;
    probe.close();

    // OpenSSL plays the bridge's DTLS endpoint; it expects the application id
    // from /auth/v1 as identity and the client key as PSK.
    final server = await Process.start('openssl', [
      's_server',
      '-dtls1_2',
      '-accept',
      '$port',
      '-nocert',
      '-psk',
      _clientKey,
      '-psk_identity',
      _applicationId,
      '-cipher',
      'PSK-AES128-GCM-SHA256',
      '-quiet',
    ]);
    addTearDown(server.kill);
    final received = <int>[];
    server.stdout.listen(received.addAll);
    server.stderr.drain<void>();
    await Future<void>.delayed(const Duration(milliseconds: 400));

    final actions = <String>[];
    final client = HueBridgeClient(
      host: '127.0.0.1',
      applicationKey: 'app-key',
      client: MockClient((request) async {
        if (request.url.path == '/auth/v1') {
          return _json({}, headers: {'hue-application-id': _applicationId});
        }
        expect(request.url.path,
            '/clip/v2/resource/entertainment_configuration/$_areaId');
        actions.add((jsonDecode(request.body) as Map)['action'] as String);
        return _json({'data': <Object>[]});
      }),
    );

    final session = await EntertainmentSession.open(
      client: client,
      credentials: const HueCredentials(
        bridge: HueBridgeInfo(id: 'b', host: '127.0.0.1'),
        applicationKey: 'app-key',
        clientKey: _clientKey,
      ),
      area: _area,
      transportFactory: (host, _) => UdpDatagramTransport.connect(host, port),
    );
    expect(actions, ['start']);

    final output = EntertainmentLightOutput(session);
    output.update({
      '0': const LightFrame(LightColor(1, 0, 0), 1),
      '1': const LightFrame(LightColor(0, 1, 0), 0.5),
    }, const Duration(milliseconds: 20));

    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (!latin1.decode(received).contains('HueStream')) {
      if (DateTime.now().isAfter(deadline)) {
        fail('No HueStream message reached the server');
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    final text = latin1.decode(received);
    expect(text, contains(_areaId));

    await output.close();
    expect(actions, ['start', 'stop']);
  }, skip: _hasOpenSsl ? false : 'openssl not installed');
}
