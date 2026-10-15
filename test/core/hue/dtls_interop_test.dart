// Interoperability tests for the DTLS client against OpenSSL's s_server,
// configured like a Hue Bridge: DTLS 1.2, PSK, AES-128-GCM.
//
// Skipped automatically when the `openssl` binary is not available.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumifx/src/core/hue/entertainment/dtls/dtls_client.dart';

const _identity = 'lumifx-test-identity';
const _pskHex = '0123456789abcdef0123456789ABCDEF';

List<int> _hex(String hex) => [
      for (var i = 0; i < hex.length; i += 2)
        int.parse(hex.substring(i, i + 2), radix: 16),
    ];

bool get _hasOpenSsl {
  try {
    return Process.runSync('openssl', ['version']).exitCode == 0;
  } on ProcessException {
    return false;
  }
}

Future<int> _freeUdpPort() async {
  final socket = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = socket.port;
  socket.close();
  return port;
}

class _Server {
  _Server._(this.process, this.output);

  final Process process;
  final StringBuffer output;

  static Future<(_Server, int)> start({bool listen = false}) async {
    final port = await _freeUdpPort();
    final process = await Process.start('openssl', [
      's_server',
      '-dtls1_2',
      if (listen) '-listen',
      '-accept',
      '$port',
      '-nocert',
      '-psk',
      _pskHex,
      '-psk_identity',
      _identity,
      '-cipher',
      'PSK-AES128-GCM-SHA256',
      '-quiet',
    ]);
    final output = StringBuffer();
    process.stdout.transform(utf8.decoder).listen(output.write);
    process.stderr.transform(utf8.decoder).listen(output.write);
    // Give s_server a moment to bind.
    await Future<void>.delayed(const Duration(milliseconds: 400));
    return (_Server._(process, output), port);
  }

  Future<void> waitFor(String text) async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (!output.toString().contains(text)) {
      if (DateTime.now().isAfter(deadline)) {
        fail('s_server never printed "$text". Output:\n$output');
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }

  void kill() => process.kill();
}

/// Records whether the server sent a HelloVerifyRequest.
class _SpyTransport implements DatagramTransport {
  _SpyTransport(this._inner);

  final DatagramTransport _inner;
  bool sawHelloVerifyRequest = false;

  @override
  Stream<Uint8List> get incoming => _inner.incoming.map((datagram) {
        // Record header is 13 bytes; handshake type follows.
        if (datagram.length > 13 && datagram[0] == 22 && datagram[13] == 3) {
          sawHelloVerifyRequest = true;
        }
        return datagram;
      });

  @override
  void send(Uint8List datagram) => _inner.send(datagram);

  @override
  Future<void> close() => _inner.close();
}

void main() {
  final skip = _hasOpenSsl ? false : 'openssl not installed';

  // s_server answers the first ClientHello with a cookie in both modes;
  // -listen additionally makes it stateless until the cookie is verified.
  for (final listen in [false, true]) {
    test('handshakes and sends application data (listen: $listen)', () async {
      final (server, port) = await _Server.start(listen: listen);
      addTearDown(server.kill);

      final transport =
          _SpyTransport(await UdpDatagramTransport.connect('127.0.0.1', port));
      final client = await DtlsPskClient.connect(
        transport: transport,
        identity: utf8.encode(_identity),
        psk: _hex(_pskHex),
        timeout: const Duration(seconds: 5),
      );
      client.send(utf8.encode('hello from lumifx\n'));
      await server.waitFor('hello from lumifx');

      client.send(utf8.encode('second message\n'));
      await server.waitFor('second message');
      expect(transport.sawHelloVerifyRequest, isTrue);
      await client.close();
    }, skip: skip);
  }

  test('fails when the pre-shared key is wrong', () async {
    final (server, port) = await _Server.start();
    addTearDown(server.kill);

    await expectLater(
      DtlsPskClient.connect(
        transport: await UdpDatagramTransport.connect('127.0.0.1', port),
        identity: utf8.encode(_identity),
        psk: _hex('ffffffffffffffffffffffffffffffff'),
        timeout: const Duration(seconds: 3),
      ),
      throwsA(isA<DtlsException>()),
    );
  }, skip: skip);

  test('times out when nobody answers', () async {
    final port = await _freeUdpPort();
    await expectLater(
      DtlsPskClient.connect(
        transport: await UdpDatagramTransport.connect('127.0.0.1', port),
        identity: utf8.encode(_identity),
        psk: _hex(_pskHex),
        timeout: const Duration(milliseconds: 800),
        retransmitInterval: const Duration(milliseconds: 200),
      ),
      throwsA(isA<DtlsException>()),
    );
  });
}
