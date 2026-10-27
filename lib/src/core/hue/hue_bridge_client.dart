import 'dart:convert';

import 'package:http/http.dart' as http;

import '../color/light_color.dart';
import 'hue_buttons.dart';
import 'hue_exceptions.dart';
import 'hue_automations.dart';
import 'hue_health.dart';
import 'hue_house.dart';
import 'hue_models.dart';
import 'hue_reminders.dart';
import 'hue_schedules.dart';

part 'hue_health_client.dart';
part 'hue_house_client.dart';
part 'hue_presence_client.dart';
part 'hue_reminders_client.dart';

/// Everything LumiFX reads from a bridge in one snapshot.
class HueHome {
  const HueHome({
    required this.lights,
    required this.rooms,
    required this.zones,
    this.entertainmentAreas = const [],
    this.entertainmentServices = const [],
    this.scenes = const [],
  });

  final Map<String, HueLight> lights;
  final List<HueGroup> rooms;
  final List<HueGroup> zones;
  final List<HueEntertainmentArea> entertainmentAreas;

  /// Lights that can be added to an entertainment area.
  final List<HueEntertainmentService> entertainmentServices;

  /// Scenes made in the Hue app, for every room and zone.
  final List<HueScene> scenes;

  List<HueGroup> get groups => [...rooms, ...zones];

  List<HueScene> scenesOf(String groupId) => [
        for (final scene in scenes)
          if (scene.groupId == groupId) scene
      ];
}

/// Talks to one Hue Bridge over its local HTTPS API.
///
/// Pairing uses the v1 `/api` endpoint (the only way to create an
/// application key); everything else uses CLIP API v2.
class HueBridgeClient {
  HueBridgeClient({
    required this.host,
    required http.Client client,
    this.applicationKey,
  }) : _client = client;

  final String host;
  final String? applicationKey;
  final http.Client _client;

  static const _timeout = Duration(seconds: 6);

  /// How long a request may take before it counts as failed.
  static const requestTimeout = _timeout;

  /// Releases the underlying connections.
  void close() => _client.close();

  /// Reads the bridge's public configuration; works without pairing and is
  /// used to confirm that a manually entered address really is a bridge.
  Future<HueBridgeInfo> fetchInfo() async {
    final response =
        await _client.get(Uri.https(host, '/api/0/config')).timeout(_timeout);
    final body = _decode(response);
    final config = body is Map ? body : const {};
    final id = config['bridgeid'];
    if (id is! String || !HueBridgeInfo.isValidId(id.toLowerCase())) {
      throw const HueException('This device does not look like a Hue Bridge');
    }
    return HueBridgeInfo(
      id: id.toLowerCase(),
      host: host,
      name: config['name'] as String?,
    );
  }

  /// Creates an application key. Throws [LinkButtonNotPressedException]
  /// until the user presses the bridge's button, so callers poll this.
  Future<({String applicationKey, String? clientKey})> pair({
    String deviceName = 'app',
  }) async {
    final device =
        deviceName.length > 19 ? deviceName.substring(0, 19) : deviceName;
    final response = await _client
        .post(
          Uri.https(host, '/api'),
          headers: {'content-type': 'application/json'},
          body: jsonEncode({
            'devicetype': 'lumifx#$device',
            'generateclientkey': true,
          }),
        )
        .timeout(_timeout);
    final body = _decode(response);
    final first = body is List && body.isNotEmpty ? body.first : null;
    if (first is Map) {
      final success = first['success'];
      if (success is Map && success['username'] is String) {
        return (
          applicationKey: success['username'] as String,
          clientKey: success['clientkey'] as String?,
        );
      }
      final error = first['error'];
      if (error is Map) {
        if (error['type'] == 101) {
          throw const LinkButtonNotPressedException();
        }
        throw HueException('${error['description'] ?? 'Pairing failed'}');
      }
    }
    throw const HueException('Unexpected pairing response');
  }

