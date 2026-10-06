import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:pointycastle/api.dart';
import 'package:pointycastle/block/aes.dart';
import 'package:pointycastle/block/modes/gcm.dart';

import 'dtls_messages.dart';
import 'tls_prf.dart';

class DtlsException implements Exception {
  const DtlsException(this.message);

  final String message;

  @override
  String toString() => 'DtlsException: $message';
}

/// A connected datagram channel to one peer.
abstract interface class DatagramTransport {
  Stream<Uint8List> get incoming;

  void send(Uint8List datagram);

  Future<void> close();
}

class UdpDatagramTransport implements DatagramTransport {
  UdpDatagramTransport._(this._socket, this._peer, this._port) {
    _socket.listen((event) {
      if (event != RawSocketEvent.read) {
        return;
      }
      final datagram = _socket.receive();
      if (datagram != null &&
          datagram.address == _peer &&
          datagram.port == _port) {
        _incoming.add(datagram.data);
      }
    }, onDone: _incoming.close);
  }

  static Future<UdpDatagramTransport> connect(String host, int port) async {
    final address = InternetAddress.tryParse(host) ??
        (await InternetAddress.lookup(host)).first;
    final socket = await RawDatagramSocket.bind(
      address.type == InternetAddressType.IPv6
          ? InternetAddress.anyIPv6
          : InternetAddress.anyIPv4,
      0,
    );
    return UdpDatagramTransport._(socket, address, port);
  }

  final RawDatagramSocket _socket;
  final InternetAddress _peer;
  final int _port;
  final _incoming = StreamController<Uint8List>();

  @override
  Stream<Uint8List> get incoming => _incoming.stream;

  @override
  void send(Uint8List datagram) => _socket.send(datagram, _peer, _port);

  @override
  Future<void> close() async => _socket.close();
}

/// Minimal DTLS 1.2 client for pre-shared-key connections.
///
/// Supports exactly what Hue Entertainment needs: one cipher suite
/// (TLS_PSK_WITH_AES_128_GCM_SHA256), cookie exchange, flight
/// retransmission, fragment reassembly, and sending application data. The
/// server is authenticated by verifying its Finished message, which only a
/// peer that knows the PSK can produce.
class DtlsPskClient {
  DtlsPskClient._(
    this._transport,
    this._subscription,
    this._writeCipher,
    this._readCipher,
  ) {
    _subscription.onData(_onDatagram);
    _subscription
        .onDone(() => _finish(const DtlsException('Transport closed')));
  }

  /// Performs the handshake over [transport]. On failure the transport is
  /// closed and a [DtlsException] (or [TimeoutException]) is thrown.
  static Future<DtlsPskClient> connect({
    required DatagramTransport transport,
    required List<int> identity,
    required List<int> psk,
    Duration timeout = const Duration(seconds: 10),
    Duration retransmitInterval = const Duration(milliseconds: 750),
    Random? random,
  }) async {
    final handshake = _Handshake(
      transport: transport,
      identity: identity,
      psk: psk,
      random: random ?? Random.secure(),
    );
    try {
      return await handshake.run(timeout, retransmitInterval);
    } on Object {
      await handshake.dispose();
      await transport.close();
      rethrow;
    }
  }

  final DatagramTransport _transport;
  final StreamSubscription<Uint8List> _subscription;
  final _GcmCipher _writeCipher;
  final _GcmCipher _readCipher;
  final _done = Completer<void>();
  int _writeSequence = 1; // 0 was used by our Finished.

  bool get isClosed => _done.isCompleted;

  /// Completes when the connection ends; with an error if the peer sent a
  /// fatal alert.
  Future<void> get done => _done.future;

  void send(List<int> data) {
    if (isClosed) {
      throw const DtlsException('Connection closed');
    }
    _transport.send(_record(ContentType.applicationData, data));
  }

  Future<void> close() async {
    if (!isClosed) {
      // close_notify, warning level.
      _transport.send(_record(ContentType.alert, const [1, 0]));
      _finish(null);
    }
    await _subscription.cancel();
    await _transport.close();
  }

