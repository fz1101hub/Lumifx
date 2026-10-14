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
    this.entertainmentAreas = const [],
    this.entertainmentServices = const [],
  });

  final Map<String, HueLight> lights;
  final List<HueGroup> rooms;
  final List<HueGroup> zones;
  final List<HueEntertainmentArea> entertainmentAreas;

  /// Lights that can be added to an entertainment area.
  final List<HueEntertainmentService> entertainmentServices;

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
    );
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
      throw const HueException('The bridge is busy; try again in a moment.',
          statusCode: 429);
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
