import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lumifx/src/core/hue/hue_bridge_client.dart';
import 'package:lumifx/src/core/hue/hue_health.dart';

HueBridgeClient _client({bool v2 = true}) => HueBridgeClient(
      host: '10.0.0.5',
      applicationKey: 'key',
      client: MockClient((request) async {
        http.Response ok(Object json) => http.Response(jsonEncode(json), 200);
        switch (request.url.path) {
          case '/api/key/lights':
            return ok({
              '1': {
                'name': 'Sofa',
                'uniqueid': '00:17:88:01:aa:00:00:01-0b',
                'state': {'reachable': true},
                'swupdate': {'state': 'noupdates'},
              },
              '2': {
                'name': 'attic',
                'uniqueid': '00:17:88:01:AA:00:00:02-0b',
                'state': {'reachable': true},
                'swupdate': {'state': 'readytoinstall'},
              },
              '3': {
                'name': 'Garden',
                'uniqueid': '00:17:88:01:aa:00:00:03-0b',
                'state': {'reachable': false},
              },
              '4': {
                'name': 'Bedroom',
                'uniqueid': '00:17:88:01:aa:00:00:04-0b',
                'state': {'reachable': true},
              },
            });
          case '/api/key/config':
            return ok({
              'swupdate2': {'state': 'noupdates'},
            });
          case '/clip/v2/resource/zigbee_connectivity':
            if (!v2) {
              return http.Response('', 404);
            }
            return ok({
              'data': [
                {
                  'mac_address': '00:17:88:01:aa:00:00:04',
                  'status': 'connectivity_issue',
                },
                {
                  'mac_address': '00:17:88:01:aa:00:00:01',
                  'status': 'connected',
                },
              ],
            });
        }
        return http.Response('', 404);
      }),
    );

void main() {
  test('lamps are reported worst first, then by name', () async {
    final report = await _client().fetchHealth();
    expect([for (final l in report.lights) l.name],
        ['Garden', 'Bedroom', 'attic', 'Sofa']);
    expect(report.lights[0].issues, {LightIssue.unreachable});
    expect(report.lights[1].issues, {LightIssue.weakSignal});
    expect(report.lights[2].issues, {LightIssue.updateReady});
    expect(report.lights[3].isFine, isTrue);
    expect(report.problems, 3);
    expect(report.bridgeUpdateReady, isFalse);
  });

  test('without the radio link the rest is still reported', () async {
    final report = await _client(v2: false).fetchHealth();
    expect(report.problems, 2);
  });
}
