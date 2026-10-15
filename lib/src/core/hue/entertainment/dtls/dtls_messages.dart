import 'dart:typed_data';

/// Wire constants and framing for the subset of DTLS 1.2 used by Hue
/// Entertainment (RFC 6347, RFC 5246, RFC 4279, RFC 5288).
abstract final class ContentType {
  static const changeCipherSpec = 20;
  static const alert = 21;
  static const handshake = 22;
  static const applicationData = 23;
}

abstract final class HandshakeType {
  static const clientHello = 1;
  static const serverHello = 2;
  static const helloVerifyRequest = 3;
  static const serverKeyExchange = 12;
  static const serverHelloDone = 14;
  static const clientKeyExchange = 16;
  static const finished = 20;
}

/// DTLS 1.2 on the wire is {254, 253}.
const dtls12 = [0xFE, 0xFD];

/// TLS_PSK_WITH_AES_128_GCM_SHA256, the suite the Hue Bridge requires.
const pskAes128GcmSha256 = 0x00A8;

/// Signals secure renegotiation support without sending an extension.
const emptyRenegotiationInfoScsv = 0x00FF;

const recordHeaderLength = 13;
const handshakeHeaderLength = 12;

class DtlsRecord {
  const DtlsRecord({
    required this.type,
    required this.epoch,
    required this.sequence,
    required this.fragment,
  });

  final int type;
  final int epoch;

  /// 48-bit record sequence number.
  final int sequence;
  final Uint8List fragment;

  Uint8List encode() {
    return (ByteWriter()
          ..u8(type)
          ..bytes(dtls12)
          ..u16(epoch)
          ..u48(sequence)
          ..u16(fragment.length)
          ..bytes(fragment))
        .toBytes();
  }

  /// Splits a datagram into records. Malformed trailing data is dropped, as
  /// DTLS requires invalid records to be discarded silently.
  static List<DtlsRecord> parseDatagram(Uint8List datagram) {
    final records = <DtlsRecord>[];
    final reader = ByteReader(datagram);
    while (reader.remaining >= recordHeaderLength) {
      final type = reader.u8();
      reader.skip(2); // version
      final epoch = reader.u16();
      final sequence = reader.u48();
      final length = reader.u16();
      if (length > reader.remaining) {
        break;
      }
      records.add(DtlsRecord(
        type: type,
        epoch: epoch,
        sequence: sequence,
        fragment: reader.bytes(length),
      ));
    }
    return records;
  }
}

/// A complete (unfragmented) handshake message.
class HandshakeMessage {
  const HandshakeMessage(this.type, this.messageSeq, this.body);

  final int type;
  final int messageSeq;
  final Uint8List body;

  /// The message with a DTLS handshake header covering the whole body. This
  /// is both what we send and what goes into the handshake transcript.
  Uint8List encode() {
    return (ByteWriter()
          ..u8(type)
          ..u24(body.length)
          ..u16(messageSeq)
          ..u24(0)
          ..u24(body.length)
          ..bytes(body))
        .toBytes();
  }
}

/// Reassembles possibly fragmented handshake messages from records.
class HandshakeReassembler {
  final _partial = <int, _Partial>{};

  /// Handshake messages in this protocol are a few hundred bytes; a header
  /// claiming more is garbage (and would otherwise make us allocate it).
  static const maxMessageLength = 16 * 1024;
  static const _maxPartials = 8;

  /// Feeds one handshake record; returns the messages it completed.
  List<HandshakeMessage> add(Uint8List fragment) {
    final completed = <HandshakeMessage>[];
    final reader = ByteReader(fragment);
    while (reader.remaining >= handshakeHeaderLength) {
      final type = reader.u8();
      final length = reader.u24();
      final seq = reader.u16();
      final offset = reader.u24();
      final fragmentLength = reader.u24();
      if (fragmentLength > reader.remaining ||
          offset + fragmentLength > length) {
        break;
      }
      final data = reader.bytes(fragmentLength);
      if (length > maxMessageLength) {
        continue;
      }
      if (offset == 0 && fragmentLength == length) {
        completed.add(HandshakeMessage(type, seq, data));
        continue;
      }
      if (!_partial.containsKey(seq) && _partial.length >= _maxPartials) {
        continue;
      }
      final partial = _partial[seq] ??= _Partial(type, length);
      if (partial.type != type || partial.body.length != length) {
        continue;
      }
      partial.body.setRange(offset, offset + fragmentLength, data);
      partial.received.fillRange(offset, offset + fragmentLength, 1);
      if (partial.received.contains(0)) {
        continue;
      }
      _partial.remove(seq);
      completed.add(HandshakeMessage(type, seq, partial.body));
    }
    return completed;
  }
}

class _Partial {
  _Partial(this.type, int length)
      : body = Uint8List(length),
        received = Uint8List(length);

  final int type;
  final Uint8List body;
  final Uint8List received;
}

class ByteWriter {
  final _builder = BytesBuilder();

  void u8(int v) => _builder.addByte(v & 0xFF);

  void u16(int v) => _builder.add([(v >> 8) & 0xFF, v & 0xFF]);

  void u24(int v) =>
      _builder.add([(v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF]);

  void u48(int v) {
    for (var shift = 40; shift >= 0; shift -= 8) {
      _builder.addByte((v >> shift) & 0xFF);
    }
  }

  void bytes(List<int> v) => _builder.add(v);

  /// Opaque vector with a 1-byte length prefix.
  void vector8(List<int> v) {
    u8(v.length);
    bytes(v);
  }

  /// Opaque vector with a 2-byte length prefix.
  void vector16(List<int> v) {
    u16(v.length);
    bytes(v);
  }

  Uint8List toBytes() => _builder.toBytes();
}

class ByteReader {
  ByteReader(this._data);

  final Uint8List _data;
  int _offset = 0;

  int get remaining => _data.length - _offset;

  void _need(int n) {
    if (n > remaining) {
      throw const FormatException('Truncated DTLS message');
    }
  }

  int u8() {
    _need(1);
    return _data[_offset++];
  }

  int u16() => (u8() << 8) | u8();

  int u24() => (u8() << 16) | (u8() << 8) | u8();

  int u48() {
    var v = 0;
    for (var i = 0; i < 6; i++) {
      v = (v << 8) | u8();
    }
    return v;
  }

  Uint8List bytes(int n) {
    _need(n);
    final out = Uint8List.sublistView(_data, _offset, _offset + n);
    _offset += n;
    return out;
  }

  Uint8List vector8() => bytes(u8());

  Uint8List vector16() => bytes(u16());

  void skip(int n) => bytes(n);
}
