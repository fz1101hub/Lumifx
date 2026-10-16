import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lumifx/src/core/hue/hue_bridge_client.dart';
import 'package:lumifx/src/core/hue/hue_exceptions.dart';
import 'package:lumifx/src/core/hue/hue_models.dart';
import 'package:lumifx/src/core/hue/hue_schedules.dart';

void main() {
  final evening = DateTime(2026, 10, 16, 18, 30);

  test('days become the bridge weekday mask, Monday first', () {
    String weekly(List<int> days) =>
        scheduleLocaltime(hour: 20, minute: 5, days: days, now: evening);
    expect(weekly([0, 1, 2, 3, 4, 5, 6]), 'W127/T20:05:00');
    expect(weekly([0, 1, 2, 3, 4]), 'W124/T20:05:00');
    expect(weekly([5, 6]), 'W003/T20:05:00');
    expect(weekly([0]), 'W064/T20:05:00');
  });

  test('once means the next time it comes, today or tomorrow', () {
    expect(scheduleLocaltime(hour: 20, minute: 0, days: [], now: evening),
        '2026-10-16T20:00:00');
    expect(scheduleLocaltime(hour: 7, minute: 0, days: [], now: evening),
        '2026-10-17T07:00:00');
    expect(
      scheduleLocaltime(
          hour: 0, minute: 0, days: [], now: DateTime(2026, 12, 31, 23)),
      '2027-01-01T00:00:00',
    );
  });

  test('times read back, and anything else is ignored', () {
    final weekly = parseLocaltime('W124/T20:05:00')!;
    expect((weekly.hour, weekly.minute), (20, 5));
    expect(weekly.days, [0, 1, 2, 3, 4]);
    final once = parseLocaltime('2026-10-17T07:00:00')!;
    expect((once.hour, once.minute), (7, 0));
    expect(once.days, isEmpty);
    expect(parseLocaltime('PT00:10:00'), isNull, reason: 'a timer');
    expect(parseLocaltime('W000/T20:00:00'), isNull);
    expect(parseLocaltime('W127/T25:00:00'), isNull);
    expect(parseLocaltime('W127/T20:00:00A00:30:00'), isNull);
  });

  test('an off time past midnight moves to the next day', () {
    expect(stopDays([0, 4, 6], nextDay: true), [0, 1, 5]);
    expect(stopDays([0, 4], nextDay: false), [0, 4]);
  });

  test('older ids are read from the newer API', () {
    expect(v1Id('/groups/3', 'groups'), '3');
    expect(v1Id('/scenes/AbC12dEf', 'scenes'), 'AbC12dEf');
    expect(v1Id('/scenes/AbC', 'groups'), isNull);
    expect(v1Id('/groups/3/../x', 'groups'), isNull);
    expect(v1Id(null, 'groups'), isNull);
  });

  group('on the bridge', () {
    late List<(String, String, Object?)> requests;
    late Map<String, Object?> stored;
    late HueBridgeClient client;

    setUp(() {
      requests = [];
      stored = {
        // One of the Hue app's own schedules: left alone.
        '1': {
          'name': 'Hue timer',
          'description': 'made in the Hue app',
          'command': {
            'address': '/api/key/groups/1/action',
            'method': 'PUT',
            'body': {'on': true},
          },
          'localtime': 'W127/T06:00:00',
          'status': 'enabled',
        },
      };
      var next = 10;
      client = HueBridgeClient(
        host: '10.0.0.5',
        applicationKey: 'key',
        client: MockClient((request) async {
          final body = request.body.isEmpty ? null : jsonDecode(request.body);
          requests.add((request.method, request.url.path, body));
          final path = request.url.path;
          if (request.method == 'GET' && path == '/api/key/schedules') {
            return http.Response(jsonEncode(stored), 200);
          }
          if (request.method == 'POST' && path == '/api/key/schedules') {
            final id = '${next++}';
            stored[id] = body;
            return http.Response(
                jsonEncode([
                  {
                    'success': {'id': id},
                  },
                ]),
                200);
          }
          return http.Response(
              jsonEncode([
                {'success': path},
              ]),
              200);
        }),
      );
    });

    test('a schedule with an off time is two schedules, found as one',
        () async {
      await client.createEffectSchedule(
        const HueEffectScheduleDraft(
          name: 'Fireplace',
          groupId: '3',
          sceneId: 'AbC12dEf',
          hour: 22,
          minute: 30,
          days: [4, 5],
          stopHour: 0,
          stopMinute: 15,
        ),
        now: evening,
      );
      final posts = [
        for (final r in requests)
          if (r.$1 == 'POST') r.$3
      ];
      expect(posts, hasLength(2));
      final start = posts.first! as Map;
      expect(start['command'], {
        'address': '/api/key/groups/3/action',
        'method': 'PUT',
        'body': {'scene': 'AbC12dEf'},
      });
      expect(start['localtime'], 'W006/T22:30:00');
      expect(start['autodelete'], isFalse);
      final stop = posts.last! as Map;
      expect((stop['command'] as Map)['body'], {'on': false});
      // Friday and Saturday nights end on Saturday and Sunday.
      expect(stop['localtime'], 'W003/T00:15:00');

      final schedules = await client.fetchEffectSchedules();
      expect(schedules, hasLength(1));
      final schedule = schedules.single;
      expect(schedule.name, 'Fireplace');
      expect(schedule.groupId, '3');
      expect(schedule.sceneId, 'AbC12dEf');
      expect((schedule.hour, schedule.minute), (22, 30));
      expect(schedule.days, [4, 5]);
      expect((schedule.stopHour, schedule.stopMinute), (0, 15));
      expect(schedule.enabled, isTrue);

      requests.clear();
      await client.setEffectScheduleEnabled(schedule, false);
      expect([
        for (final r in requests) (r.$1, r.$2)
      ], [
        ('PUT', '/api/key/schedules/10'),
        ('PUT', '/api/key/schedules/11'),
      ]);
      for (final r in requests) {
        expect(r.$3, {'status': 'disabled'});
      }

      requests.clear();
      await client.deleteEffectSchedule(schedule);
      expect([
        for (final r in requests) (r.$1, r.$2)
      ], [
        ('DELETE', '/api/key/schedules/10'),
        ('DELETE', '/api/key/schedules/11'),
        ('DELETE', '/api/key/scenes/AbC12dEf'),
      ]);
    });

    test(
        'an ok-to-wake light glows amber the evening before, green in the '
        'morning, then switches off', () async {
      await client.createOkToWake(
        const HueOkToWakeDraft(
          name: 'Mia',
          groupId: '4',
          nightHour: 19,
          nightMinute: 30,
          wakeHour: 7,
          wakeMinute: 0,
          mornings: [0, 1, 2, 3, 4],
          offAfter: Duration(minutes: 60),
        ),
        now: evening,
      );
      final posts = [
        for (final r in requests)
          if (r.$1 == 'POST') r.$3! as Map,
      ];
      expect(posts, hasLength(3));
      final [night, green, off] = posts;
      // Sunday to Thursday evenings, before school mornings.
      expect(night['localtime'], 'W121/T19:30:00');
      final nightBody = (night['command'] as Map)['body'] as Map;
      expect(nightBody['on'], isTrue);
      expect(nightBody['bri'], lessThan(40));
      expect(green['localtime'], 'W124/T07:00:00');
      expect(((green['command'] as Map)['body'] as Map)['xy'],
          [HueOkToWakeDraft.wakeXy.x, HueOkToWakeDraft.wakeXy.y]);
      expect(off['localtime'], 'W124/T08:00:00');
      expect(((off['command'] as Map)['body'] as Map)['on'], isFalse);

      final lights = await client.fetchOkToWake();
      expect(lights, hasLength(1));
      final light = lights.single;
      expect(light.name, 'Mia');
      expect(light.groupId, '4');
      expect((light.nightHour, light.nightMinute), (19, 30));
      expect((light.wakeHour, light.wakeMinute), (7, 0));
      expect((light.offHour, light.offMinute), (8, 0));
      expect(light.mornings, [0, 1, 2, 3, 4]);
      expect(await client.fetchEffectSchedules(), isEmpty,
          reason: 'not taken for a scheduled effect');

      requests.clear();
      await client.deleteOkToWake(light);
      expect(requests.map((r) => r.$1), everyElement('DELETE'));
      expect(requests, hasLength(3));
    });

    test('a night glow after midnight starts the same morning', () async {
      await client.createOkToWake(
        const HueOkToWakeDraft(
          name: 'Late',
          groupId: '4',
          nightHour: 1,
          nightMinute: 0,
          wakeHour: 7,
          wakeMinute: 30,
          mornings: [5, 6],
        ),
        now: evening,
      );
      final posts = [
        for (final r in requests)
          if (r.$1 == 'POST') r.$3! as Map,
      ];
      expect(posts, hasLength(2), reason: 'no off time');
      expect(posts.first['localtime'], 'W003/T01:00:00');
    });

    test('once runs on its day and is removed afterwards', () async {
      await client.createEffectSchedule(
        const HueEffectScheduleDraft(
          name: 'Aurora',
          groupId: '1',
          sceneId: 'X',
          hour: 23,
          minute: 0,
          days: [],
          stopHour: 1,
          stopMinute: 0,
        ),
        now: evening,
      );
      final posts = [
        for (final r in requests)
          if (r.$1 == 'POST') r.$3! as Map,
      ];
      expect(posts.first['localtime'], '2026-10-16T23:00:00');
      expect(posts.last['localtime'], '2026-10-17T01:00:00');
      expect(posts.every((p) => p['autodelete'] == true), isTrue);
    });
  });

  test('a refusal from the older API is an error, not a success', () async {
    final client = HueBridgeClient(
      host: '10.0.0.5',
      applicationKey: 'key',
      client: MockClient((_) async => http.Response(
          jsonEncode([
            {
              'error': {'type': 7, 'description': 'invalid value'},
            },
          ]),
          200)),
    );
    expect(
      client.createEffectSchedule(
        const HueEffectScheduleDraft(
          name: 'x',
          groupId: '1',
          sceneId: 'y',
          hour: 1,
          minute: 2,
          days: [0],
        ),
      ),
      throwsA(isA<HueException>()),
    );
  });

  test('a refused part of an ok-to-wake light leaves nothing behind', () async {
    final deleted = <String>[];
    var posts = 0;
    final client = HueBridgeClient(
      host: '10.0.0.5',
      applicationKey: 'key',
      client: MockClient((request) async {
        if (request.method == 'DELETE') {
          deleted.add(request.url.path);
          return http.Response('[{"success": "ok"}]', 200);
        }
        posts++;
        return http.Response(
            posts == 1
                ? '[{"success": {"id": "21"}}]'
                : '[{"error": {"type": 7, "description": "invalid value"}}]',
            200);
      }),
    );
    await expectLater(
      client.createOkToWake(const HueOkToWakeDraft(
        name: 'x',
        groupId: '1',
        nightHour: 19,
        nightMinute: 0,
        wakeHour: 7,
        wakeMinute: 0,
        mornings: [0],
      )),
      throwsA(isA<HueException>()),
    );
    expect(deleted, ['/api/key/schedules/21']);
  });

  test('evenings before mornings wrap around the week', () {
    expect(daysBefore([0, 3]), [2, 6]);
  });
}
