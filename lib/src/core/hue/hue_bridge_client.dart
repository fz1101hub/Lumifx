import 'dart:convert';

import 'package:http/http.dart' as http;

import 'hue_exceptions.dart';
import 'hue_models.dart';

/// Everything LumiFX reads from a bridge in one snapshot.
class HueHome {
  const HueHome({
    required this.lights,
    required this.rooms,
    required this.zones,
  });

  final Map<String, HueLight> lights;
  final List<HueGroup> rooms;
  final List<HueGroup> zones;

  List<HueGroup> get groups => [...rooms, ...zones];
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

  /// Reads the bridge's public configuration; works without pairing and is
  /// used to confirm that a manually entered address really is a bridge.
  Future<HueBridgeInfo> fetchInfo() async {
    final response =
        await _client.get(Uri.https(host, '/api/0/config')).timeout(_timeout);
    final body = _decode(response);
    if (body is! Map || body['bridgeid'] is! String) {
      throw const HueException('This device does not look like a Hue Bridge');
    }
    return HueBridgeInfo(
      id: (body['bridgeid'] as String).toLowerCase(),
      host: host,
      name: body['name'] as String?,
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
      _resources('light'),
      _resources('room'),
      _resources('zone'),
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
      );
    }

    return HueHome(
      lights: lights,
      rooms: [for (final json in results[1]) group(json, HueGroupKind.room)],
      zones: [for (final json in results[2]) group(json, HueGroupKind.zone)],
    );
  }

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
      throw const HueException('Bridge is busy, slow down');
    }
    final Object? body;
    try {
      body = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw HueException('Unexpected response (${response.statusCode})');
    }
    if (response.statusCode >= 400) {
      final errors = body is Map ? _list(body['errors']) : const [];
      final description = errors.firstOrNull?['description'];
      throw HueException(
          '${description ?? 'Request failed'} (${response.statusCode})');
    }
    return body;
  }
}

List<Map<String, Object?>> _list(Object? value) => value is List
    ? [
        for (final item in value)
          if (item is Map) item.cast<String, Object?>()
      ]
    : const [];
