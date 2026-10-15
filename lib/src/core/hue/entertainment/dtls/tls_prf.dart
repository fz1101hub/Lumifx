import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// TLS 1.2 pseudo-random function with HMAC-SHA256 (RFC 5246 §5).
Uint8List tlsPrf(List<int> secret, String label, List<int> seed, int length) {
  final labelAndSeed = [...ascii.encode(label), ...seed];
  final hmac = Hmac(sha256, secret);
  final output = BytesBuilder(copy: false);
  var a = Uint8List.fromList(hmac.convert(labelAndSeed).bytes);
  while (output.length < length) {
    output.add(hmac.convert([...a, ...labelAndSeed]).bytes);
    a = Uint8List.fromList(hmac.convert(a).bytes);
  }
  return Uint8List.sublistView(output.takeBytes(), 0, length);
}

/// Pre-master secret for plain PSK key exchange (RFC 4279 §2).
Uint8List pskPreMasterSecret(List<int> psk) {
  final n = psk.length;
  return Uint8List.fromList([
    n >> 8, n & 0xFF, ...List<int>.filled(n, 0), //
    n >> 8, n & 0xFF, ...psk,
  ]);
}
