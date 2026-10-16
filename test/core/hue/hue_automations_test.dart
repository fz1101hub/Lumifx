import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lumifx/src/core/hue/hue_automations.dart';
import 'package:lumifx/src/core/hue/hue_bridge_client.dart';
import 'package:lumifx/src/core/hue/hue_models.dart';

http.Response _json(Object body) => http.Response(jsonEncode(body), 200);

void main() {
  late List<(String, String, Map<String, Object?>?)> requests;

  HueBridgeClient client() => HueBridgeClient(
        host: '10.0.0.5',
        applicationKey: 'key',
        client: MockClient((request) async {
          requests.add((
            request.method,
            request.url.path,
            request.body.isEmpty
                ? null
                : jsonDecode(request.body) as Map<String, Object?>,
          ));
          if (request.method == 'POST') {
            return _json({
              'data': [
                {'rid': 'new', 'rtype': 'behavior_instance'},
              ],
            });
          }
          if (request.method != 'GET') {
            return _json({'data': <Object>[]});
          }
          switch (request.url.path) {
            case '/clip/v2/resource/behavior_script':
              return _json({
                'data': [
                  {
                    'id': HueBridgeClient.wakeUpScriptId,
                    'metadata': {'name': 'Basic wake up routine'},
                  },
                  {
                    'id': 'sleep-script',
                    'metadata': {'name': 'Basic go to sleep routine'},
                  },
                  {
                    'id': 'timer-script',
                    'metadata': {'name': 'Timers'},
                  },
                ],
              });
            case '/clip/v2/resource/behavior_instance':
              return _json({
                'data': [
                  {
                    'id': 'w1',
                    'script_id': HueBridgeClient.wakeUpScriptId,
                    'enabled': true,
                    'metadata': {'name': 'Wake Weekends'},
                    'configuration': {
                      'end_brightness': 100.0,
                      'fade_in_duration': {'seconds': 1200},
                      'style': 'sunrise',
                      'when': {
                        'recurrence_days': ['saturday', 'sunday'],
                        'time_point': {
                          'time': {'hour': 6, 'minute': 0},
                          'type': 'time',
                        },
                      },
                      'where': [
                        {
                          'group': {'rid': 'r1', 'rtype': 'room'},
                        },
                      ],
                    },
                  },
                  {
                    'id': 't1',
                    'script_id': 'timer-script',
                    'enabled': true,
                    'metadata': {'name': 'Egg timer'},
                    'configuration': <String, Object>{},
                  },
                ],
              });
          }
          return _json({'data': <Object>[]});
        }),
      );

  setUp(() => requests = []);

  test('reads the wake-up and bedtime routines, ignores the rest', () async {
    final automations = await client().fetchAutomations();
    final wake = automations.single;
    expect(wake.kind, HueAutomationKind.wakeUp);
    expect(wake.name, 'Wake Weekends');
    expect(wake.enabled, isTrue);
    expect((wake.hour, wake.minute), (6, 0));
    expect(wake.days, [5, 6]);
    expect(wake.groupIds, ['r1']);
    expect(wake.fade, const Duration(minutes: 20));
  });

  test('creates a bedtime routine with the bridge script found by name',
      () async {
    await client().createAutomation(const HueAutomationDraft(
      kind: HueAutomationKind.goToSleep,
      name: 'Night',
      hour: 22,
      minute: 30,
      days: [0, 1, 2, 3, 4, 5, 6],
      groups: [
        HueGroup(
          id: 'z1',
          name: 'Upstairs',
          kind: HueGroupKind.zone,
          lightIds: ['l1'],
        ),
      ],
      fade: Duration(minutes: 30),
    ));
    final (method, path, body) = requests.last;
    expect(method, 'POST');
    expect(path, '/clip/v2/resource/behavior_instance');
    expect(body!['script_id'], 'sleep-script');
    expect(body['metadata'], {'name': 'Night'});
    final configuration = body['configuration']! as Map;
    expect(configuration['fade_out_duration'], {'seconds': 1800});
    expect((configuration['when'] as Map)['recurrence_days'], hasLength(7));
    expect(configuration['where'], [
      {
        'group': {'rid': 'z1', 'rtype': 'zone'},
      },
    ]);
  });

  test('a one-off sunrise wake-up, then switched off and deleted', () async {
    final hue = client();
    await hue.createAutomation(const HueAutomationDraft(
      kind: HueAutomationKind.wakeUp,
      name: 'Flight',
      hour: 5,
      minute: 15,
      days: [],
      groups: [
        HueGroup(
          id: 'r1',
          name: 'Bedroom',
          kind: HueGroupKind.room,
          lightIds: ['l1'],
        ),
      ],
      fade: Duration(minutes: 10),
    ));
    final configuration = requests.last.$3!['configuration']! as Map;
    expect(requests.last.$3!['script_id'], HueBridgeClient.wakeUpScriptId);
    expect(configuration['style'], 'sunrise');
    expect(configuration['end_brightness'], 100.0);
    expect(
        (configuration['when'] as Map).containsKey('recurrence_days'), isFalse,
        reason: 'no days means once');
    expect(
      ((configuration['when'] as Map)['time_point'] as Map)['time'],
      {'hour': 5, 'minute': 15},
    );

    await hue.setAutomationEnabled('w1', false);
    expect(requests.last.$1, 'PUT');
    expect(requests.last.$3, {'enabled': false});
    await hue.deleteAutomation('w1');
    expect(requests.last.$1, 'DELETE');
    expect(requests.last.$2, '/clip/v2/resource/behavior_instance/w1');
  });
}
