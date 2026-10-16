import 'dart:convert';

import 'package:http/http.dart' as http;

import 'hue_exceptions.dart';
import 'hue_automations.dart';
import 'hue_models.dart';

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

  /// The longest scene name the bridge accepts.
  static const maxSceneNameLength = 32;

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
            'metadata': {
              'name': trimmed.length > maxSceneNameLength
                  ? trimmed.substring(0, maxSceneNameLength)
                  : trimmed,
            },
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
            'metadata': {'name': draft.name.trim()},
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
