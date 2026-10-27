part of 'hue_bridge_client.dart';

/// Light reminders and the night switch-off: schedules the bridge runs by
/// itself, tagged `lumifx:<token>:<role>` in their description.
extension HueReminderRoutines on HueBridgeClient {
  /// The schedules LumiFX made with [roles], by token.
  Future<Map<String, List<(String, String, Map<Object?, Object?>)>>>
      _taggedSchedules(bool Function(String role) roles) async {
    final response =
        await _client.get(_v1('/schedules')).timeout(HueBridgeClient._timeout);
    final body = _v1Result(response);
    final byToken = <String, List<(String, String, Map<Object?, Object?>)>>{};
    if (body is! Map) {
      return byToken;
    }
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
      if (words.length >= 2 && roles(words[1])) {
        (byToken[words[0]] ??= []).add((words.skip(1).join(':'), key, value));
      }
    }
    return byToken;
  }

  static String? _groupOf(Map<Object?, Object?> schedule) {
    final command = schedule['command'];
    final address = command is Map ? command['address'] : null;
    return address is String
        ? RegExp(r'/groups/([A-Za-z0-9]+)/action$')
            .firstMatch(address)
            ?.group(1)
        : null;
  }

  /// The light reminders LumiFX stored on the bridge.
  Future<List<HueLightReminder>> fetchLightReminders() async {
    final byToken = await _taggedSchedules((role) => role.startsWith('remind'));
    final reminders = <HueLightReminder>[];
    for (final MapEntry(key: token, value: parts) in byToken.entries) {
      (String, String, Map<Object?, Object?>)? on;
      (String, String, Map<Object?, Object?>)? off;
      for (final part in parts) {
        if (part.$1.startsWith('remind-on')) {
          on = part;
        } else if (part.$1 == 'remind-off') {
          off = part;
        }
      }
      if (on == null) {
        continue;
      }
      final (role, id, value) = on;
      final at = parseLocaltime('${value['localtime'] ?? ''}');
      final group = _groupOf(value);
      final hex = role.split(':').elementAtOrNull(1);
      if (at == null || group == null || hex == null || hex.length != 6) {
        continue;
      }
      int? offAfter;
      if (off != null) {
        final end = parseLocaltime('${off.$3['localtime'] ?? ''}');
        if (end != null) {
          offAfter = (end.hour * 60 + end.minute - at.hour * 60 - at.minute) %
              (24 * 60);
        }
      }
      reminders.add(HueLightReminder(
        token: token,
        name: '${value['name'] ?? ''}',
        groupId: group,
        hour: at.hour,
        minute: at.minute,
        days: at.days,
        color: '#${hex.toUpperCase()}',
        offAfterMinutes: offAfter,
        enabled: value['status'] == 'enabled',
        scheduleIds: [id, if (off != null) off.$2],
      ));
    }
    reminders.sort(
        (a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute));
    return reminders;
  }

  /// Stores a reminder: the room takes the colour (breathing in it for a
  /// few seconds) at the time on the days chosen, and switches off
  /// [HueLightReminderDraft.offAfterMinutes] later if set. Nothing is
  /// left behind when a part is refused.
  Future<void> createLightReminder(HueLightReminderDraft draft,
      {DateTime? now}) async {
    if (draft.days.isEmpty) {
      throw const HueException('Choose at least one day');
    }
    final at = now ?? DateTime.now();
    final token = at.microsecondsSinceEpoch.toRadixString(36);
    final hex = draft.color.replaceFirst('#', '').toUpperCase();
    final xy = LightColor.fromHex(draft.color).toXy();
    final action = '/api/$applicationKey/groups/${draft.groupId}/action';
    final created = <String>[];
    try {
      created.add(await _postSchedule({
        'name': HueBridgeClient._clipName(draft.name),
        'description': '${HueEffectSchedule.tag}$token:remind-on:$hex',
        'command': {
          'address': action,
          'method': 'PUT',
          'body': {
            'on': true,
            'bri': HueLightReminderDraft.brightness,
            'xy': [
              double.parse(xy.x.toStringAsFixed(4)),
              double.parse(xy.y.toStringAsFixed(4)),
            ],
            'alert': 'lselect',
          },
        },
        'localtime': scheduleLocaltime(
            hour: draft.hour, minute: draft.minute, days: draft.days, now: at),
        'status': 'enabled',
        'autodelete': false,
      }));
      if (draft.offAfterMinutes case final minutes?) {
        final end = draft.hour * 60 + draft.minute + minutes;
        created.add(await _postSchedule({
          'name': HueBridgeClient._clipName(draft.name),
          'description': '${HueEffectSchedule.tag}$token:remind-off',
          'command': {
            'address': action,
            'method': 'PUT',
            'body': {'on': false, 'transitiontime': 20},
          },
          'localtime': scheduleLocaltime(
            hour: end ~/ 60 % 24,
            minute: end % 60,
            days: stopDays(draft.days, nextDay: end >= 24 * 60),
            now: at,
          ),
          'status': 'enabled',
          'autodelete': false,
        }));
      }
    } on Object {
      for (final id in created) {
        await _deleteV1('/schedules/$id').catchError((Object _) {});
      }
      rethrow;
    }
  }

  /// The night switch-off LumiFX stored on the bridge, if any.
  Future<HueNightOff?> fetchNightOff() async {
    final byToken = await _taggedSchedules((role) => role == 'nightoff');
    for (final MapEntry(key: token, value: parts) in byToken.entries) {
      final groups = <String>[];
      final ids = <String>[];
      ({int hour, int minute, List<int> days})? at;
      var fade = 0;
      var enabled = true;
      for (final (_, id, value) in parts) {
        final time = parseLocaltime('${value['localtime'] ?? ''}');
        final group = _groupOf(value);
        if (time == null || group == null) {
          continue;
        }
        at ??= time;
        groups.add(group);
        ids.add(id);
        enabled = enabled && value['status'] == 'enabled';
        final command = value['command'];
        final body = command is Map ? command['body'] : null;
        final transition = body is Map ? body['transitiontime'] : null;
        if (transition is int) {
          fade = (transition / 600).round();
        }
      }
      if (at != null && groups.isNotEmpty) {
        return HueNightOff(
          token: token,
          groupIds: groups,
          hour: at.hour,
          minute: at.minute,
          fadeMinutes: fade,
          enabled: enabled,
          scheduleIds: ids,
        );
      }
    }
    return null;
  }

  /// Stores the night switch-off, replacing the one there was: every
  /// night each room chosen fades out over the minutes set.
  Future<void> setNightOff(HueNightOffDraft draft,
      {HueNightOff? replacing, DateTime? now}) async {
    if (draft.groupIds.isEmpty) {
      throw const HueException('Choose at least one room');
    }
    final at = now ?? DateTime.now();
    final token = at.microsecondsSinceEpoch.toRadixString(36);
    final created = <String>[];
    try {
      for (final group in draft.groupIds.take(HueNightOffDraft.maxRooms)) {
        created.add(await _postSchedule({
          'name': 'LumiFX night off',
          'description': '${HueEffectSchedule.tag}$token:nightoff',
          'command': {
            'address': '/api/$applicationKey/groups/$group/action',
            'method': 'PUT',
            'body': {
              'on': false,
              // In tenths of a second.
              'transitiontime': draft.fadeMinutes * 600,
            },
          },
          'localtime': scheduleLocaltime(
            hour: draft.hour,
            minute: draft.minute,
            days: const [0, 1, 2, 3, 4, 5, 6],
            now: at,
          ),
          'status': 'enabled',
          'autodelete': false,
        }));
      }
    } on Object {
      for (final id in created) {
        await _deleteV1('/schedules/$id').catchError((Object _) {});
      }
      rethrow;
    }
    if (replacing != null) {
      await deleteSchedules(replacing.scheduleIds);
    }
  }

  /// The tooth fairy's visit: at the next [hour]:[minute] the room
  /// glows soft pink and violet, breathing a little, and goes off a
  /// quarter of an hour later. One-time schedules, deleted by the bridge
  /// once done.
  Future<void> createFairyVisit({
    required String groupId,
    required int hour,
    required int minute,
    DateTime? now,
  }) async {
    final at = now ?? DateTime.now();
    final token = at.microsecondsSinceEpoch.toRadixString(36);
    final xy = LightColor.fromHex('#E0A0FF').toXy();
    final action = '/api/$applicationKey/groups/$groupId/action';
    final end = hour * 60 + minute + 15;
    final created = <String>[];
    try {
      created.add(await _postSchedule({
        'name': 'LumiFX tooth fairy',
        'description': '${HueEffectSchedule.tag}$token:fairy-on',
        'command': {
          'address': action,
          'method': 'PUT',
          'body': {
            'on': true,
            'bri': 60,
            'xy': [
              double.parse(xy.x.toStringAsFixed(4)),
              double.parse(xy.y.toStringAsFixed(4)),
            ],
            'alert': 'lselect',
            'transitiontime': 100,
          },
        },
        'localtime': scheduleLocaltime(
            hour: hour, minute: minute, days: const [], now: at),
        'status': 'enabled',
        'autodelete': true,
      }));
      created.add(await _postSchedule({
        'name': 'LumiFX tooth fairy',
        'description': '${HueEffectSchedule.tag}$token:fairy-off',
        'command': {
          'address': action,
          'method': 'PUT',
          'body': {'on': false, 'transitiontime': 300},
        },
        'localtime': scheduleLocaltime(
            hour: end ~/ 60 % 24, minute: end % 60, days: const [], now: at),
        'status': 'enabled',
        'autodelete': true,
      }));
    } on Object {
      for (final id in created) {
        await _deleteV1('/schedules/$id').catchError((Object _) {});
      }
      rethrow;
    }
  }

  /// Cancels the tooth fairy's visits not made yet.
  Future<void> cancelFairyVisits() async {
    final byToken = await _taggedSchedules((role) => role.startsWith('fairy'));
    await deleteSchedules([
      for (final parts in byToken.values)
        for (final (_, id, _) in parts) id,
    ]);
  }

  /// The times of the lights before appointments now on the bridge.
  Future<List<String>> _calendarSchedules() async {
    final byToken = await _taggedSchedules((role) => role == 'cal');
    return [
      for (final parts in byToken.values)
        for (final (_, id, _) in parts) id,
    ];
  }

  /// Replaces the lights before appointments: at each of [times] (within
  /// the next day) the room [groupId] glows [color] softly and breathes.
  /// Only the times reach the bridge, never what the appointment is.
  /// Returns how many were set.
  Future<int> syncCalendarLights({
    required List<DateTime> times,
    required String groupId,
    required String color,
    DateTime? now,
  }) async {
    final at = now ?? DateTime.now();
    await deleteSchedules(await _calendarSchedules());
    final xy = LightColor.fromHex(color).toXy();
    final action = '/api/$applicationKey/groups/$groupId/action';
    var made = 0;
    for (final time in times) {
      if (!time.isAfter(at) || time.difference(at) > const Duration(days: 1)) {
        continue;
      }
      final token =
          '${at.microsecondsSinceEpoch.toRadixString(36)}${made.toString()}';
      await _postSchedule({
        'name': 'LumiFX calendar',
        'description': '${HueEffectSchedule.tag}$token:cal',
        'command': {
          'address': action,
          'method': 'PUT',
          'body': {
            'on': true,
            'bri': 140,
            'xy': [
              double.parse(xy.x.toStringAsFixed(4)),
              double.parse(xy.y.toStringAsFixed(4)),
            ],
            'alert': 'lselect',
            'transitiontime': 30,
          },
        },
        'localtime': scheduleLocaltime(
            hour: time.hour, minute: time.minute, days: const [], now: at),
        'status': 'enabled',
        'autodelete': true,
      });
      made++;
    }
    return made;
  }

  /// Takes away every light before an appointment.
  Future<void> clearCalendarLights() async =>
      deleteSchedules(await _calendarSchedules());

  /// Switches a reminder or the night switch-off on or off.
  Future<void> setSchedulesEnabled(List<String> ids, bool enabled) async {
    for (final id in ids) {
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

  /// Deletes a reminder or the night switch-off; schedules already gone
  /// (deleted in the Hue app) are skipped.
  Future<void> deleteSchedules(List<String> ids) async {
    for (final id in ids) {
      try {
        await _deleteV1('/schedules/$id');
      } on HueException {
        // Already gone.
      }
    }
  }
}
