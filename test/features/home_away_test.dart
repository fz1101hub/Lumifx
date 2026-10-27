import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lumifx/src/core/hue/hue_bridge_client.dart';
import 'package:lumifx/src/core/hue/hue_models.dart';
import 'package:lumifx/src/features/house/home_away.dart';

/// A bridge with this phone's sensor (5), another family phone's (6),
/// a Hue app geofence (7), a motion sensor and the daylight sensor.
class _Bridge {
  _Bridge(
      {this.otherHome = false, this.geofenceHome = false, this.dark = true});

  final bool otherHome;
  final bool geofenceHome;
  final bool dark;
  final requests = <(String, String, Object?)>[];

  late final client = HueBridgeClient(
    host: '10.0.0.5',
    applicationKey: 'key',
    client: MockClient((request) async {
      final body = request.body.isEmpty ? null : jsonDecode(request.body);
      requests.add((request.method, request.url.path, body));
      http.Response ok(Object json) => http.Response(jsonEncode(json), 200);
      if (request.method == 'GET' && request.url.path == '/api/key/sensors') {
        return ok({
          '1': {
            'type': 'Daylight',
            'state': {'daylight': !dark}
          },
          '2': {
            'type': 'ZLLPresence',
            'state': {'presence': true}
          },
          '5': {
            'type': 'CLIPPresence',
            'modelid': 'LumiFXPresence',
            'state': {'presence': true},
          },
          '6': {
            'type': 'CLIPPresence',
            'modelid': 'LumiFXPresence',
            'state': {'presence': otherHome},
          },
          '7': {
            'type': 'Geofence',
            'state': {'presence': geofenceHome}
          },
          '8': {
            'type': 'CLIPPresence',
            'state': {'presence': true}
          },
        });
      }
      if (request.method == 'POST') {
        return ok([
          {
            'success': {'id': '9'},
          },
        ]);
      }
      return ok([
        {'success': request.url.path},
      ]);
    }),
  );

  List<String> get writes => [
        for (final (method, path, body) in requests)
          if (method != 'GET') '$method $path ${jsonEncode(body)}',
      ];
}

const _settings = HomeAwaySettings(
  latitude: 45.07,
  longitude: 7.69,
  sensorId: '5',
  hallGroupId: '3',
);

void main() {
  test('the last one out switches every light off', () async {
    final bridge = _Bridge();
    await leftHome(bridge.client, _settings);
    expect(bridge.writes, [
      'PUT /api/key/sensors/5/state {"presence":false}',
      'PUT /api/key/groups/0/action {"on":false,"transitiontime":20}',
    ]);
  });

  test('with someone else home, the lights stay', () async {
    for (final bridge in [
      _Bridge(otherHome: true),
      _Bridge(geofenceHome: true),
    ]) {
      await leftHome(bridge.client, _settings);
      expect(
          bridge.writes, ['PUT /api/key/sensors/5/state {"presence":false}']);
    }
    final noOff = _Bridge();
    await leftHome(noOff.client, _settings.copyWith(offOnLeave: false));
    expect(noOff.writes, hasLength(1), reason: 'only told it is away');
  });

  test('coming home after dark lights the hall, by day nothing', () async {
    final night = _Bridge();
    await cameHome(night.client, _settings);
    expect(night.writes, [
      'PUT /api/key/sensors/5/state {"presence":true}',
      'PUT /api/key/groups/3/action {"on":true,"bri":180,"ct":366}',
    ]);
    final day = _Bridge(dark: false);
    await cameHome(day.client, _settings);
    expect(day.writes, hasLength(1));
  });

  test('the phone gets a presence sensor of its own', () async {
    final bridge = _Bridge();
    expect(await bridge.client.createPresenceSensor('LumiFX phone', 'lumifx-1'),
        '9');
    final (_, path, body) = bridge.requests.single;
    expect(path, '/api/key/sensors');
    final sent = body! as Map;
    expect(sent['modelid'], 'LumiFXPresence');
    expect(sent['type'], 'CLIPPresence');
  });

  test('settings are written and read back; the config needs a pinned bridge',
      () {
    final back = HomeAwaySettings.decode(_settings.encode())!;
    expect((back.latitude, back.longitude, back.radius, back.hallGroupId),
        (45.07, 7.69, 150, '3'));
    expect(HomeAwaySettings.decode('{"lat":200}'), isNull);
    expect(HomeAwaySettings.decode('nonsense'), isNull);
    const pinned = HueCredentials(
      bridge: HueBridgeInfo(id: '001788fffe000001', host: '10.0.0.5'),
      applicationKey: 'key',
      certificateFingerprint: 'ab',
    );
    final config = homeAwayConfig(_settings, pinned)!;
    expect(config['sensor'], '5');
    expect(config['fingerprint'], 'ab');
    expect(homeAwayConfig(null, pinned), isNull);
    expect(
        homeAwayConfig(
            _settings,
            const HueCredentials(
                bridge: HueBridgeInfo(id: '001788fffe000001', host: '10.0.0.5'),
                applicationKey: 'key')),
        isNull,
        reason: 'never without the pinned certificate');
  });
}
