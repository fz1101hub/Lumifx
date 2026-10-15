import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// Why the last certificate was rejected.
enum CertificateMismatch {
  none,

  /// The certificate's common name is not the bridge id: something else is
  /// answering at this address (the bridge probably moved).
  differentDevice,

  /// Same bridge id, different certificate from the one pinned at pairing.
  differentCertificate,
}

/// Trust policy for a Hue Bridge's TLS certificate.
///
/// Bridges serve HTTPS with a certificate issued by Signify's private CA (or
/// self-signed on older firmware) whose common name is the bridge id, so the
/// platform trust store rejects it. Instead of accepting any certificate, we
/// only accept one for the bridge's own host, whose CN matches the bridge id
/// when known, and pin its SHA-256 fingerprint on first contact (pairing).
class BridgeCertificatePin {
  BridgeCertificatePin({
    required String host,
    this.bridgeId,
    this.fingerprint,
  }) : host = host.toLowerCase();

  final String host;
  final String? bridgeId;

  /// Hex SHA-256 of the DER certificate; null until first contact.
  String? fingerprint;

  /// Set when the bridge presented a certificate that did not match.
  CertificateMismatch mismatch = CertificateMismatch.none;

  bool get mismatchDetected => mismatch != CertificateMismatch.none;

  /// Forgets a previous rejection before a new attempt.
  void reset() => mismatch = CertificateMismatch.none;

  bool accepts(X509Certificate certificate, String requestHost, int port) {
    if (requestHost.toLowerCase() != host) {
      return false;
    }
    final id = bridgeId;
    if (id != null &&
        !certificate.subject.toLowerCase().contains('cn=${id.toLowerCase()}')) {
      mismatch = CertificateMismatch.differentDevice;
      return false;
    }
    final presented = sha256.convert(certificate.der).toString();
    if (fingerprint == null) {
      fingerprint = presented;
      return true;
    }
    if (fingerprint != presented) {
      mismatch = CertificateMismatch.differentCertificate;
      return false;
    }
    return true;
  }
}

/// An HTTP client that trusts no root certificate, so every bridge
/// certificate goes through [BridgeCertificatePin.accepts], and that never
/// follows redirects (which would carry the application key elsewhere).
http.Client createBridgeHttpClient(BridgeCertificatePin pin) {
  final client = HttpClient(context: SecurityContext(withTrustedRoots: false))
    ..connectionTimeout = const Duration(seconds: 5)
    ..badCertificateCallback = pin.accepts;
  return _NoRedirectClient(IOClient(client));
}

class _NoRedirectClient extends http.BaseClient {
  _NoRedirectClient(this._inner);

  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.followRedirects = false;
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}
