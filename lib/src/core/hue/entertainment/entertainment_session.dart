import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import '../../effects/engine/light_frame.dart';
import '../../effects/engine/light_output.dart';
import '../hue_bridge_client.dart';
import '../hue_exceptions.dart';
import '../hue_models.dart';
import 'dtls/dtls_client.dart';
import 'hue_stream_message.dart';

/// UDP port of the Hue Entertainment DTLS server.
const hueEntertainmentPort = 2100;

typedef DatagramTransportFactory = Future<DatagramTransport> Function(
  String host,
  int port,
);

/// A live streaming connection to one entertainment area.
///
/// Opening it reserves the area on the bridge (`action: start`) and performs
/// the DTLS handshake; closing it releases the area. While open, the bridge
/// ignores other control of those lights, and stops the stream on its own if
/// it receives nothing for about 10 seconds.
class EntertainmentSession {
  EntertainmentSession._(
    this._client,
    this.area,
    this._dtls, {
    required Duration statusInterval,
  }) {
    _done.future.ignore();
    unawaited(_dtls.done.then(
      (_) => _end(null),
      onError: (Object error) => _end(error),
    ));
    // We never read application data, so a bridge that silently drops the
    // stream (another app took the area, a reboot) would go unnoticed.
    // Its REST status is the only liveness signal.
    if (statusInterval > Duration.zero) {
      _statusTimer = Timer.periodic(statusInterval, (_) => _checkStatus());
    }
  }

  static Future<EntertainmentSession> open({
    required HueBridgeClient client,
    required HueCredentials credentials,
    required HueEntertainmentArea area,
    DatagramTransportFactory transportFactory = UdpDatagramTransport.connect,
    Duration statusInterval = const Duration(seconds: 5),
  }) async {
    final clientKey = credentials.clientKey;
    final psk = clientKey == null ? null : _hexDecode(clientKey);
    if (psk == null || psk.length != 16) {
      throw const HueException(
          'Streaming needs a newer pairing. Forget the bridge and pair again.');
    }
    if (area.channels.isEmpty) {
      throw const HueException('This entertainment area has no lights.');
    }

    final identity =
        await client.fetchApplicationId() ?? credentials.applicationKey;
    await client.startEntertainment(area.id);
    try {
      final dtls = await DtlsPskClient.connect(
        transport: await transportFactory(
            credentials.bridge.host, hueEntertainmentPort),
        identity: utf8.encode(identity),
        psk: psk,
      );
      return EntertainmentSession._(client, area, dtls,
          statusInterval: statusInterval);
    } on Object {
      await client.stopEntertainment(area.id).catchError((Object _) {});
      rethrow;
    }
  }

  final HueBridgeClient _client;
  final HueEntertainmentArea area;
  final DtlsPskClient _dtls;
  final _done = Completer<void>();
  Timer? _statusTimer;
  bool _checkingStatus = false;
  int _sequence = 0;
  bool _closed = false;

  /// Completes when the stream ends: normally after [close] or a
  /// close_notify, with an error when the bridge dropped it (another app
  /// took the area, a reboot) or the connection was lost.
  Future<void> get done => _done.future;

  bool get isClosed => _closed || _dtls.isClosed;

  Future<void> _checkStatus() async {
    if (_closed || _checkingStatus) {
      return;
    }
    _checkingStatus = true;
    try {
      final active = await _client.isEntertainmentActive(area.id);
      if (active == false && !_closed) {
        _end(const HueException(
            'The bridge stopped the stream (another app may have taken over '
            'the area).'));
      }
    } on Object {
      // A failed status read says nothing about the stream.
    } finally {
      _checkingStatus = false;
    }
  }

  void _end(Object? error) {
    _statusTimer?.cancel();
    if (_done.isCompleted) {
      return;
    }
    if (error == null || _closed) {
      _done.complete();
    } else {
      _done.completeError(error);
    }
  }

  /// Sends one state for every given channel id.
  void send(Map<int, LightFrame> channels) {
    if (isClosed) {
      return;
    }
    final entries = channels.entries.toList();
    for (var i = 0; i < entries.length; i += hueStreamMaxChannels) {
      final end = i + hueStreamMaxChannels;
      _dtls.send(encodeHueStreamMessage(
        areaId: area.id,
        channels: Map.fromEntries(
            entries.sublist(i, end < entries.length ? end : entries.length)),
        sequence: _sequence++,
      ));
    }
  }

  Future<void> close() async {
    if (_closed) {
      return;
    }
    _closed = true;
    _statusTimer?.cancel();
    await _dtls.close();
    _end(null);
    try {
      await _client.stopEntertainment(area.id);
    } on Object {
      // The bridge also stops the stream by itself after a timeout.
    }
  }

  /// Decodes a hex string, or returns null when it is not one.
  static Uint8List? _hexDecode(String hex) {
    if (hex.length.isOdd || !RegExp(r'^[0-9a-fA-F]+$').hasMatch(hex)) {
      return null;
    }
    return Uint8List.fromList([
      for (var i = 0; i < hex.length; i += 2)
        int.parse(hex.substring(i, i + 2), radix: 16),
    ]);
  }
}

/// Streams effect frames to an entertainment area.
///
/// Light ids given to the player are channel ids as strings (see
/// [entertainmentSlotIds]). Every update is sent immediately; while playback
/// is paused the last state is repeated so the bridge keeps the stream open.
class EntertainmentLightOutput implements LightOutput {
  EntertainmentLightOutput(
    this.session, {
    Duration keepAlive = const Duration(milliseconds: 500),
  }) {
    _keepAlive = Timer.periodic(keepAlive, (_) {
      final last = _last;
      if (last != null && DateTime.now().difference(_lastSentAt) >= keepAlive) {
        _send(last);
      }
    });
  }

  final EntertainmentSession session;
  late final Timer _keepAlive;
  Map<int, LightFrame>? _last;
  DateTime _lastSentAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void update(Map<String, LightFrame> frames, Duration tick) {
    _send({
      for (final entry in frames.entries) int.parse(entry.key): entry.value,
    });
  }

  void _send(Map<int, LightFrame> channels) {
    _last = channels;
    _lastSentAt = DateTime.now();
    session.send(channels);
  }

  @override
  Future<void> close() async {
    _keepAlive.cancel();
    await session.close();
  }
}

/// Player light ids for an area: its channel ids, ordered through space.
List<String> entertainmentSlotIds(HueEntertainmentArea area) =>
    [for (final channel in area.spatialChannels) '${channel.id}'];
