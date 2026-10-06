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
  EntertainmentSession._(this._client, this.area, this._dtls);

  static Future<EntertainmentSession> open({
    required HueBridgeClient client,
    required HueCredentials credentials,
    required HueEntertainmentArea area,
    DatagramTransportFactory transportFactory = UdpDatagramTransport.connect,
  }) async {
    final clientKey = credentials.clientKey;
    if (clientKey == null || clientKey.length != 32) {
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
        psk: _hexDecode(clientKey),
      );
      return EntertainmentSession._(client, area, dtls);
    } on Object {
      await client.stopEntertainment(area.id).catchError((Object _) {});
      rethrow;
    }
  }

  final HueBridgeClient _client;
  final HueEntertainmentArea area;
  final DtlsPskClient _dtls;
  int _sequence = 0;
  bool _closed = false;

  /// Completes when the bridge ends the stream, e.g. because another app
  /// took over the area.
  Future<void> get done => _dtls.done;

  bool get isClosed => _closed || _dtls.isClosed;

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
    await _dtls.close();
    try {
      await _client.stopEntertainment(area.id);
    } on Object {
      // The bridge also stops the stream by itself after a timeout.
    }
  }

  static Uint8List _hexDecode(String hex) => Uint8List.fromList([
        for (var i = 0; i < hex.length; i += 2)
          int.parse(hex.substring(i, i + 2), radix: 16),
      ]);
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
