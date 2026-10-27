import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lumifx/src/core/hue/hue_bridge_client.dart';
import 'package:lumifx/src/core/hue/hue_exceptions.dart';
import 'package:lumifx/src/core/hue/hue_house.dart';
import 'package:lumifx/src/core/hue/hue_models.dart';
import 'package:lumifx/src/core/hue/hue_reminders.dart';

/// A bridge that keeps what it is sent: schedules and rules (older API),
/// scenes and smart scenes (newer API), and lists two sensors.
class _Bridge {
  final requests = <(String, String, Object?)>[];
  final schedules = <String, Object?>{};
  final rules = <String, Object?>{};
  final scenes = <String, Map<String, Object?>>{};
  final smartScenes = <String, Map<String, Object?>>{};
  var next = 10;

  /// Paths whose creation fails, to test the clean-up.
  final failing = <String>{};

  late final client = HueBridgeClient(
    host: '10.0.0.5',
    applicationKey: 'key',
    client: MockClient((request) async {
      final body = request.body.isEmpty ? null : jsonDecode(request.body);
      final path = request.url.path;
      requests.add((request.method, path, body));
      http.Response ok(Object json) => http.Response(jsonEncode(json), 200);
      List<Object> created(String id) => [
            {
              'success': {'id': id},
            },
          ];
      if (failing.contains('${request.method} $path')) {
        return ok([
          {
            'error': {'type': 7, 'description': 'invalid value'},
          },
        ]);
      }
      switch ((request.method, path)) {
        case ('GET', '/api/key/schedules'):
          return ok(schedules);
        case ('POST', '/api/key/schedules'):
          final id = '${next++}';
          schedules[id] = {...body as Map, 'status': 'enabled'};
          return ok(created(id));
        case ('GET', '/api/key/rules'):
          return ok(rules);
        case ('POST', '/api/key/rules'):
          final id = '${next++}';
          rules[id] = {...body as Map, 'status': 'enabled'};
          return ok(created(id));
        case ('GET', '/api/key/sensors'):
          return ok({
            '2': {'type': 'ZLLPresence', 'name': 'Hallway sensor'},
            '3': {'type': 'ZLLLightLevel', 'name': 'Hallway light level'},
            '1': {'type': 'Daylight', 'name': 'Daylight'},
          });
        case ('POST', '/clip/v2/resource/scene'):
          final id = 'scene-${next++}';
          scenes[id] = (body as Map).cast<String, Object?>();
          return ok({
            'data': [
              {'rid': id, 'rtype': 'scene'},
            ],
          });
        case ('POST', '/clip/v2/resource/smart_scene'):
          final id = 'smart-${next++}';
          smartScenes[id] = {
            ...(body as Map).cast<String, Object?>(),
            'id': id,
            'state': 'inactive',
          };
          return ok({
            'data': [
              {'rid': id, 'rtype': 'smart_scene'},
            ],
          });
        case ('GET', '/clip/v2/resource/smart_scene'):
          return ok({'data': smartScenes.values.toList(), 'errors': []});
      }
      if (request.method == 'DELETE' && path.startsWith('/clip/v2/')) {
        scenes.remove(path.split('/').last);
        smartScenes.remove(path.split('/').last);
        return ok({'data': [], 'errors': []});
      }
      if (request.method == 'PUT' && path.startsWith('/clip/v2/')) {
        return ok({'data': [], 'errors': []});
      }
      if (request.method == 'DELETE') {
        schedules.remove(path.split('/').last);
        rules.remove(path.split('/').last);
      }
      return ok([
        {'success': path},
      ]);
    }),
  );

  List<Map<Object?, Object?>> posted(String path) => [
        for (final (method, p, body) in requests)
          if (method == 'POST' && p == path) body! as Map,
      ];
}

