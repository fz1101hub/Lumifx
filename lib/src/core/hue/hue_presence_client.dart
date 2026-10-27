part of 'hue_bridge_client.dart';

/// Leaving and coming home: each phone keeps a presence sensor of its own
/// on the bridge (older API), so the last one out can tell nobody else is
/// home. The Hue app's own geofence sensors count too.
extension HuePresence on HueBridgeClient {
  static const presenceModel = 'LumiFXPresence';

  Future<Object?> _sendV1(String method, String path, Object body) async {
    final request = http.Request(method, _v1(path))
      ..headers['content-type'] = 'application/json'
      ..body = jsonEncode(body);
    final streamed =
        await _client.send(request).timeout(HueBridgeClient._timeout);
    return _v1Result(await http.Response.fromStream(streamed));
  }

  /// Creates this phone's presence sensor; its id.
  Future<String> createPresenceSensor(String name, String uniqueId) async {
    final result = await _sendV1('POST', '/sensors', {
      'name': HueBridgeClient._clipName(name),
      'type': 'CLIPPresence',
      'modelid': presenceModel,
      'manufacturername': 'LumiFX',
      'swversion': '1.0',
      'uniqueid': uniqueId,
      'state': {'presence': true},
    });
    final first = result is List ? result.firstOrNull : null;
    final success = first is Map ? first['success'] : null;
    final id = success is Map ? success['id'] : null;
    if (id is! String) {
      throw const HueException('The bridge did not create the sensor');
    }
    return id;
  }

  Future<void> deletePresenceSensor(String id) async {
    try {
      await _deleteV1('/sensors/$id');
    } on HueException {
      // Gone already.
    }
  }

  Future<void> setPresence(String id, bool present) =>
      _sendV1('PUT', '/sensors/$id/state', {'presence': present});

  /// Whether another phone is home: another LumiFX presence sensor or a
  /// Hue app geofence saying so.
  Future<bool> someoneElseHome(String mine) async {
    final response =
        await _client.get(_v1('/sensors')).timeout(HueBridgeClient._timeout);
    final body = _v1Result(response);
    if (body is! Map) {
      return false;
    }
    for (final MapEntry(:key, :value) in body.entries) {
      if (key == mine || value is! Map) {
        continue;
      }
      final state = value['state'];
      final counts = value['type'] == 'Geofence' ||
          (value['type'] == 'CLIPPresence' &&
              value['modelid'] == presenceModel);
      if (counts && state is Map && state['presence'] == true) {
        return true;
      }
    }
    return false;
  }

  /// Whether the bridge's daylight sensor says the sun is down (false
  /// when it does not know).
  Future<bool> isDark() async {
    final response =
        await _client.get(_v1('/sensors')).timeout(HueBridgeClient._timeout);
    final body = _v1Result(response);
    if (body is! Map) {
      return false;
    }
    for (final value in body.values) {
      final state = value is Map ? value['state'] : null;
      if (value is Map &&
          value['type'] == 'Daylight' &&
          state is Map &&
          state['daylight'] is bool) {
        return state['daylight'] == false;
      }
    }
    return false;
  }

  /// Switches every light off (the bridge's group 0).
  Future<void> allOff() =>
      _sendV1('PUT', '/groups/0/action', {'on': false, 'transitiontime': 20});

  /// Lights [groupId] (v1) warm and welcoming.
  Future<void> welcomeHome(String groupId) => _sendV1(
      'PUT', '/groups/$groupId/action', {'on': true, 'bri': 180, 'ct': 366});
}