  Uint8List _record(int type, List<int> plaintext) {
    final sequence = _writeSequence++;
    return DtlsRecord(
      type: type,
      epoch: 1,
      sequence: sequence,
      fragment:
          _writeCipher.seal(1, sequence, type, Uint8List.fromList(plaintext)),
    ).encode();
  }

  void _onDatagram(Uint8List datagram) {
    for (final record in DtlsRecord.parseDatagram(datagram)) {
      if (record.epoch != 1 || record.type != ContentType.alert) {
        continue;
      }
      final alert = _readCipher.open(record);
      if (alert != null && alert.length == 2) {
        _finish(alert[1] == 0
            ? null
            : DtlsException('Peer sent alert ${alert[1]}'));
      }
    }
  }

  void _finish(DtlsException? error) {
    if (_done.isCompleted) {
      return;
    }
    if (error == null) {
      _done.complete();
    } else {
      _done.completeError(error);
    }
  }
}

enum _State { awaitingServerHello, awaitingServerHelloDone, awaitingFinished }

class _Handshake {
  _Handshake({
    required this.transport,
    required this.identity,
    required this.psk,
    required Random random,
  }) : clientRandom = Uint8List.fromList(
          List<int>.generate(32, (_) => random.nextInt(256)),
        );

  final DatagramTransport transport;
  final List<int> identity;
  final List<int> psk;
  final Uint8List clientRandom;

  final _completer = Completer<DtlsPskClient>();
  final _reassembler = HandshakeReassembler();
  final _pending = <int, HandshakeMessage>{};
  StreamSubscription<Uint8List>? _subscription;
  Timer? _retransmitTimer;

  _State _state = _State.awaitingServerHello;
  BytesBuilder _transcript = BytesBuilder();
  int _epoch0Sequence = 0;
  int _messageSeq = 0;
  int? _nextServerSeq;
  Uint8List? _serverRandom;
  _GcmCipher? _writeCipher;
  _GcmCipher? _readCipher;
  Uint8List? _expectedServerVerifyData;

  /// Rebuilds the current flight; records get fresh sequence numbers on
  /// every retransmission.
  Uint8List Function()? _flight;

  Future<DtlsPskClient> run(Duration timeout, Duration retransmitInterval) {
    _subscription = transport.incoming.listen(
      _onDatagram,
      onDone: () => _fail('Transport closed during handshake'),
    );
    _sendClientHello(Uint8List(0));
    _retransmitTimer = Timer.periodic(retransmitInterval, (_) => _sendFlight());
    return _completer.future.timeout(
      timeout,
      onTimeout: () => throw const DtlsException('Handshake timed out'),
    );
  }

  Future<void> dispose() async {
    _retransmitTimer?.cancel();
    await _subscription?.cancel();
  }

  void _sendFlight() {
    if (!_completer.isCompleted && _flight != null) {
      transport.send(_flight!());
    }
  }

  Uint8List _plainRecord(int type, List<int> fragment) => DtlsRecord(
        type: type,
        epoch: 0,
        sequence: _epoch0Sequence++,
        fragment: Uint8List.fromList(fragment),
      ).encode();

  void _sendClientHello(Uint8List cookie) {
    final body = (ByteWriter()
          ..bytes(dtls12)
          ..bytes(clientRandom)
          ..vector8(const []) // session id
          ..vector8(cookie)
          ..vector16((ByteWriter()
                ..u16(pskAes128GcmSha256)
                ..u16(emptyRenegotiationInfoScsv))
              .toBytes())
          ..vector8(const [0])) // null compression
        .toBytes();
    final message =
        HandshakeMessage(HandshakeType.clientHello, _messageSeq++, body)
            .encode();
    // The transcript starts at the ClientHello the server answers with
    // ServerHello; earlier cookie-less attempts are excluded (RFC 6347 §4.2.6).
    _transcript = BytesBuilder()..add(message);
    _flight = () => _plainRecord(ContentType.handshake, message);
    _sendFlight();
  }

