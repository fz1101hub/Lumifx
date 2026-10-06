import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// Trust policy for a Hue Bridge's TLS certificate.
///
/// Bridges serve HTTPS with a certificate issued by Signify's private CA (or
/// self-signed on older firmware) whose common name is the bridge id, so the
/// platform trust store rejects it. Instead of accepting any certificate, we
/// only accept one for the bridge's own host, whose CN matches the bridge id
/// when known, and pin its SHA-256 fingerprint on first contact (pairing).
class BridgeCertificatePin {
  BridgeCertificatePin({
    required this.host,
    this.bridgeId,
    this.fingerprint,
  });

  final String host;
  final String? bridgeId;

  /// Hex SHA-256 of the DER certificate; null until first contact.
  String? fingerprint;

  /// Set when the bridge presented a certificate that did not match.
  bool mismatchDetected = false;

  bool accepts(X509Certificate certificate, String requestHost, int port) {
    if (requestHost != host) {
      return false;
    }
    final id = bridgeId;
    if (id != null &&
        !certificate.subject.toLowerCase().contains('cn=${id.toLowerCase()}')) {
      mismatchDetected = true;
      return false;
    }
    final presented = sha256.convert(certificate.der).toString();
    if (fingerprint == null) {
      fingerprint = presented;
      return true;
    }
    if (fingerprint != presented) {
      mismatchDetected = true;
      return false;
    }
    return true;
  }
}

http.Client createBridgeHttpClient(BridgeCertificatePin pin) {
  final client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 5)
    ..badCertificateCallback = pin.accepts;
  return IOClient(client);
}
