import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/hue/bridge_http_client.dart';
import '../../core/hue/hue_bridge_client.dart';
import '../../core/hue/hue_exceptions.dart';
import '../../core/hue/hue_models.dart';
import 'credential_store.dart';

enum BridgeStatus {
  /// Reading saved credentials.
  initializing,

  /// No bridge paired yet.
  unpaired,

  /// Waiting for the user to press the bridge's link button.
  pairing,

  /// Paired; [BridgeController.home] holds the latest snapshot.
  connected,

  /// Paired, but the bridge could not be reached or rejected us.
  unreachable,
}

typedef BridgeClientFactory = HueBridgeClient Function(
  BridgeCertificatePin pin,
  String? applicationKey,
);

HueBridgeClient _defaultClientFactory(
  BridgeCertificatePin pin,
  String? applicationKey,
) {
  return HueBridgeClient(
    host: pin.host,
    client: createBridgeHttpClient(pin),
    applicationKey: applicationKey,
  );
}

/// Owns the connection to the user's Hue Bridge.
class BridgeController extends ChangeNotifier {
  BridgeController({
    required CredentialStore store,
    BridgeClientFactory clientFactory = _defaultClientFactory,
  })  : _store = store,
        _clientFactory = clientFactory;

  final CredentialStore _store;
  final BridgeClientFactory _clientFactory;

  BridgeStatus _status = BridgeStatus.initializing;
  HueCredentials? _credentials;
  HueBridgeClient? _client;
  HueHome? _home;
  String? _error;
  bool _pairingCancelled = false;

  BridgeStatus get status => _status;
  HueCredentials? get credentials => _credentials;
  HueHome? get home => _home;
  String? get error => _error;

  /// Client for the paired bridge, or null when not paired.
  HueBridgeClient? get client => _client;

  bool get isConnected => _status == BridgeStatus.connected;

  Future<void> initialize() async {
    final saved = await _store.load();
    if (saved == null) {
      _setStatus(BridgeStatus.unpaired);
      return;
    }
    _useCredentials(saved);
    await refresh();
  }

  /// Confirms that [host] is a Hue Bridge; used for manual entry.
  Future<HueBridgeInfo> probe(String host) {
    final client = _clientFactory(BridgeCertificatePin(host: host), null);
    return client.fetchInfo();
  }

  /// Polls the bridge until the link button is pressed, [timeout] passes or
  /// [cancelPairing] is called. Returns true when paired.
  Future<bool> pair(
    HueBridgeInfo bridge, {
    Duration timeout = const Duration(seconds: 30),
    Duration interval = const Duration(seconds: 1),
  }) async {
    final previousStatus = _status;
    _pairingCancelled = false;
    _error = null;
    _setStatus(BridgeStatus.pairing);

    final pin = BridgeCertificatePin(host: bridge.host, bridgeId: bridge.id);
    final client = _clientFactory(pin, null);
    final deadline = DateTime.now().add(timeout);

    while (!_pairingCancelled && DateTime.now().isBefore(deadline)) {
      try {
        final keys = await client.pair(deviceName: _deviceName());
        final credentials = HueCredentials(
          bridge: bridge,
          applicationKey: keys.applicationKey,
          clientKey: keys.clientKey,
          certificateFingerprint: pin.fingerprint,
        );
        await _store.save(credentials);
        _useCredentials(credentials);
        await refresh();
        return true;
      } on LinkButtonNotPressedException {
        await Future<void>.delayed(interval);
      } on Object catch (error) {
        _error = _describe(error, pin);
        break;
      }
    }

    if (_pairingCancelled) {
      _error = null;
    } else {
      _error ??= 'The bridge button was not pressed in time.';
    }
    _setStatus(_credentials == null ? BridgeStatus.unpaired : previousStatus);
    return false;
  }

  void cancelPairing() => _pairingCancelled = true;

  /// Reloads lights, rooms and zones.
  Future<void> refresh() async {
    final client = _client;
    if (client == null) {
      return;
    }
    try {
      _home = await client.fetchHome();
      _error = null;
      _setStatus(BridgeStatus.connected);
    } on Object catch (error) {
      _error = _describe(error, null);
      _setStatus(BridgeStatus.unreachable);
    }
  }

  Future<void> forget() async {
    await _store.clear();
    _credentials = null;
    _client = null;
    _home = null;
    _error = null;
    _setStatus(BridgeStatus.unpaired);
  }

  void _useCredentials(HueCredentials credentials) {
    _credentials = credentials;
    final pin = BridgeCertificatePin(
      host: credentials.bridge.host,
      bridgeId: credentials.bridge.id,
      fingerprint: credentials.certificateFingerprint,
    );
    _client = _clientFactory(pin, credentials.applicationKey);
  }

  void _setStatus(BridgeStatus status) {
    _status = status;
    notifyListeners();
  }

  static String _deviceName() {
    try {
      return Platform.operatingSystem;
    } on Object {
      return 'app';
    }
  }

  static String _describe(Object error, BridgeCertificatePin? pin) {
    if (error is CertificateMismatchException ||
        (pin?.mismatchDetected ?? false)) {
      return const CertificateMismatchException().message;
    }
    if (error is UnauthorizedException) {
      return 'The bridge no longer accepts LumiFX. Pair it again.';
    }
    if (error is HueException) {
      return error.message;
    }
    if (error is TimeoutException ||
        error is SocketException ||
        error is http.ClientException) {
      return 'The bridge could not be reached on this network.';
    }
    if (error is HandshakeException) {
      return const CertificateMismatchException().message;
    }
    return 'Something went wrong talking to the bridge.';
  }
}