  void _onDatagram(Uint8List datagram) {
    try {
      for (final record in DtlsRecord.parseDatagram(datagram)) {
        _onRecord(record);
      }
    } on DtlsException catch (error) {
      _fail(error.message);
    } on FormatException {
      // Malformed records are dropped silently, per DTLS.
    }
  }

  void _onRecord(DtlsRecord record) {
    Uint8List fragment = record.fragment;
    if (record.epoch == 1) {
      final opened = _readCipher?.open(record);
      if (opened == null) {
        return;
      }
      fragment = opened;
    } else if (record.epoch != 0) {
      return;
    }

    switch (record.type) {
      case ContentType.alert:
        if (fragment.length == 2) {
          throw DtlsException(
              'Handshake rejected by the bridge (alert ${fragment[1]})');
        }
      case ContentType.handshake:
        for (final message in _reassembler.add(fragment)) {
          _onHandshakeMessage(message);
        }
      case ContentType.changeCipherSpec:
        // Implied by an authenticated epoch-1 Finished; nothing to do.
        break;
    }
  }

  void _onHandshakeMessage(HandshakeMessage message) {
    if (message.type == HandshakeType.helloVerifyRequest) {
      if (_state == _State.awaitingServerHello) {
        final reader = ByteReader(message.body)..skip(2);
        _sendClientHello(Uint8List.fromList(reader.vector8()));
      }
      return;
    }
    if (message.type == HandshakeType.serverHello) {
      if (_state != _State.awaitingServerHello) {
        return; // retransmitted
      }
      _nextServerSeq = message.messageSeq;
    }
    final next = _nextServerSeq;
    if (next == null || message.messageSeq > next) {
      _pending[message.messageSeq] = message;
      return;
    }
    if (message.messageSeq < next) {
      return; // retransmitted
    }
    _pending[message.messageSeq] = message;
    while (_pending.containsKey(_nextServerSeq)) {
      final current = _pending.remove(_nextServerSeq)!;
      _nextServerSeq = _nextServerSeq! + 1;
      _process(current);
    }
  }

  void _process(HandshakeMessage message) {
    switch ((_state, message.type)) {
      case (_State.awaitingServerHello, HandshakeType.serverHello):
        _onServerHello(message);
      case (_State.awaitingServerHelloDone, HandshakeType.serverKeyExchange):
        // Carries only an optional PSK identity hint, which Hue does not use.
        _transcript.add(message.encode());
      case (_State.awaitingServerHelloDone, HandshakeType.serverHelloDone):
        _transcript.add(message.encode());
        _sendKeyExchangeAndFinished();
      case (_State.awaitingFinished, HandshakeType.finished):
        _onServerFinished(message);
      default:
        throw DtlsException('Unexpected handshake message ${message.type}');
    }
  }

  void _onServerHello(HandshakeMessage message) {
    final reader = ByteReader(message.body);
    final version = reader.u16();
    _serverRandom = Uint8List.fromList(reader.bytes(32));
    reader.vector8(); // session id
    final suite = reader.u16();
    final compression = reader.u8();
    if (version != 0xFEFD) {
      throw const DtlsException('Bridge did not agree to DTLS 1.2');
    }
    if (suite != pskAes128GcmSha256 || compression != 0) {
      throw const DtlsException('Bridge chose an unsupported cipher suite');
    }
    _transcript.add(message.encode());
    _state = _State.awaitingServerHelloDone;
  }

