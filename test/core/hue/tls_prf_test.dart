import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumifx/src/core/hue/entertainment/dtls/dtls_messages.dart';
import 'package:lumifx/src/core/hue/entertainment/dtls/tls_prf.dart';

String _hex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

List<int> _bytes(String hex) => [
      for (var i = 0; i < hex.length; i += 2)
        int.parse(hex.substring(i, i + 2), radix: 16),
    ];

void main() {
  test('TLS 1.2 PRF matches the published SHA-256 test vector', () {
    final output = tlsPrf(
      _bytes('9bbe436ba940f017b17652849a71db35'),
      'test label',
      _bytes('a0ba9f936cda311827a6f796ffd5198c'),
      100,
    );
    expect(
      _hex(output),
      'e3f229ba727be17b8d122620557cd453c2aab21d07c3d495329b52d4e61edb5a'
      '6b301791e90d35c9c9a46b4e14baf9af0fa022f7077def17abfd3797c0564bab'
      '4fbc91666e9def9b97fce34f796789baa48082d122ee42c5a72e5a5110fff701'
      '87347b66',
    );
  });

  test('PSK pre-master secret layout', () {
    expect(pskPreMasterSecret([0xAA, 0xBB]), [0, 2, 0, 0, 0, 2, 0xAA, 0xBB]);
  });

  test('records round-trip through a datagram', () {
    final record = DtlsRecord(
      type: ContentType.handshake,
      epoch: 1,
      sequence: 0x010203040506,
      fragment: utf8.encode('abc'),
    );
    final datagram = [...record.encode(), ...record.encode()];
    final parsed = DtlsRecord.parseDatagram(Uint8List.fromList(datagram));
    expect(parsed, hasLength(2));
    expect(parsed.first.sequence, 0x010203040506);
    expect(parsed.first.epoch, 1);
    expect(utf8.decode(parsed.last.fragment), 'abc');
  });

  test('fragmented handshake messages are reassembled', () {
    final message = HandshakeMessage(
        HandshakeType.serverHello, 1, utf8.encode('0123456789'));
    List<int> fragment(int offset, int length) => (ByteWriter()
          ..u8(message.type)
          ..u24(message.body.length)
          ..u16(message.messageSeq)
          ..u24(offset)
          ..u24(length)
          ..bytes(message.body.sublist(offset, offset + length)))
        .toBytes();

    final reassembler = HandshakeReassembler();
    expect(reassembler.add(Uint8List.fromList(fragment(4, 6))), isEmpty);
    final done = reassembler.add(Uint8List.fromList(fragment(0, 4)));
    expect(done, hasLength(1));
    expect(utf8.decode(done.single.body), '0123456789');
  });
}