  Future<HueHome> fetchHome() async {
    final results = await Future.wait([
      _resources('light').catchError(
        (Object _) => throw const UnsupportedBridgeException(),
        test: (error) => error is HueException && error.statusCode == 404,
      ),
      _resources('room'),
      _resources('zone'),
      // Optional: streaming is a bonus, not a reason to fail loading.
      _resources('entertainment_configuration').catchError(_noResources),
      _resources('entertainment').catchError(_noResources),
      _resources('scene').catchError(_noResources),
    ]);
    final lights = {
      for (final json in results[0])
        json['id']! as String: HueLight.fromJson(json),
    };
    final lightsByDevice = <String, List<String>>{};
    for (final light in lights.values) {
      final device = light.deviceId;
      if (device != null) {
        (lightsByDevice[device] ??= []).add(light.id);
      }
    }

    HueGroup group(Map<String, Object?> json, HueGroupKind kind) {
      final lightIds = <String>[];
      for (final child in _list(json['children'])) {
        final rid = child['rid'];
        switch (child['rtype']) {
          case 'light' when lights.containsKey(rid):
            lightIds.add(rid! as String);
          case 'device':
            lightIds.addAll(lightsByDevice[rid] ?? const []);
        }
      }
      final groupedLight = _list(json['services'])
          .where((s) => s['rtype'] == 'grouped_light')
          .map((s) => s['rid'] as String?)
          .firstOrNull;
      final metadata = json['metadata'];
      return HueGroup(
        id: json['id']! as String,
        name: metadata is Map ? metadata['name'] as String? ?? '' : '',
        archetype: metadata is Map ? metadata['archetype'] as String? : null,
        kind: kind,
        lightIds: lightIds,
        groupedLightId: groupedLight,
        idV1: v1Id(json['id_v1'], 'groups'),
      );
    }

    // Entertainment services belong to devices, like room children; newer
    // firmware also names the light directly.
    final services = [
      for (final json in results[4])
        HueEntertainmentService(
          id: json['id']! as String,
          lightIds: switch (_map(json['renderer_reference'])['rid']) {
            final String light when lights.containsKey(light) => [light],
            _ => lightsByDevice[_map(json['owner'])['rid']] ?? const [],
          },
          isRenderer: json['renderer'] as bool? ?? true,
          maxStreams: (json['max_streams'] as num?)?.toInt() ?? 1,
        ),
    ];
    final lightsByEntertainment = {
      for (final service in services) service.id: service.lightIds,
    };

    HueEntertainmentArea area(Map<String, Object?> json) {
      final metadata = _map(json['metadata']);
      return HueEntertainmentArea(
        id: json['id']! as String,
        name: metadata['name'] as String? ??
            json['name'] as String? ??
            'Entertainment area',
        configurationType: json['configuration_type'] as String?,
        isStreaming: json['status'] == 'active',
        locations: [
          for (final location
              in _list(_map(json['locations'])['service_locations']))
            HueServiceLocation(
              serviceId: _map(location['service'])['rid'] as String? ?? '',
              positions: [
                for (final position in location['positions'] is List
                    ? location['positions']! as List
                    : [location['position']])
                  HuePosition.fromJson(position),
              ],
            ),
        ],
        channels: [
          for (final channel in _list(json['channels']))
            HueEntertainmentChannel(
              id: (channel['channel_id']! as num).toInt(),
              x: _coordinate(channel, 'x'),
              y: _coordinate(channel, 'y'),
              z: _coordinate(channel, 'z'),
              lightIds: [
                for (final member in _list(channel['members']))
                  ...?lightsByEntertainment[_map(member['service'])['rid']],
              ],
            ),
        ],
      );
    }

    return HueHome(
      lights: lights,
      rooms: [for (final json in results[1]) group(json, HueGroupKind.room)],
      zones: [for (final json in results[2]) group(json, HueGroupKind.zone)],
      entertainmentAreas: [for (final json in results[3]) area(json)],
      entertainmentServices: services,
      scenes: [for (final json in results[5]) HueScene.fromJson(json)],
    );
  }