  void _sendKeyExchangeAndFinished() {
    final serverRandom = _serverRandom!;
    final master = tlsPrf(
      pskPreMasterSecret(psk),
      'master secret',
      [...clientRandom, ...serverRandom],
      48,
    );
    final keys =
        tlsPrf(master, 'key expansion', [...serverRandom, ...clientRandom], 40);
    final writeCipher = _writeCipher = _GcmCipher(
      Uint8List.sublistView(keys, 0, 16),
      Uint8List.sublistView(keys, 32, 36),
    );
    _readCipher = _GcmCipher(
      Uint8List.sublistView(keys, 16, 32),
      Uint8List.sublistView(keys, 36, 40),
    );

    final keyExchange = HandshakeMessage(
      HandshakeType.clientKeyExchange,
      _messageSeq++,
      (ByteWriter()..vector16(identity)).toBytes(),
    ).encode();
    _transcript.add(keyExchange);

    final verifyData = tlsPrf(
      master,
      'client finished',
      sha256.convert(_transcript.toBytes()).bytes,
      12,
    );
    final finished =
        HandshakeMessage(HandshakeType.finished, _messageSeq++, verifyData)
            .encode();
    _transcript.add(finished);
    _expectedServerVerifyData = tlsPrf(
      master,
      'server finished',
      sha256.convert(_transcript.toBytes()).bytes,
      12,
    );

    _state = _State.awaitingFinished;
    _flight = () {
      // Our Finished is always epoch 1, sequence 0: a retransmission repeats
      // the same record, so the server can drop it as a duplicate.
      final encryptedFinished = DtlsRecord(
        type: ContentType.handshake,
        epoch: 1,
        sequence: 0,
        fragment: writeCipher.seal(1, 0, ContentType.handshake, finished),
      ).encode();
      return Uint8List.fromList([
        ..._plainRecord(ContentType.handshake, keyExchange),
        ..._plainRecord(ContentType.changeCipherSpec, const [1]),
        ...encryptedFinished,
      ]);
    };
    _sendFlight();
  }

  void _onServerFinished(HandshakeMessage message) {
    final expected = _expectedServerVerifyData!;
    var difference = message.body.length ^ expected.length;
    for (var i = 0; i < expected.length && i < message.body.length; i++) {
      difference |= message.body[i] ^ expected[i];
    }
    if (difference != 0) {
      throw const DtlsException(
          'Bridge could not prove it knows the key; pair LumiFX again');
    }
    _retransmitTimer?.cancel();
    final subscription = _subscription!;
    _subscription = null;
    _completer.complete(DtlsPskClient._(
      transport,
      subscription,
      _writeCipher!,
      _readCipher!,
    ));
  }

  void _fail(String message) {
    if (!_completer.isCompleted) {
      _completer.completeError(DtlsException(message));
    }
  }
}

/// AES-128-GCM record protection (RFC 5288) with DTLS sequence numbers.
class _GcmCipher {
  _GcmCipher(this._key, this._salt);

  final Uint8List _key;
  final Uint8List _salt;

  Uint8List seal(int epoch, int sequence, int type, Uint8List plaintext) {
    final explicitNonce = _sequenceBytes(epoch, sequence);
    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        true,
        AEADParameters(
          KeyParameter(_key),
          128,
          Uint8List.fromList([..._salt, ...explicitNonce]),
          _aad(explicitNonce, type, plaintext.length),
        ),
      );
    return Uint8List.fromList([...explicitNonce, ...cipher.process(plaintext)]);
  }

  /// Returns the plaintext, or null if the record does not authenticate.
  Uint8List? open(DtlsRecord record) {
    final fragment = record.fragment;
    if (fragment.length < 8 + 16) {
      return null;
    }
    final explicitNonce = Uint8List.sublistView(fragment, 0, 8);
    final sealed = Uint8List.sublistView(fragment, 8);
    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        false,
        AEADParameters(
          KeyParameter(_key),
          128,
          Uint8List.fromList([..._salt, ...explicitNonce]),
          _aad(
            _sequenceBytes(record.epoch, record.sequence),
            record.type,
            sealed.length - 16,
          ),
        ),
      );
    try {
      return cipher.process(sealed);
    } on InvalidCipherTextException {
      return null;
    } on ArgumentError {
      return null;
    }
  }

  static Uint8List _sequenceBytes(int epoch, int sequence) => (ByteWriter()
        ..u16(epoch)
        ..u48(sequence))
      .toBytes();

  static Uint8List _aad(Uint8List sequence, int type, int length) =>
      (ByteWriter()
            ..bytes(sequence)
            ..u8(type)
            ..bytes(dtls12)
            ..u16(length))
          .toBytes();
}
