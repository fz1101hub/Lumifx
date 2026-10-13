class HueException implements Exception {
  const HueException(this.message, {this.statusCode});

  final String message;

  /// HTTP status of the failed request, when there was one.
  final int? statusCode;

  @override
  String toString() => 'HueException: $message';
}

/// The user has not pressed the bridge's link button yet (Hue error 101).
class LinkButtonNotPressedException extends HueException {
  const LinkButtonNotPressedException() : super('Link button not pressed');
}

/// The application key was rejected; the app must pair again.
class UnauthorizedException extends HueException {
  const UnauthorizedException() : super('Application key not accepted');
}

/// The bridge presented a TLS certificate different from the pinned one.
class CertificateMismatchException extends HueException {
  const CertificateMismatchException()
      : super('Bridge certificate does not match the paired bridge');
}

/// The bridge does not offer the CLIP v2 API: a first-generation round
/// bridge, or a square bridge that needs a software update.
class UnsupportedBridgeException extends HueException {
  const UnsupportedBridgeException()
      : super('This bridge needs a software update (in the Hue app) before '
            'LumiFX can use it. The original round bridge is not supported.');
}
