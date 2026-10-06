class HueException implements Exception {
  const HueException(this.message);

  final String message;

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