void main() {
  final evening = DateTime(2026, 10, 16, 18, 30);

  test('random times are written and read back', () {
    final localtime = randomLocaltime(
        hour: 19, minute: 15, days: [5, 6], now: evening, randomMinutes: 30);
    expect(localtime, 'W003/T19:15:00A00:30:00');
    final back = parseRandomLocaltime(localtime)!;
    expect((back.hour, back.minute, back.randomMinutes), (19, 15, 30));
    expect(back.days, [5, 6]);
    expect(parseRandomLocaltime('W127/T07:00:00')!.randomMinutes, 0);
    expect(parseRandomLocaltime('PT00:10:00'), isNull);
  });

  group('away mode', () {
    test('rooms light up one after the other, at random, and go off', () async {
      final bridge = _Bridge();
      await bridge.client.createAwayMode(
        const HueAwayModeDraft(
          name: 'Away',
          groupIds: ['1', '4'],
          onHour: 19,
          onMinute: 0,
          offHour: 23,
          offMinute: 50,
          days: [0, 1, 2, 3, 4, 5, 6],
        ),
        now: evening,
      );
      final posts = bridge.posted('/api/key/schedules');
      expect(posts, hasLength(4));
      final [on1, off1, on2, off2] = posts;
      expect(on1['localtime'], 'W127/T19:00:00A00:30:00');
      expect(on2['localtime'], 'W127/T19:15:00A00:30:00');
      expect(off1['localtime'], 'W127/T23:50:00A00:30:00');
      // Pushed past midnight: the next day, which for every day is the
      // same set.
      expect(off2['localtime'], 'W127/T00:05:00A00:30:00');
      final onBody = (on1['command'] as Map)['body'] as Map;
      expect(onBody['on'], isTrue);
      expect(onBody['ct'], HueAwayModeDraft.mirek);
      expect((on2['command'] as Map)['address'], '/api/key/groups/4/action');

      final modes = await bridge.client.fetchAwayModes();
      expect(modes, hasLength(1));
      final mode = modes.single;
      expect(mode.name, 'Away');
      expect(mode.groupIds, ['1', '4']);
      expect((mode.onHour, mode.onMinute), (19, 0));
      expect((mode.offHour, mode.offMinute), (0, 5),
          reason: 'the earliest off by the clock');
      expect(mode.days, [0, 1, 2, 3, 4, 5, 6]);
      expect(mode.scheduleIds, hasLength(4));
      expect(await bridge.client.fetchOkToWake(), isEmpty);

      bridge.requests.clear();
      await bridge.client.setAwayModeEnabled(mode, false);
      expect(bridge.requests.map((r) => r.$3),
          everyElement({'status': 'disabled'}));
      await bridge.client.deleteAwayMode(mode);
      expect(bridge.schedules, isEmpty);
    });

    test('weekend evenings, off after midnight on the next days', () async {
      final bridge = _Bridge();
      await bridge.client.createAwayMode(
        const HueAwayModeDraft(
          name: 'Weekend',
          groupIds: ['1'],
          onHour: 20,
          onMinute: 0,
          offHour: 0,
          offMinute: 30,
          days: [4, 5],
        ),
        now: evening,
      );
      final [on, off] = bridge.posted('/api/key/schedules');
      expect(on['localtime'], 'W006/T20:00:00A00:30:00');
      expect(off['localtime'], 'W003/T00:30:00A00:30:00');
    });

    test('a room pushed past midnight goes off on the right day', () async {
      final bridge = _Bridge();
      await bridge.client.createAwayMode(
        const HueAwayModeDraft(
          name: 'Monday',
          groupIds: ['1', '4'],
          onHour: 23,
          onMinute: 50,
          offHour: 23,
          offMinute: 45,
          days: [0],
        ),
        now: evening,
      );
      final [on1, off1, on2, off2] = bridge.posted('/api/key/schedules');
      expect(on1['localtime'], 'W064/T23:50:00A00:30:00', reason: 'Monday');
      expect(off1['localtime'], 'W032/T23:45:00A00:30:00', reason: 'Tuesday');
      expect(on2['localtime'], 'W032/T00:05:00A00:30:00', reason: 'Tuesday');
      expect(off2['localtime'], 'W016/T00:00:00A00:30:00',
          reason: 'Wednesday, after it came on, not Tuesday before');
    });

    test('nothing is left behind when the bridge refuses', () async {
      final bridge = _Bridge();
      await bridge.client.createAwayMode(
        const HueAwayModeDraft(
          name: 'Away',
          groupIds: ['1'],
          onHour: 19,
          onMinute: 0,
          offHour: 23,
          offMinute: 0,
          days: [0],
        ),
        now: evening,
      );
      bridge.failing.add('POST /api/key/schedules');
      await expectLater(
        bridge.client.createAwayMode(
          const HueAwayModeDraft(
            name: 'No',
            groupIds: [],
            onHour: 19,
            onMinute: 0,
            offHour: 23,
            offMinute: 0,
            days: [0],
          ),
        ),
        throwsA(isA<HueException>()),
      );
      expect(bridge.schedules, hasLength(2), reason: 'the first one stays');
    });
  });

  group('night path', () {
    test('motion at night: dim and warm; off after the last movement',
        () async {
      final bridge = _Bridge();
      final sensors = await bridge.client.fetchMotionSensors();
      expect(sensors.map((s) => (s.id, s.name)), [('2', 'Hallway sensor')]);

      await bridge.client.createNightPath(
        const HueNightPathDraft(
          sensorId: '2',
          groupId: '5',
          fromHour: 22,
          fromMinute: 0,
          toHour: 7,
          toMinute: 0,
          minutes: 5,
        ),
        now: evening,
      );
      final [on, off] = bridge.posted('/api/key/rules');
      expect((on['name'] as String).length, lessThanOrEqualTo(32));
      expect(on['conditions'], [
        {
          'address': '/sensors/2/state/presence',
          'operator': 'eq',
          'value': 'true',
        },
        {'address': '/sensors/2/state/presence', 'operator': 'dx'},
        {
          'address': '/config/localtime',
          'operator': 'in',
          'value': 'T22:00:00/T07:00:00',
        },
      ]);
      final action = (on['actions'] as List).single as Map;
      expect(action['address'], '/groups/5/action');
      expect((action['body'] as Map)['bri'], HueNightPathDraft.brightness);
      final offConditions = off['conditions'] as List;
      expect(offConditions[1], {
        'address': '/sensors/2/state/presence',
        'operator': 'ddx',
        'value': 'PT00:05:00',
      });
      expect((offConditions[2] as Map)['value'], 'T22:00:00/T07:35:00',
          reason: 'a little past the morning, to switch off in time');

      final paths = await bridge.client.fetchNightPaths();
      expect(paths, hasLength(1));
      final path = paths.single;
      expect((path.sensorId, path.groupId, path.minutes), ('2', '5', 5));
      expect((path.fromHour, path.toHour), (22, 7));
      expect(path.enabled, isTrue);

      await bridge.client.setNightPathEnabled(path, false);
      await bridge.client.deleteNightPath(path);
      expect(bridge.rules, isEmpty);
    });

    test('the first rule goes when the second is refused', () async {
      final bridge = _Bridge();
      var calls = 0;
      // Fail on the second POST only.
      final client = HueBridgeClient(
        host: '10.0.0.5',
        applicationKey: 'key',
        client: MockClient((request) async {
          if (request.method == 'POST') {
            calls++;
            if (calls == 2) {
              return http.Response(
                  jsonEncode([
                    {
                      'error': {'type': 7, 'description': 'bad'},
                    },
                  ]),
                  200);
            }
            return http.Response(
                jsonEncode([
                  {
                    'success': {'id': '42'},
                  },
                ]),
                200);
          }
          bridge.requests.add((request.method, request.url.path, null));
          return http.Response(
              jsonEncode([
                {'success': 'ok'}
              ]),
              200);
        }),
      );
      await expectLater(
        client.createNightPath(const HueNightPathDraft(
          sensorId: '2',
          groupId: '5',
          fromHour: 22,
          fromMinute: 0,
          toHour: 7,
          toMinute: 0,
          minutes: 2,
        )),
        throwsA(isA<HueException>()),
      );
      expect(bridge.requests.single, ('DELETE', '/api/key/rules/42', null));
    });
  });

  group('natural light', () {
    const color = HueLight(
      id: 'color',
      name: 'Color',
      deviceId: 'd1',
      isOn: true,
      brightness: 50,
      supportsColor: true,
      supportsColorTemperature: true,
      mirekMin: 153,
      mirekMax: 500,
    );
    const ambiance = HueLight(
      id: 'white',
      name: 'Ambiance',
      deviceId: 'd2',
      isOn: true,
      brightness: 50,
      supportsColorTemperature: true,
      mirekMin: 153,
      mirekMax: 454,
    );
    const plain = HueLight(
      id: 'plain',
      name: 'Plain',
      deviceId: 'd3',
      isOn: true,
      brightness: 50,
    );
    const elsewhere = HueLight(
      id: 'other',
      name: 'Other room',
      deviceId: 'd4',
      isOn: true,
      brightness: 50,
    );
    const room = HueGroup(
      id: 'room-1',
      name: 'Living room',
      kind: HueGroupKind.room,
      lightIds: ['color', 'white', 'plain'],
    );

    test('a scene for each part of the day and a smart scene between them',
        () async {
      final bridge = _Bridge();
      final id = await bridge.client.createNaturalLight(
        name: 'Natural light Living room',
        group: room,
        lights: [color, ambiance, plain, elsewhere],
        slotNames: ['Morning', 'Day', 'Afternoon', 'Evening', 'Night'],
      );
      expect(bridge.scenes, hasLength(NaturalLightSlot.day.length));
      final night = bridge.scenes.values.last;
      expect((night['metadata'] as Map)['name'], 'Night');
      final actions = {
        for (final a in night['actions']! as List)
          ((a as Map)['target'] as Map)['rid']: a['action'] as Map,
      };
      expect(actions.keys, ['color', 'white', 'plain'],
          reason: 'only the lights of the room');
      expect(actions['color']!['color_temperature'], {'mirek': 454});
      expect(actions['white']!['color_temperature'], {'mirek': 454});
      expect(actions['plain']!.containsKey('color_temperature'), isFalse);
      expect(actions['plain']!['dimming'], {'brightness': 35.0});

      final smart = bridge.smartScenes[id]!;
      expect(smart['group'], {'rid': 'room-1', 'rtype': 'room'});
      final slots = ((smart['week_timeslots'] as List).single
          as Map)['timeslots'] as List;
      expect(slots, hasLength(NaturalLightSlot.day.length));
      expect((slots.first as Map)['start_time'], {
        'kind': 'time',
        'time': {'hour': 6, 'minute': 30, 'second': 0},
      });

      final found = await bridge.client.fetchNaturalLights({id});
      expect(found.single.sceneIds, bridge.scenes.keys.toList());
      expect(found.single.active, isFalse);
      expect(await bridge.client.fetchNaturalLights({'someone-else'}), isEmpty);

      bridge.requests.clear();
      await bridge.client.setNaturalLightActive(found.single, true);
      expect(bridge.requests.single.$3, {
        'recall': {'action': 'activate'},
      });
      await bridge.client.deleteNaturalLight(found.single);
      expect(bridge.smartScenes, isEmpty);
      expect(bridge.scenes, isEmpty);
    });

    test('a room without dimmable lights is refused', () async {
      final bridge = _Bridge();
      await expectLater(
        bridge.client.createNaturalLight(
          name: 'x',
          group: room,
          lights: const [elsewhere],
          slotNames: List.filled(5, 'x'),
        ),
        throwsA(isA<HueException>()),
      );
      expect(bridge.scenes, isEmpty);
    });
  });

  group('light reminders', () {
    test('a colour at a time on the chosen days, switched off later', () async {
      final bridge = _Bridge();
      await bridge.client.createLightReminder(
        const HueLightReminderDraft(
          name: 'Plastic out',
          groupId: '3',
          hour: 23,
          minute: 30,
          days: [1],
          color: '#FFD23F',
          offAfterMinutes: 60,
        ),
        now: evening,
      );
      final [on, off] = bridge.posted('/api/key/schedules');
      expect(on['localtime'], 'W032/T23:30:00', reason: 'Tuesdays');
      final body = (on['command'] as Map)['body'] as Map;
      expect(body['on'], isTrue);
      expect(body['alert'], 'lselect');
      expect(body['xy'], hasLength(2));
      expect((on['command'] as Map)['address'], '/api/key/groups/3/action');
      // An hour later is past midnight: Wednesday.
      expect(off['localtime'], 'W016/T00:30:00');
      expect(((off['command'] as Map)['body'] as Map)['on'], isFalse);

      final reminders = await bridge.client.fetchLightReminders();
      final reminder = reminders.single;
      expect(reminder.name, 'Plastic out');
      expect(reminder.groupId, '3');
      expect((reminder.hour, reminder.minute), (23, 30));
      expect(reminder.days, [1]);
      expect(reminder.color, '#FFD23F');
      expect(reminder.offAfterMinutes, 60);
      expect(reminder.enabled, isTrue);
      expect(await bridge.client.fetchAwayModes(), isEmpty,
          reason: 'not taken for an away mode');

      await bridge.client.deleteSchedules(reminder.scheduleIds);
      expect(bridge.schedules, isEmpty);
    });

    test('one that stays on has a single schedule', () async {
      final bridge = _Bridge();
      await bridge.client.createLightReminder(
        const HueLightReminderDraft(
          name: 'Medicine',
          groupId: '1',
          hour: 21,
          minute: 0,
          days: [0, 1, 2, 3, 4, 5, 6],
          color: '#B388FF',
        ),
        now: evening,
      );
      final reminder = (await bridge.client.fetchLightReminders()).single;
      expect(reminder.offAfterMinutes, isNull);
      expect(reminder.scheduleIds, hasLength(1));
    });
  });

  group('night switch-off', () {
    test('every night each room fades out, and a new one replaces it',
        () async {
      final bridge = _Bridge();
      expect(await bridge.client.fetchNightOff(), isNull);
      await bridge.client.setNightOff(
        const HueNightOffDraft(
            groupIds: ['1', '2'], hour: 1, minute: 0, fadeMinutes: 10),
        now: evening,
      );
      final posts = bridge.posted('/api/key/schedules');
      expect(posts, hasLength(2));
      expect(posts.first['localtime'], 'W127/T01:00:00');
      expect(((posts.first['command'] as Map)['body'] as Map),
          {'on': false, 'transitiontime': 6000});
      final first = (await bridge.client.fetchNightOff())!;
      expect(first.groupIds, unorderedEquals(['1', '2']));
      expect((first.hour, first.minute, first.fadeMinutes), (1, 0, 10));

      await bridge.client.setNightOff(
        const HueNightOffDraft(groupIds: ['4'], hour: 0, minute: 30),
        replacing: first,
        now: evening.add(const Duration(seconds: 1)),
      );
      final second = (await bridge.client.fetchNightOff())!;
      expect(second.groupIds, ['4']);
      expect(bridge.schedules, hasLength(1), reason: 'the old one is gone');

      await bridge.client.setSchedulesEnabled(second.scheduleIds, false);
      expect(bridge.requests.last.$3, {'status': 'disabled'});
    });
  });

  test('the tooth fairy glows once near dawn, and can be cancelled', () async {
    final bridge = _Bridge();
    await bridge.client
        .createFairyVisit(groupId: '2', hour: 6, minute: 0, now: evening);
    final [on, off] = bridge.posted('/api/key/schedules');
    // Tomorrow morning, once.
    expect(on['localtime'], '2026-10-17T06:00:00');
    expect(on['autodelete'], isTrue);
    final body = (on['command'] as Map)['body'] as Map;
    expect(body['bri'], lessThanOrEqualTo(60), reason: 'not enough to wake');
    expect(off['localtime'], '2026-10-17T06:15:00');
    await bridge.client.cancelFairyVisits();
    expect(bridge.schedules, isEmpty);
  });

  test('lights before appointments: one per time, replaced on each sync',
      () async {
    final bridge = _Bridge();
    final made = await bridge.client.syncCalendarLights(
      times: [
        evening.add(const Duration(hours: 1)),
        DateTime(2026, 10, 17, 9, 20),
        evening.subtract(const Duration(minutes: 1)),
        evening.add(const Duration(days: 2)),
      ],
      groupId: '3',
      color: '#FF8C1A',
      now: evening,
    );
    expect(made, 2, reason: 'past and far-off times are left out');
    final [first, second] = bridge.posted('/api/key/schedules');
    expect(second['localtime'], '2026-10-17T09:20:00');
    expect(first['autodelete'], isTrue);
    expect(first['name'], 'LumiFX calendar',
        reason: 'what the appointment is never reaches the bridge');
    expect((first['command'] as Map)['address'], '/api/key/groups/3/action');
    expect(bridge.schedules, hasLength(2));

    await bridge.client.syncCalendarLights(
      times: [DateTime(2026, 10, 17, 8)],
      groupId: '3',
      color: '#FF8C1A',
      now: evening,
    );
    expect(bridge.schedules, hasLength(1));
    await bridge.client.clearCalendarLights();
    expect(bridge.schedules, isEmpty);
  });
}
