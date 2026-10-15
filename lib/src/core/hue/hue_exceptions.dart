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

/// The bridge answered 429: too many commands in a short time.
class BridgeBusyException extends HueException {
  const BridgeBusyException()
      : super('The bridge is busy; try again in a moment.', statusCode: 429);
}

/// Streaming needs the Entertainment client key, which these credentials
/// lack (paired before streaming support) or hold in a corrupt form.
class StreamingKeyMissingException extends HueException {
  const StreamingKeyMissingException()
      : super('Streaming needs a newer pairing. Forget the bridge and pair '
            'again.');
}

/// An entertainment area without channels cannot be streamed to.
class EmptyEntertainmentAreaException extends HueException {
  const EmptyEntertainmentAreaException()
      : super('This entertainment area has no lights.');
}

/// The bridge reported the area inactive while LumiFX was streaming to it:
/// another app took it over, or the bridge restarted.
class EntertainmentStoppedException extends HueException {
  const EntertainmentStoppedException()
      : super('The bridge stopped the stream (another app may have taken over '
            'the area).');
}
