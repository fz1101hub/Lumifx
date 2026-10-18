part of 'hue_bridge_client.dart';

/// Away mode, night paths and natural light: routines the bridge runs by
/// itself.
extension HueHouseRoutines on HueBridgeClient {
  /// The away modes LumiFX stored on the bridge.
  Future<List<HueAwayMode>> fetchAwayModes() async {
    final response =
        await _client.get(_v1('/schedules')).timeout(HueBridgeClient._timeout);
    final body = _v1Result(response);
    if (body is! Map) {
      return const [];
    }
    final byToken = <String, List<(String, String, Map<Object?, Object?>)>>{};
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
      if (words.length == 2 && words[1].startsWith('away-')) {
        (byToken[words[0]] ??= []).add((words[1], key, value));
      }
    }
    final modes = <HueAwayMode>[];
    for (final MapEntry(key: token, value: parts) in byToken.entries) {
      final ons = <(int, String, String)>[];
      final offs = <(int, String)>[];
      ({int hour, int minute, List<int> days})? first;
      ({int hour, int minute})? firstOff;
      var name = '';
      var enabled = true;
      for (final (role, id, value) in parts) {
        final at = parseRandomLocaltime('${value['localtime'] ?? ''}');
        final command = value['command'];
        final address = command is Map ? command['address'] : null;
        final group = address is String
            ? RegExp(r'/groups/([A-Za-z0-9]+)/action$')
                .firstMatch(address)
                ?.group(1)
            : null;
        if (at == null || group == null) {
          continue;
        }
        final minutes = at.hour * 60 + at.minute;
        if (role == 'away-on') {
          ons.add((minutes, id, group));
          if (first == null || minutes < first.hour * 60 + first.minute) {
            first = (hour: at.hour, minute: at.minute, days: at.days);
          }
          final label = value['name'];
          if (label is String) {
            name = label;
          }
          enabled = enabled && value['status'] == 'enabled';
        } else if (role == 'away-off') {
          offs.add((minutes, id));
          if (firstOff == null ||
              minutes < firstOff.hour * 60 + firstOff.minute) {
            firstOff = (hour: at.hour, minute: at.minute);
          }
        }
      }
      if (first == null || firstOff == null || ons.isEmpty) {
        continue;
      }
      ons.sort((a, b) => a.$1.compareTo(b.$1));
      modes.add(HueAwayMode(
        token: token,
        name: name,
        groupIds: [for (final (_, _, group) in ons) group],
        onHour: first.hour,
        onMinute: first.minute,
        offHour: firstOff.hour,
        offMinute: firstOff.minute,
        days: first.days,
        enabled: enabled,
        scheduleIds: [
          for (final (_, id, _) in ons) id,
          for (final (_, id) in offs) id,
        ],
      ));
    }
    return modes;
  }

  /// Stores an away mode: each room on at the start (one after the other,
  /// plus a random delay) and off at the end, on the chosen evenings.
  /// Nothing is left behind when a part is refused.
  Future<void> createAwayMode(HueAwayModeDraft draft, {DateTime? now}) async {
    final key = applicationKey;
    if (key == null) {
      throw const UnauthorizedException();
    }
    if (draft.groupIds.isEmpty || draft.days.isEmpty) {
      throw const HueException('Choose at least one room and one day');
    }
    final at = now ?? DateTime.now();
    final token = at.microsecondsSinceEpoch.toRadixString(36);
    final offPastMidnight = draft.offHour * 60 + draft.offMinute <=
        draft.onHour * 60 + draft.onMinute;
    final created = <String>[];
    try {
      for (final (i, group)
          in draft.groupIds.take(HueAwayModeDraft.maxRooms).indexed) {
        final action = '/api/$key/groups/$group/action';
        Future<void> add(String role, Map<String, Object> body, int minutes,
            List<int> days) async {
          created.add(await _postSchedule({
            'name': HueBridgeClient._clipName(draft.name),
            'description': '${HueEffectSchedule.tag}$token:$role',
            'command': {'address': action, 'method': 'PUT', 'body': body},
            'localtime': randomLocaltime(
              hour: minutes ~/ 60 % 24,
              minute: minutes % 60,
              days: days,
              now: at,
              randomMinutes: HueAwayModeDraft.randomMinutes,
            ),
            'status': 'enabled',
            'autodelete': false,
          }));
        }

        final stagger = i * HueAwayModeDraft.staggerMinutes;
        final on = draft.onHour * 60 + draft.onMinute + stagger;
        final off = draft.offHour * 60 + draft.offMinute + stagger;
        await add(
          'away-on',
          {
            'on': true,
            'bri': HueAwayModeDraft.brightness,
            'ct': HueAwayModeDraft.mirek,
            'transitiontime': 20,
          },
          on,
          on >= 24 * 60 ? stopDays(draft.days, nextDay: true) : draft.days,
        );
        // Past midnight once for the window itself and once more for the
        // stagger: both can add up, two days after the evening chosen.
        var offDays = draft.days;
        for (var shift = (offPastMidnight ? 1 : 0) + off ~/ (24 * 60);
            shift > 0;
            shift--) {
          offDays = stopDays(offDays, nextDay: true);
        }
        await add(
          'away-off',
          {'on': false, 'transitiontime': 20},
          off,
          offDays,
        );
      }
    } on Object {
      for (final id in created) {
        await _deleteV1('/schedules/$id').catchError((Object _) {});
      }
      rethrow;
    }
  }

  Future<void> setAwayModeEnabled(HueAwayMode mode, bool enabled) async {
    for (final id in mode.scheduleIds) {
      final response = await _client
          .put(
            _v1('/schedules/$id'),
            headers: {'content-type': 'application/json'},
            body: jsonEncode({'status': enabled ? 'enabled' : 'disabled'}),
          )
          .timeout(HueBridgeClient._timeout);
      _v1Result(response);
    }
  }

  Future<void> deleteAwayMode(HueAwayMode mode) async {
    for (final id in mode.scheduleIds) {
      await _deleteV1('/schedules/$id');
    }
  }

  /// The Hue motion sensors.
  Future<List<HueMotionSensor>> fetchMotionSensors() async {
    final response =
        await _client.get(_v1('/sensors')).timeout(HueBridgeClient._timeout);
    final body = _v1Result(response);
    if (body is! Map) {
      return const [];
    }
    return [
      for (final MapEntry(:key, :value) in body.entries)
        if (key is String &&
            value is Map &&
            value['type'] == 'ZLLPresence' &&
            value['name'] is String)
          HueMotionSensor(id: key, name: value['name']! as String),
    ]..sort((a, b) => a.name.compareTo(b.name));
  }

  /// The night paths LumiFX stored on the bridge.
  Future<List<HueNightPath>> fetchNightPaths() async {
    final response =
        await _client.get(_v1('/rules')).timeout(HueBridgeClient._timeout);
    final body = _v1Result(response);
    if (body is! Map) {
      return const [];
    }
    final pairs = <String, Map<String, (String, Map<Object?, Object?>)>>{};
    for (final MapEntry(:key, :value) in body.entries) {
      final name = value is Map ? value['name'] : null;
      if (key is! String ||
          value is! Map ||
          name is! String ||
          !name.startsWith(HueEffectSchedule.tag)) {
        continue;
      }
      final words = name.substring(HueEffectSchedule.tag.length).split(':');
      if (words.length == 2 && words[1].startsWith('path-')) {
        (pairs[words[0]] ??= {})[words[1]] = (key, value);
      }
    }
    final paths = <HueNightPath>[];
    for (final roles in pairs.values) {
      final on = roles['path-on'];
      final off = roles['path-off'];
      if (on == null || off == null) {
        continue;
      }
      String? sensor;
      String? window;
      for (final condition in _listOf(on.$2['conditions'])) {
        final address = condition['address'];
        if (address is! String) {
          continue;
        }
        sensor ??= RegExp(r'^/sensors/([A-Za-z0-9]+)/state/presence$')
            .firstMatch(address)
            ?.group(1);
        if (address == '/config/localtime' && condition['value'] is String) {
          window = condition['value']! as String;
        }
      }
      String? group;
      for (final action in _listOf(on.$2['actions'])) {
        final address = action['address'];
        if (address is String) {
          group ??= RegExp(r'^/groups/([A-Za-z0-9]+)/action$')
              .firstMatch(address)
              ?.group(1);
        }
      }
      var minutes = 5;
      for (final condition in _listOf(off.$2['conditions'])) {
        final value = condition['value'];
        if (condition['operator'] == 'ddx' && value is String) {
          final match = RegExp(r'^PT(\d\d):(\d\d):\d\d$').firstMatch(value);
          if (match != null) {
            minutes =
                int.parse(match.group(1)!) * 60 + int.parse(match.group(2)!);
          }
        }
      }
      final times = window == null
          ? null
          : RegExp(r'^T(\d\d):(\d\d):\d\d/T(\d\d):(\d\d):\d\d$')
              .firstMatch(window);
      if (sensor == null || group == null || times == null) {
        continue;
      }
      paths.add(HueNightPath(
        onRuleId: on.$1,
        offRuleId: off.$1,
        sensorId: sensor,
        groupId: group,
        fromHour: int.parse(times.group(1)!),
        fromMinute: int.parse(times.group(2)!),
        toHour: int.parse(times.group(3)!),
        toMinute: int.parse(times.group(4)!),
        minutes: minutes,
        enabled: on.$2['status'] == 'enabled',
      ));
    }
    return paths;
  }

  /// Stores a night path: two rules, one switching the room on (dim and
  /// warm) at the first motion inside the night, one switching it off
  /// when there has been no motion for [HueNightPathDraft.minutes].
  Future<void> createNightPath(HueNightPathDraft draft, {DateTime? now}) async {
    final token =
        (now ?? DateTime.now()).microsecondsSinceEpoch.toRadixString(36);
    String time(int minutes) =>
        'T${(minutes ~/ 60 % 24).toString().padLeft(2, '0')}:'
        '${(minutes % 60).toString().padLeft(2, '0')}:00';
    final from = draft.fromHour * 60 + draft.fromMinute;
    final to = draft.toHour * 60 + draft.toMinute;
    final presence = '/sensors/${draft.sensorId}/state/presence';
    final action = '/groups/${draft.groupId}/action';
    final onId = await _postRule({
      'name': '${HueEffectSchedule.tag}$token:path-on',
      'conditions': [
        {'address': presence, 'operator': 'eq', 'value': 'true'},
        {'address': presence, 'operator': 'dx'},
        {
          'address': '/config/localtime',
          'operator': 'in',
          'value': '${time(from)}/${time(to)}',
        },
      ],
      'actions': [
        {
          'address': action,
          'method': 'PUT',
          'body': {
            'on': true,
            'bri': HueNightPathDraft.brightness,
            'xy': [HueNightPathDraft.xy.x, HueNightPathDraft.xy.y],
            'transitiontime': 10,
          },
        },
      ],
    });
    final minutes = draft.minutes.clamp(1, 120);
    try {
      await _postRule({
        'name': '${HueEffectSchedule.tag}$token:path-off',
        'conditions': [
          {'address': presence, 'operator': 'eq', 'value': 'false'},
          {
            'address': presence,
            'operator': 'ddx',
            'value': 'PT${(minutes ~/ 60).toString().padLeft(2, '0')}:'
                '${(minutes % 60).toString().padLeft(2, '0')}:00',
          },
          {
            'address': '/config/localtime',
            'operator': 'in',
            // A little past the end, so a light switched on just before
            // the morning still goes off.
            'value': '${time(from)}/'
                '${time(to + minutes + HueNightPathDraft.offGraceMinutes)}',
          },
        ],
        'actions': [
          {
            'address': action,
            'method': 'PUT',
            'body': {'on': false, 'transitiontime': 50},
          },
        ],
      });
    } on Object {
      await _deleteV1('/rules/$onId').catchError((Object _) {});
      rethrow;
    }
  }

  Future<void> setNightPathEnabled(HueNightPath path, bool enabled) async {
    for (final id in path.ruleIds) {
      final response = await _client
          .put(
            _v1('/rules/$id'),
            headers: {'content-type': 'application/json'},
            body: jsonEncode({'status': enabled ? 'enabled' : 'disabled'}),
          )
          .timeout(HueBridgeClient._timeout);
      _v1Result(response);
    }
  }

  Future<void> deleteNightPath(HueNightPath path) async {
    for (final id in path.ruleIds) {
      await _deleteV1('/rules/$id');
    }
  }

  Future<String> _postRule(Map<String, Object> body) async {
    final response = await _client
        .post(
          _v1('/rules'),
          headers: {'content-type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(HueBridgeClient._timeout);
    final result = _v1Result(response);
    final first = result is List ? result.firstOrNull : null;
    final success = first is Map ? first['success'] : null;
    final id = success is Map ? success['id'] : null;
    if (id is! String) {
      throw const HueException('The bridge did not create the rule');
    }
    return id;
  }

  /// Natural light in [group]: one scene per part of the day, named with
  /// [slotNames], and a smart scene that moves between them. Returns its
  /// id. Lights get the whites they can show.
  Future<String> createNaturalLight({
    required String name,
    required HueGroup group,
    required List<HueLight> lights,
    required List<String> slotNames,
  }) async {
    final members = [
      for (final light in lights)
        if (group.lightIds.contains(light.id) && light.isDimmable) light,
    ];
    if (members.isEmpty) {
      throw const HueException('No dimmable lights in this room');
    }
    final scenes = <String>[];
    try {
      for (final (i, slot) in NaturalLightSlot.day.indexed) {
        final white = LightColor.fromMirek(slot.mirek);
        scenes.add(await createScene(
          name: slotNames[i],
          group: group,
          actions: {
            for (final light in members)
              light.id: HueLightCommand(
                on: true,
                brightness: slot.brightness,
                mirek: light.supportsColorTemperature
                    ? slot.mirek.clamp(light.mirekMin, light.mirekMax)
                    : null,
                xy: !light.supportsColorTemperature && light.supportsColor
                    ? white.toXy()
                    : null,
              ),
          },
        ));
      }
      final response = await _client
          .post(
            Uri.https(host, '/clip/v2/resource/smart_scene'),
            headers: {..._headers, 'content-type': 'application/json'},
            body: jsonEncode({
              'type': 'smart_scene',
              'metadata': {'name': HueBridgeClient._clipName(name)},
              'group': {'rid': group.id, 'rtype': group.kind.name},
              'week_timeslots': [
                {
                  'timeslots': [
                    for (final (i, slot) in NaturalLightSlot.day.indexed)
                      {
                        'start_time': {
                          'kind': 'time',
                          'time': {
                            'hour': slot.hour,
                            'minute': slot.minute,
                            'second': 0,
                          },
                        },
                        'target': {'rid': scenes[i], 'rtype': 'scene'},
                      },
                  ],
                  'recurrence': const [
                    'monday',
                    'tuesday',
                    'wednesday',
                    'thursday',
                    'friday',
                    'saturday',
                    'sunday',
                  ],
                },
              ],
            }),
          )
          .timeout(HueBridgeClient._timeout);
      final body = _decode(response);
      final created = body is Map ? _list(body['data']).firstOrNull : null;
      final id = created?['rid'];
      if (id is! String) {
        throw const HueException('The bridge did not create the smart scene');
      }
      return id;
    } on Object {
      for (final id in scenes) {
        await _deleteV2('scene/$id').catchError((Object _) {});
      }
      rethrow;
    }
  }

  /// The natural lights among [ids] (the ones LumiFX made) still on the
  /// bridge.
  Future<List<HueNaturalLight>> fetchNaturalLights(Set<String> ids) async {
    if (ids.isEmpty) {
      return const [];
    }
    final scenes = await _resources('smart_scene');
    return [
      for (final json in scenes)
        if (json['id'] case final String id when ids.contains(id))
          HueNaturalLight(
            id: id,
            name: '${_map(json['metadata'])['name'] ?? ''}',
            groupId: '${_map(json['group'])['rid'] ?? ''}',
            sceneIds: [
              for (final week in _list(json['week_timeslots']))
                for (final slot in _list(week['timeslots']))
                  if (_map(slot['target'])['rid'] case final String scene)
                    scene,
            ],
            active: json['state'] == 'active',
          ),
    ];
  }

  /// Starts or stops [light] in its room.
  Future<void> setNaturalLightActive(HueNaturalLight light, bool active) =>
      setSmartSceneActive(light.id, active: active);

  /// Starts or stops the smart scene [id].
  Future<void> setSmartSceneActive(String id, {required bool active}) =>
      _put('smart_scene/$id', {
        'recall': {'action': active ? 'activate' : 'deactivate'},
      });

  /// Removes the smart scene and its scenes.
  Future<void> deleteNaturalLight(HueNaturalLight light) async {
    await _deleteV2('smart_scene/${light.id}');
    for (final scene in light.sceneIds) {
      await _deleteV2('scene/$scene').catchError((Object _) {});
    }
  }

  Future<void> _deleteV2(String path) async {
    final response = await _client
        .delete(Uri.https(host, '/clip/v2/resource/$path'), headers: _headers)
        .timeout(HueBridgeClient._timeout);
    _decode(response);
  }
}

List<Map<Object?, Object?>> _listOf(Object? value) => value is List
    ? value.whereType<Map<Object?, Object?>>().toList()
    : const [];
