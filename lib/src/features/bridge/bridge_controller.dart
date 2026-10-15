import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/hue/bridge_http_client.dart';
import '../../core/hue/entertainment/entertainment_session.dart';
import '../../core/hue/hue_bridge_client.dart';
import '../../core/hue/hue_discovery.dart';
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

/// Why the bridge is unreachable, or why pairing failed. The UI turns it
/// into a localised sentence.
enum BridgeProblem {
  /// Secure storage could not be read at launch; the pairing may be intact.
  storageUnavailable,

  /// The bridge accepted the app but the credentials could not be saved.
  storageWriteFailed,

  /// The link button was not pressed before the pairing timed out.
  linkButtonTimeout,

  /// The application key was rejected: pair again.
  unauthorized,

  /// Nothing we trust answered at the bridge's address.
  unreachable,

  /// Same bridge id, different TLS certificate from the pinned one.
  certificateMismatch,

  /// The bridge has no CLIP v2 API (old firmware or first-generation).
  unsupportedBridge,

  /// The bridge rate-limited us.
  bridgeBusy,

  other,
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
    BridgeDiscovery? discovery,
  })  : _store = store,
        _clientFactory = clientFactory,
        _discovery = discovery;

  final CredentialStore _store;
  final BridgeClientFactory _clientFactory;

  /// Used to find the bridge again when its IP address changes.
  final BridgeDiscovery? _discovery;
  bool _relocating = false;

  BridgeStatus _status = BridgeStatus.initializing;
  HueCredentials? _credentials;
  HueBridgeClient? _client;

  /// Trust policy of [_client], consulted to tell a moved bridge from a
  /// changed certificate.
  BridgeCertificatePin? _pin;
  HueHome? _home;
  BridgeProblem? _problem;
  bool _pairingCancelled = false;

  BridgeStatus get status => _status;
  HueCredentials? get credentials => _credentials;
  HueHome? get home => _home;
  BridgeProblem? get problem => _problem;

  /// Client for the paired bridge, or null when not paired.
  HueBridgeClient? get client => _client;

  bool get isConnected => _status == BridgeStatus.connected;

  Future<void> initialize() async {
    HueCredentials? saved;
    try {
      saved = await _store.load();
    } on CredentialStoreException {
      // Storage is unavailable right now; keep the pairing and let the user
      // retry instead of showing the app as unpaired.
      _problem = BridgeProblem.storageUnavailable;
      _setStatus(BridgeStatus.unreachable);
      return;
    } on Object {
      // Never leave the app on the loading state because storage failed.
      saved = null;
    }
    if (saved == null) {
      _setStatus(BridgeStatus.unpaired);
      return;
    }
    _useCredentials(saved);
    await refresh();
  }

  /// Confirms that [host] is a Hue Bridge; used for manual entry.
  Future<HueBridgeInfo> probe(String host) async {
    final client = _clientFactory(
      BridgeCertificatePin(host: host.trim().toLowerCase()),
      null,
    );
    try {
      return await client.fetchInfo();
    } finally {
      client.close();
    }
  }

  /// Polls the bridge until the link button is pressed, [timeout] passes or
  /// [cancelPairing] is called. Returns true when paired.
  Future<bool> pair(
    HueBridgeInfo bridge, {
    Duration timeout = const Duration(seconds: 30),
    Duration interval = const Duration(seconds: 1),
  }) async {
    if (_status == BridgeStatus.pairing) {
      return false; // already pairing (e.g. a double tap)
    }
    final previousStatus = _status;
    _pairingCancelled = false;
    _problem = null;
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
        try {
          await _store.save(credentials);
        } on Object {
          _problem = BridgeProblem.storageWriteFailed;
          break;
        }
        client.close();
        _useCredentials(credentials);
        // Leave the pairing state so refresh() (which ignores refreshes
        // while pairing) can report connected/unreachable.
        _status = BridgeStatus.initializing;
        await refresh();
        return true;
      } on LinkButtonNotPressedException {
        await Future<void>.delayed(interval);
      } on Object catch (error) {
        _problem = _classify(error, pin);
        break;
      }
    }
    client.close();

    if (_pairingCancelled) {
      _problem = null;
    } else {
      _problem ??= BridgeProblem.linkButtonTimeout;
    }
    _setStatus(_credentials == null ? BridgeStatus.unpaired : previousStatus);
    return false;
  }

  void cancelPairing() => _pairingCancelled = true;

  /// Reloads lights, rooms and zones. If the bridge cannot be reached at
  /// its saved address (routers hand out new ones), looks for it on the
  /// network by id and retries at the new address.
  Future<void> refresh() async {
    final client = _client;
    final pin = _pin;
    if (client == null) {
      if (_credentials == null && _status == BridgeStatus.unreachable) {
        // Storage was unavailable at launch: try loading again.
        return initialize();
      }
      return;
    }
    if (_status == BridgeStatus.pairing) {
      return; // pair() reloads when it is done
    }
    pin?.reset();
    try {
      final home = await client.fetchHome();
      if (_client != client) {
        return; // forgotten or re-paired meanwhile
      }
      _home = home;
      _problem = null;
      _setStatus(BridgeStatus.connected);
    } on Object catch (error) {
      if (_client != client) {
        return;
      }
      if (_isNetworkError(error, pin) && await _relocate()) {
        return refresh();
      }
      if (_client != client) {
        return;
      }
      _problem = _classify(error, pin);
      _setStatus(BridgeStatus.unreachable);
    }
  }

  /// Finds the paired bridge at a new address. Returns true when the
  /// address changed and the client now points at it.
  Future<bool> _relocate() async {
    final discovery = _discovery;
    final credentials = _credentials;
    if (discovery == null || credentials == null || _relocating) {
      return false;
    }
    _relocating = true;
    try {
      final found = await discovery
          .discover(timeout: const Duration(seconds: 4))
          .cast<HueBridgeInfo?>()
          .firstWhere(
            (bridge) => bridge?.id == credentials.bridge.id,
            orElse: () => null,
          )
          .timeout(const Duration(seconds: 6), onTimeout: () => null);
      if (found == null || found.host == credentials.bridge.host) {
        return false;
      }
      final moved = credentials.copyWith(
        bridge: HueBridgeInfo(
          id: credentials.bridge.id,
          host: found.host,
          name: found.name ?? credentials.bridge.name,
        ),
      );
      // Forgotten or re-paired while searching: never write the old key
      // back.
      if (!identical(_credentials, credentials)) {
        return false;
      }
      await _store.save(moved);
      if (!identical(_credentials, credentials)) {
        return false;
      }
      _useCredentials(moved);
      return true;
    } on Object {
      return false;
    } finally {
      _relocating = false;
    }
  }

  /// Failures that mean "nothing we trust answered at that address": worth
  /// looking for the bridge elsewhere. A certificate that differs from the
  /// pinned one for the same bridge id is not one of them.
  static bool _isNetworkError(Object error, BridgeCertificatePin? pin) {
    if (error is HandshakeException || error is TlsException) {
      return pin?.mismatch != CertificateMismatch.differentCertificate;
    }
    return error is TimeoutException ||
        error is SocketException ||
        error is HttpException ||
        error is http.ClientException;
  }

  /// Starts streaming to [area]. The returned output releases the area
  /// when closed.
  Future<EntertainmentLightOutput> openEntertainment(
    HueEntertainmentArea area,
  ) async {
    final client = _client;
    final credentials = _credentials;
    if (client == null || credentials == null) {
      throw const HueException('No bridge connected.');
    }
    final session = await EntertainmentSession.open(
      client: client,
      credentials: credentials,
      area: area,
    );
    return EntertainmentLightOutput(session);
  }

  /// Creates an area (when [areaId] is null) or replaces an existing one,
  /// then reloads. Returns the area id.
  Future<String> saveEntertainmentArea(
    HueEntertainmentAreaDraft draft, {
    String? areaId,
  }) async {
    final client = _requireClient();
    final id = areaId ?? await client.createEntertainmentArea(draft);
    if (areaId != null) {
      await client.updateEntertainmentArea(areaId, draft);
    }
    await refresh();
    return id;
  }

  Future<void> deleteEntertainmentArea(String areaId) async {
    await _requireClient().deleteEntertainmentArea(areaId);
    await refresh();
  }

  HueBridgeClient _requireClient() {
    final client = _client;
    if (client == null) {
      throw const HueException('No bridge connected.');
    }
    return client;
  }

  Future<void> forget() async {
    await _store.clear();
    _credentials = null;
    _client?.close();
    _client = null;
    _pin = null;
    _home = null;
    _problem = null;
    _setStatus(BridgeStatus.unpaired);
  }

  void _useCredentials(HueCredentials credentials) {
    _credentials = credentials;
    final pin = BridgeCertificatePin(
      host: credentials.bridge.host,
      bridgeId: credentials.bridge.id,
      fingerprint: credentials.certificateFingerprint,
    );
    _client?.close();
    _pin = pin;
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

  static BridgeProblem _classify(Object error, BridgeCertificatePin? pin) {
    if (error is CertificateMismatchException ||
        pin?.mismatch == CertificateMismatch.differentCertificate) {
      return BridgeProblem.certificateMismatch;
    }
    if (error is UnauthorizedException) {
      return BridgeProblem.unauthorized;
    }
    if (error is UnsupportedBridgeException) {
      return BridgeProblem.unsupportedBridge;
    }
    if (error is HueException) {
      return error.statusCode == 429
          ? BridgeProblem.bridgeBusy
          : BridgeProblem.other;
    }
    if (error is TimeoutException ||
        error is SocketException ||
        error is HttpException ||
        error is TlsException ||
        error is http.ClientException) {
      // A different device at the address, a reboot mid-handshake, a
      // closed connection: all look like "not there" to the user.
      return BridgeProblem.unreachable;
    }
    return BridgeProblem.other;
  }
}