  /// Shows a scene on its room or zone, as the Hue app does: a dynamic
  /// scene starts moving through its palette.
  Future<void> recallScene(String sceneId, {bool dynamic = false}) =>
      _put('scene/$sceneId', {
        'recall': {'action': dynamic ? 'dynamic_palette' : 'active'},
      });

  /// The longest scene or routine name the bridge accepts.
  static const maxSceneNameLength = 32;

  /// [name] trimmed to what the bridge accepts, without splitting a
  /// character.
  static String _clipName(String name) {
    final trimmed = name.trim();
    final runes = trimmed.runes;
    return runes.length <= maxSceneNameLength
        ? trimmed
        : String.fromCharCodes(runes.take(maxSceneNameLength)).trim();
  }

  /// Saves a scene on [group] with one action per light and returns its
  /// id. It then shows up in the Hue app, on switches and in voice
  /// assistants like any scene made there.
  ///
  /// With a [palette] the scene is dynamic: recalled from the Hue app,
  /// a switch or a voice assistant it keeps moving through those colours
  /// by itself, without LumiFX.
  Future<String> createScene({
    required String name,
    required HueGroup group,
    required Map<String, HueLightCommand> actions,
    HueScenePalette? palette,
  }) async {
    final trimmed = name.trim();
    final response = await _client
        .post(
          Uri.https(host, '/clip/v2/resource/scene'),
          headers: {..._headers, 'content-type': 'application/json'},
          body: jsonEncode({
            'type': 'scene',
            'metadata': {'name': _clipName(trimmed)},
            'group': {'rid': group.id, 'rtype': group.kind.name},
            'actions': [
              for (final MapEntry(key: id, value: command) in actions.entries)
                {
                  'target': {'rid': id, 'rtype': 'light'},
                  // A scene stores a state, not a fade to it.
                  'action': command.withoutTransition().toJson(),
                },
            ],
            if (palette != null) ...{
              'palette': palette.toJson(),
              'speed': _round(palette.speed.clamp(0.0, 1.0), 3),
              'auto_dynamic': true,
            },
          }),
        )
        .timeout(_timeout);
    final body = _decode(response);
    final created = body is Map ? _list(body['data']).firstOrNull : null;
    final id = created?['rid'];
    if (id is! String) {
      throw const HueException('The bridge did not create the scene');
    }
    return id;
  }

  /// The Hue switches and smart buttons, with their buttons.
  Future<List<HueButtonDevice>> fetchButtonDevices() async {
    final results = await Future.wait([
      _resources('button'),
      _resources('device'),
    ]);
    return buttonDevicesOf(results[0], results[1]);
  }

  /// Button presses as they happen, from the bridge's event stream. The
  /// stream ends when the connection drops; listen again to reconnect.
  Stream<HueButtonEvent> buttonEvents() async* {
    await for (final data in _events()) {
      yield* Stream.fromIterable(buttonEventsOf(data));
    }
  }

  /// Motion on the bridge's motion sensors, while listened to.
  Stream<HueMotionEvent> motionEvents() async* {
    await for (final data in _events()) {
      yield* Stream.fromIterable(motionEventsOf(data));
    }
  }

