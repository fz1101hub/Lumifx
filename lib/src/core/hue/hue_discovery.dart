import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:nsd/nsd.dart' as nsd;

import 'hue_models.dart';

/// Finds Hue Bridges on the local network.
abstract interface class BridgeDiscovery {
  /// Emits each bridge once as it is found, and closes after [timeout].
  Stream<HueBridgeInfo> discover({Duration timeout});
}

/// Bonjour / NSD discovery of `_hue._tcp`, using the platform's native
/// service browser (no raw multicast sockets, so no special iOS entitlement).
class MdnsBridgeDiscovery implements BridgeDiscovery {
  const MdnsBridgeDiscovery();

  @override
  Stream<HueBridgeInfo> discover({
    Duration timeout = const Duration(seconds: 5),
  }) async* {
    final nsd.Discovery discovery;
    try {
      discovery = await nsd.startDiscovery(
        '_hue._tcp',
        ipLookupType: nsd.IpLookupType.v4,
      );
    } on Object {
      // NSD is unavailable (e.g. tests, unsupported platform): no results.
      return;
    }

    final found = StreamController<HueBridgeInfo>();
    void onService(nsd.Service service, nsd.ServiceStatus status) {
      if (status != nsd.ServiceStatus.found) {
        return;
      }
      final bridge = _toBridge(service);
      if (bridge != null) {
        found.add(bridge);
      }
    }

    discovery.addServiceListener(onService);
    for (final service in discovery.services) {
      onService(service, nsd.ServiceStatus.found);
    }
    final timer = Timer(timeout, found.close);
    try {
      yield* found.stream;
    } finally {
      timer.cancel();
      discovery.removeServiceListener(onService);
      await nsd.stopDiscovery(discovery);
    }
  }

  static HueBridgeInfo? _toBridge(nsd.Service service) {
    final address = service.addresses
        ?.where((a) => a.type == InternetAddressType.IPv4)
        .firstOrNull;
    final host = address?.address ?? service.host;
    final rawId = service.txt?['bridgeid'];
    if (host == null || rawId == null) {
      return null;
    }
    return HueBridgeInfo(
      id: utf8.decode(rawId).toLowerCase(),
      host: host,
      name: service.name,
    );
  }
}

/// Philips' discovery endpoint, which lists bridges that registered from
/// the same public IP. Rate limited, so used as a complement to mDNS.
class CloudBridgeDiscovery implements BridgeDiscovery {
  CloudBridgeDiscovery({http.Client? client}) : _client = client;

  static final endpoint = Uri.https('discovery.meethue.com', '/');

  final http.Client? _client;

  @override
  Stream<HueBridgeInfo> discover({
    Duration timeout = const Duration(seconds: 5),
  }) async* {
    final client = _client ?? http.Client();
    try {
      final response = await client.get(endpoint).timeout(timeout);
      if (response.statusCode != 200) {
        return;
      }
      final body = jsonDecode(response.body);
      if (body is! List) {
        return;
      }
      for (final entry in body.whereType<Map<String, Object?>>()) {
        final id = entry['id'];
        final host = entry['internalipaddress'];
        if (id is String && host is String) {
          yield HueBridgeInfo(id: id.toLowerCase(), host: host);
        }
      }
    } on Object {
      // Offline or rate limited: mDNS and manual entry still work.
      return;
    } finally {
      if (_client == null) {
        client.close();
      }
    }
  }
}

/// Runs several discovery strategies at once, keeping the first result for
/// each bridge id.
class CompositeBridgeDiscovery implements BridgeDiscovery {
  const CompositeBridgeDiscovery(this.strategies);

  final List<BridgeDiscovery> strategies;

  @override
  Stream<HueBridgeInfo> discover({
    Duration timeout = const Duration(seconds: 5),
  }) {
    final seen = <String>{};
    final controller = StreamController<HueBridgeInfo>();
    var pending = strategies.length;
    if (pending == 0) {
      controller.close();
    }
    for (final strategy in strategies) {
      strategy.discover(timeout: timeout).listen(
            (bridge) {
              if (seen.add(bridge.id)) {
                controller.add(bridge);
              }
            },
            onError: (Object _) {},
            onDone: () {
              if (--pending == 0) {
                controller.close();
              }
            },
          );
    }
    return controller.stream;
  }
}