  /// The `data:` lines of the bridge's event stream.
  Stream<String> _events() async* {
    final request = http.Request('GET', Uri.https(host, '/eventstream/clip/v2'))
      ..headers.addAll({..._headers, 'accept': 'text/event-stream'});
    final response = await _client.send(request).timeout(_timeout);
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const UnauthorizedException();
    }
    if (response.statusCode != 200) {
      throw HueException('Event stream refused (${response.statusCode})',
          statusCode: response.statusCode);
    }
    final lines =
        response.stream.transform(utf8.decoder).transform(const LineSplitter());
    await for (final line in lines) {
      if (line.startsWith('data:')) {
        yield line.substring(5).trim();
      }
    }
  }

  /// The effects the bridge plays at set times (see [HueEffectSchedule]).
  Future<List<HueEffectSchedule>> fetchEffectSchedules() async {
    final response = await _client.get(_v1('/schedules')).timeout(_timeout);
    final body = _v1Result(response);
    if (body is! Map) {
      return const [];
    }
    final starts = <String, (String, Map<Object?, Object?>)>{};
    final stops = <String, (String, Map<Object?, Object?>)>{};
    for (final MapEntry(:key, :value) in body.entries) {
      final description = value is Map ? value['description'] : null;
      if (key is! String ||
          value is! Map ||
          description is! String ||
          !description.startsWith(HueEffectSchedule.tag)) {
        continue;
      }
      final parts =
          description.substring(HueEffectSchedule.tag.length).split(':');
      if (parts.length == 2) {
        (parts[1] == 'stop' ? stops : starts)[parts[0]] = (key, value);
      }
    }
    return [
      for (final MapEntry(key: token, value: (id, json)) in starts.entries)
        if (_effectSchedule(id, json, stops[token]) case final schedule?)
          schedule,
    ]..sort(
        (a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute));
  }

  static HueEffectSchedule? _effectSchedule(
    String id,
    Map<Object?, Object?> json,
    (String, Map<Object?, Object?>)? stop,
  ) {
    final when = parseLocaltime('${json['localtime'] ?? ''}');
    final command = json['command'];
    final address = command is Map ? command['address'] : null;
    final body = command is Map ? command['body'] : null;
    final scene = body is Map ? body['scene'] : null;
    final group = address is String
        ? RegExp(r'/groups/([A-Za-z0-9]+)/action$')
            .firstMatch(address)
            ?.group(1)
        : null;
    if (when == null || group == null || scene is! String) {
      return null;
    }
    final stopWhen =
        stop == null ? null : parseLocaltime('${stop.$2['localtime'] ?? ''}');
    final name = json['name'];
    return HueEffectSchedule(
      id: id,
      name: name is String ? name : '',
      groupId: group,
      sceneId: scene,
      hour: when.hour,
      minute: when.minute,
      days: when.days,
      enabled: json['status'] == 'enabled',
      stopId: stopWhen == null ? null : stop!.$1,
      stopHour: stopWhen?.hour,
      stopMinute: stopWhen?.minute,
    );
  }

  /// Stores [draft] on the bridge: one schedule recalls the scene, and
  /// another switches the room off when it has a stop time. A single day
  /// ([HueEffectScheduleDraft.days] empty) runs once and is then removed.
  Future<void> createEffectSchedule(
    HueEffectScheduleDraft draft, {
    DateTime? now,
  }) async {
    final key = applicationKey;
    if (key == null) {
      throw const UnauthorizedException();
    }
    final at = now ?? DateTime.now();
    final token = at.microsecondsSinceEpoch.toRadixString(36);
    final once = draft.days.isEmpty;
    final action = '/api/$key/groups/${draft.groupId}/action';
    final startId = await _postSchedule({
      'name': _clipName(draft.name),
      'description': '${HueEffectSchedule.tag}$token:start',
      'command': {
        'address': action,
        'method': 'PUT',
        'body': {'scene': draft.sceneId},
      },
      'localtime': scheduleLocaltime(
        hour: draft.hour,
        minute: draft.minute,
        days: draft.days,
        now: at,
      ),
      'status': 'enabled',
      'autodelete': once,
    });
    if (!draft.stops) {
      return;
    }
    final stopHour = draft.stopHour!;
    final stopMinute = draft.stopMinute!;
    final nextDay =
        stopHour * 60 + stopMinute <= draft.hour * 60 + draft.minute;
    // Once: the next stop time after the start; weekly: the same days, or
    // the day after each when the stop is past midnight.
    var start = DateTime(at.year, at.month, at.day, draft.hour, draft.minute);
    if (!start.isAfter(at)) {
      start = start.add(const Duration(days: 1));
    }
    try {
      await _postSchedule({
        'name': _clipName(draft.name),
        'description': '${HueEffectSchedule.tag}$token:stop',
        'command': {
          'address': action,
          'method': 'PUT',
          'body': {'on': false},
        },
        'localtime': scheduleLocaltime(
          hour: stopHour,
          minute: stopMinute,
          days: stopDays(draft.days, nextDay: nextDay),
          now: once ? start : at,
        ),
        'status': 'enabled',
        'autodelete': once,
      });
    } on Object {
      // Half a schedule would turn the lights on and never off.
      await _deleteV1('/schedules/$startId');
      rethrow;
    }
  }

  /// The ok-to-wake lights LumiFX stored on the bridge.
  Future<List<HueOkToWake>> fetchOkToWake() async {
    final response = await _client.get(_v1('/schedules')).timeout(_timeout);
    final body = _v1Result(response);
    if (body is! Map) {
      return const [];
    }
    final parts = <String, Map<String, (String, Map<Object?, Object?>)>>{};
    for (final MapEntry(:key, :value) in body.entries) {
      final description = value is Map ? value['description'] : null;
      if (key is! String ||
          value is! Map ||
          description is! String ||
          !description.startsWith(HueEffectSchedule.tag)) {
        continue;
      }
      final words =
          description.substring(HueEffectSchedule.tag.length).split(':');
      if (words.length == 2 && words[1].startsWith('wake-')) {
        (parts[words[0]] ??= {})[words[1]] = (key, value);
      }
    }
    final lights = <HueOkToWake>[];
    for (final roles in parts.values) {
      final night = roles['wake-night'];
      final wake = roles['wake-green'];
      final off = roles['wake-off'];
      if (night == null || wake == null) {
        continue;
      }
      final nightAt = parseLocaltime('${night.$2['localtime'] ?? ''}');
      final wakeAt = parseLocaltime('${wake.$2['localtime'] ?? ''}');
      final offAt =
          off == null ? null : parseLocaltime('${off.$2['localtime'] ?? ''}');
      final command = wake.$2['command'];
      final address = command is Map ? command['address'] : null;
      final group = address is String
          ? RegExp(r'/groups/([A-Za-z0-9]+)/action$')
              .firstMatch(address)
              ?.group(1)
          : null;
      if (nightAt == null ||
          wakeAt == null ||
          wakeAt.days.isEmpty ||
          group == null) {
        continue;
      }
      final name = wake.$2['name'];
      lights.add(HueOkToWake(
        nightId: night.$1,
        wakeId: wake.$1,
        offId: offAt == null ? null : off!.$1,
        name: name is String ? name : '',
        groupId: group,
        nightHour: nightAt.hour,
        nightMinute: nightAt.minute,
        wakeHour: wakeAt.hour,
        wakeMinute: wakeAt.minute,
        offHour: offAt?.hour,
        offMinute: offAt?.minute,
        mornings: wakeAt.days,
        enabled: wake.$2['status'] == 'enabled',
      ));
    }
    return lights
      ..sort((a, b) => (a.wakeHour * 60 + a.wakeMinute)
          .compareTo(b.wakeHour * 60 + b.wakeMinute));
  }

  /// Stores an ok-to-wake light: the night colour from the evening before
  /// each chosen morning (or the same day, when it starts after
  /// midnight), green on those mornings, and the lights off later if
  /// asked. Nothing is left behind when a part is refused.
  Future<void> createOkToWake(
    HueOkToWakeDraft draft, {
    DateTime? now,
  }) async {
    final key = applicationKey;
    if (key == null) {
      throw const UnauthorizedException();
    }
    final at = now ?? DateTime.now();
    final token = at.microsecondsSinceEpoch.toRadixString(36);
    final action = '/api/$key/groups/${draft.groupId}/action';
    final nightAfterMidnight = draft.nightHour * 60 + draft.nightMinute <
        draft.wakeHour * 60 + draft.wakeMinute;
    final created = <String>[];
    Future<void> add(
      String role,
      Map<String, Object> body,
      int hour,
      int minute,
      List<int> days,
    ) async {
      created.add(await _postSchedule({
        'name': _clipName(draft.name),
        'description': '${HueEffectSchedule.tag}$token:$role',
        'command': {'address': action, 'method': 'PUT', 'body': body},
        'localtime': scheduleLocaltime(
          hour: hour,
          minute: minute,
          days: days,
          now: at,
        ),
        'status': 'enabled',
        'autodelete': false,
      }));
    }

    try {
      await add(
        'wake-night',
        {
          'on': true,
          'bri': HueOkToWakeDraft.nightBrightness,
          'xy': [HueOkToWakeDraft.nightXy.x, HueOkToWakeDraft.nightXy.y],
          'transitiontime': 600,
        },
        draft.nightHour,
        draft.nightMinute,
        nightAfterMidnight ? [...draft.mornings] : daysBefore(draft.mornings),
      );
      await add(
        'wake-green',
        {
          'on': true,
          'bri': HueOkToWakeDraft.wakeBrightness,
          'xy': [HueOkToWakeDraft.wakeXy.x, HueOkToWakeDraft.wakeXy.y],
          'transitiontime': 50,
        },
        draft.wakeHour,
        draft.wakeMinute,
        draft.mornings,
      );
      final offAfter = draft.offAfter;
      if (offAfter != null) {
        final minutes =
            draft.wakeHour * 60 + draft.wakeMinute + offAfter.inMinutes;
        await add(
          'wake-off',
          {'on': false, 'transitiontime': 100},
          minutes ~/ 60 % 24,
          minutes % 60,
          stopDays(draft.mornings, nextDay: minutes >= 24 * 60),
        );
      }
    } on Object {
      for (final id in created) {
        await _deleteV1('/schedules/$id').catchError((Object _) {});
      }
      rethrow;
    }
  }

  /// Pauses or resumes every part of [light].
  Future<void> setOkToWakeEnabled(HueOkToWake light, bool enabled) async {
    for (final id in light.scheduleIds) {
      final response = await _client
          .put(
            _v1('/schedules/$id'),
            headers: {'content-type': 'application/json'},
            body: jsonEncode({'status': enabled ? 'enabled' : 'disabled'}),
          )
          .timeout(_timeout);
      _v1Result(response);
    }
  }

  Future<void> deleteOkToWake(HueOkToWake light) async {
    for (final id in light.scheduleIds) {
      await _deleteV1('/schedules/$id');
    }
  }

  /// Pauses or resumes [schedule] (and its stop).
  Future<void> setEffectScheduleEnabled(
    HueEffectSchedule schedule,
    bool enabled,
  ) async {
    for (final id in [schedule.id, if (schedule.stopId case final s?) s]) {
      final response = await _client
          .put(
            _v1('/schedules/$id'),
            headers: {'content-type': 'application/json'},
            body: jsonEncode({'status': enabled ? 'enabled' : 'disabled'}),
          )
          .timeout(_timeout);
      _v1Result(response);
    }
  }

  /// Removes [schedule], its stop and the scene it recalls.
  Future<void> deleteEffectSchedule(HueEffectSchedule schedule) async {
    await _deleteV1('/schedules/${schedule.id}');
    final stopId = schedule.stopId;
    if (stopId != null) {
      await _deleteV1('/schedules/$stopId');
    }
    try {
      await _deleteV1('/scenes/${schedule.sceneId}');
    } on HueException {
      // Already deleted in the Hue app.
    }
  }

  Future<String> _postSchedule(Map<String, Object> body) async {
    final response = await _client
        .post(
          _v1('/schedules'),
          headers: {'content-type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(_timeout);
    final result = _v1Result(response);
    final first = result is List ? result.firstOrNull : null;
    final success = first is Map ? first['success'] : null;
    final id = success is Map ? success['id'] : null;
    if (id is! String) {
      throw const HueException('The bridge did not create the schedule');
    }
    return id;
  }

  Future<void> _deleteV1(String path) async {
    final response = await _client.delete(_v1(path)).timeout(_timeout);
    _v1Result(response);
  }

  Uri _v1(String path) {
    final key = applicationKey;
    if (key == null) {
      throw const UnauthorizedException();
    }
    return Uri.https(host, '/api/$key$path');
  }

  /// The older API answers 200 with a list of `success` and `error`
  /// entries.
  Object? _v1Result(http.Response response) {
    final body = _decode(response);
    if (body is List) {
      for (final item in body) {
        final error = item is Map ? item['error'] : null;
        if (error is Map) {
          if (error['type'] == 1) {
            throw const UnauthorizedException();
          }
          throw HueException('${error['description'] ?? 'Request failed'}');
        }
      }
    }
    return body;
  }

  /// The bridge's own wake-up script, as made by the Hue app.
  static const wakeUpScriptId = 'ff8957e3-2eb9-4699-a0c8-ad2cb3ede704';

  /// Which of the bridge's scripts are wake-up and go-to-sleep routines,
  /// found by name since only the wake-up id is known for certain.
  Future<Map<String, HueAutomationKind>> _automationScripts() async {
    final scripts = <String, HueAutomationKind>{
      wakeUpScriptId: HueAutomationKind.wakeUp,
    };
    for (final script in await _resources('behavior_script')) {
      final id = script['id'];
      final name = '${_map(script['metadata'])['name'] ?? ''}'.toLowerCase();
      if (id is! String) {
        continue;
      }
      if (name.contains('wake')) {
        scripts[id] = HueAutomationKind.wakeUp;
      } else if (name.contains('sleep')) {
        scripts[id] = HueAutomationKind.goToSleep;
      }
    }
    return scripts;
  }

  /// The wake-up and go-to-sleep routines on the bridge, LumiFX's and the
  /// Hue app's alike.
  Future<List<HueAutomation>> fetchAutomations() async {
    final scripts = await _automationScripts();
    return [
      for (final json in await _resources('behavior_instance'))
        if (HueAutomation.fromJson(json, scripts) case final automation?)
          automation,
    ];
  }

  /// Creates a routine and returns its id. Throws [HueException] when the
  /// bridge has no such script (very old firmware) or refuses it.
  Future<String> createAutomation(HueAutomationDraft draft) async {
    final scripts = await _automationScripts();
    final scriptId = scripts.entries
        .where((e) => e.value == draft.kind)
        .map((e) => e.key)
        .firstOrNull;
    if (scriptId == null) {
      throw const HueException('The bridge has no routine of this kind');
    }
    final response = await _client
        .post(
          Uri.https(host, '/clip/v2/resource/behavior_instance'),
          headers: {..._headers, 'content-type': 'application/json'},
          body: jsonEncode({
            'type': 'behavior_instance',
            'script_id': scriptId,
            'enabled': true,
            // The bridge refuses longer names.
            'metadata': {'name': _clipName(draft.name)},
            'configuration': draft.toConfiguration(),
          }),
        )
        .timeout(_timeout);
    final body = _decode(response);
    final created = body is Map ? _list(body['data']).firstOrNull : null;
    final id = created?['rid'];
    if (id is! String) {
      throw const HueException('The bridge did not create the routine');
    }
    return id;
  }

  Future<void> setAutomationEnabled(String id, bool enabled) =>
      _put('behavior_instance/$id', {'enabled': enabled});

  Future<void> deleteAutomation(String id) async {
    final response = await _client
        .delete(
          Uri.https(host, '/clip/v2/resource/behavior_instance/$id'),
          headers: _headers,
        )
        .timeout(_timeout);
    _decode(response);
  }

  /// Creates an entertainment area and returns its id.
  Future<String> createEntertainmentArea(
      HueEntertainmentAreaDraft draft) async {
    final response = await _client
        .post(
          Uri.https(host, '/clip/v2/resource/entertainment_configuration'),
          headers: {..._headers, 'content-type': 'application/json'},
          body: jsonEncode({
            'type': 'entertainment_configuration',
            ...draft.toJson(),
          }),
        )
        .timeout(_timeout);
    final body = _decode(response);
    final created = body is Map ? _list(body['data']).firstOrNull : null;
    final id = created?['rid'];
    if (id is! String) {
      throw const HueException('The bridge did not create the area');
    }
    return id;
  }

  Future<void> updateEntertainmentArea(
    String areaId,
    HueEntertainmentAreaDraft draft,
  ) =>
      _put('entertainment_configuration/$areaId', draft.toJson());

  Future<void> deleteEntertainmentArea(String areaId) async {
    final response = await _client
        .delete(
          Uri.https(
              host, '/clip/v2/resource/entertainment_configuration/$areaId'),
          headers: _headers,
        )
        .timeout(_timeout);
    _decode(response);
  }

  /// The id the bridge assigned to this application key, used as the PSK
  /// identity for Entertainment streaming.
  Future<String?> fetchApplicationId() async {
    final response = await _client
        .get(Uri.https(host, '/auth/v1'), headers: _headers)
        .timeout(_timeout);
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const UnauthorizedException();
    }
    return response.headers['hue-application-id'];
  }

  /// Whether the bridge still reports [areaId] as streaming: null when it
  /// cannot tell (missing area, no status field).
  Future<bool?> isEntertainmentActive(String areaId) async {
    final response = await _client
        .get(
          Uri.https(
              host, '/clip/v2/resource/entertainment_configuration/$areaId'),
          headers: _headers,
        )
        .timeout(_timeout);
    final body = _decode(response);
    final configuration = body is Map ? _list(body['data']).firstOrNull : null;
    final status = configuration?['status'];
    return status is String ? status == 'active' : null;
  }

  /// Reserves [areaId] for streaming. Fails if another app is streaming.
  Future<void> startEntertainment(String areaId) =>
      _put('entertainment_configuration/$areaId', const {'action': 'start'});

  Future<void> stopEntertainment(String areaId) =>
      _put('entertainment_configuration/$areaId', const {'action': 'stop'});

  Future<void> setLight(String lightId, HueLightCommand command) =>
      _put('light/$lightId', command.toJson());

  Future<void> setGroupedLight(
          String groupedLightId, HueLightCommand command) =>
      _put('grouped_light/$groupedLightId', command.toJson());

  Future<List<Map<String, Object?>>> _resources(String type) async {
    final response = await _client
        .get(Uri.https(host, '/clip/v2/resource/$type'), headers: _headers)
        .timeout(_timeout);
    final body = _decode(response);
    return body is Map ? _list(body['data']) : const [];
  }

  Future<void> _put(String path, Map<String, Object> body) async {
    final response = await _client
        .put(
          Uri.https(host, '/clip/v2/resource/$path'),
          headers: {..._headers, 'content-type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(_timeout);
    _decode(response);
  }

  Map<String, String> get _headers {
    final key = applicationKey;
    if (key == null) {
      throw const UnauthorizedException();
    }
    return {'hue-application-key': key};
  }

  Object? _decode(http.Response response) {
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const UnauthorizedException();
    }
    if (response.statusCode == 429) {
      throw const BridgeBusyException();
    }
    final Object? body;
    try {
      body = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw HueException('Unexpected response (${response.statusCode})',
          statusCode: response.statusCode);
    }
    if (response.statusCode >= 400) {
      final errors = body is Map ? _list(body['errors']) : const [];
      final description = errors.firstOrNull?['description'];
      throw HueException(
        '${description ?? 'Request failed'} (${response.statusCode})',
        statusCode: response.statusCode,
      );
    }
    return body;
  }
}

List<Map<String, Object?>> _noResources(Object _) => const [];

Map<String, Object?> _map(Object? value) =>
    value is Map ? value.cast<String, Object?>() : const {};

double _coordinate(Map<String, Object?> channel, String axis) =>
    (_map(channel['position'])[axis] as num?)?.toDouble() ?? 0;

List<Map<String, Object?>> _list(Object? value) => value is List
    ? [
        for (final item in value)
          if (item is Map) item.cast<String, Object?>()
      ]
    : const [];

double _round(double value, int digits) =>
    double.parse(value.toStringAsFixed(digits));
