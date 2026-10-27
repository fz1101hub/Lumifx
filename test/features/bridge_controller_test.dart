import 'dart:convert';

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lumifx/src/core/hue/bridge_http_client.dart';
import 'package:lumifx/src/core/hue/hue_bridge_client.dart';
import 'package:lumifx/src/core/hue/hue_discovery.dart';
import 'package:lumifx/src/core/hue/hue_models.dart';
import 'package:lumifx/src/features/bridge/bridge_controller.dart';
import 'package:lumifx/src/features/bridge/credential_store.dart';
import 'package:lumifx/src/features/library/preferences_controller.dart';

const _bridge = HueBridgeInfo(id: '001788fffe000001', host: '10.0.0.2');

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status);

/// A fake bridge whose link button is "pressed" after [pressAfter] attempts.
class _FakeBridge {
  _FakeBridge({this.pressAfter = 0});

  final int pressAfter;
  int pairAttempts = 0;
  bool reachable = true;

  http.Client get client => MockClient((request) async {
        if (!reachable) {
          throw http.ClientException('unreachable');
        }
        if (request.url.path == '/api' && request.method == 'POST') {
          if (pairAttempts++ < pressAfter) {
            return _json([
              {
                'error': {
                  'type': 101,
                  'description': 'link button not pressed'
                },
              },
            ]);
          }
          return _json([
            {
              'success': {'username': 'key-1', 'clientkey': 'psk'},
            },
          ]);
        }
        if (request.headers['hue-application-key'] != 'key-1') {
          return _json({'errors': <Object>[]}, 403);
        }
        return _json({'errors': <Object>[], 'data': <Object>[]});
      });
}

BridgeController _controller(_FakeBridge bridge, CredentialStore store) =>
    BridgeController(
      store: store,
      clientFactory: (pin, key) => HueBridgeClient(
        host: pin.host,
        client: bridge.client,
        applicationKey: key,
      ),
    );

void main() {
  group('a fresh install', () {
    const credentials = HueCredentials(bridge: _bridge, applicationKey: 'k');

    test('forgets keys an earlier install left in the keychain', () async {
      final store = InMemoryKeyValueStore();
      final keys = InMemoryCredentialStore(credentials);
      await keys.saveOthers([credentials]);
      await forgetEarlierInstall(store, keys);
      expect(await keys.load(), isNull, reason: 'paired again, by the button');
      expect(await keys.loadOthers(), isEmpty);

      // Paired now: the next launches keep it.
      await keys.save(credentials);
      await forgetEarlierInstall(store, keys);
      expect(await keys.load(), isNotNull);
    });

    test('an app updated from an older version keeps its pairing', () async {
      final store = InMemoryKeyValueStore();
      await store.write(PreferencesController.storageKey, '{}');
      final keys = InMemoryCredentialStore(credentials);
      await forgetEarlierInstall(store, keys);
      expect(await keys.load(), isNotNull);
      expect(await store.read(installedKey), isNotNull);
    });
  });

  test('starts unpaired without saved credentials', () async {
    final controller = _controller(_FakeBridge(), InMemoryCredentialStore());
    await controller.initialize();
    expect(controller.status, BridgeStatus.unpaired);
  });

  test('pairs once the link button is pressed and saves credentials', () async {
    final fake = _FakeBridge(pressAfter: 2);
    final store = InMemoryCredentialStore();
    final controller = _controller(fake, store);
    await controller.initialize();

    final paired = await controller.pair(
      _bridge,
      interval: const Duration(milliseconds: 1),
    );

    expect(paired, isTrue);
    expect(fake.pairAttempts, 3);
    expect(controller.status, BridgeStatus.connected);
    expect(controller.home, isNotNull);
    final saved = await store.load();
    expect(saved?.applicationKey, 'key-1');
    expect(saved?.clientKey, 'psk');
    expect(saved?.bridge, _bridge);
  });

  test('gives up when the button is never pressed', () async {
    final controller = _controller(
        _FakeBridge(pressAfter: 1 << 30), InMemoryCredentialStore());
    await controller.initialize();
    final paired = await controller.pair(
      _bridge,
      timeout: const Duration(milliseconds: 30),
      interval: const Duration(milliseconds: 5),
    );
    expect(paired, isFalse);
    expect(controller.status, BridgeStatus.unpaired);
    expect(controller.problem, BridgeProblem.linkButtonTimeout);
  });

  test('restores saved credentials and reports an unreachable bridge',
      () async {
    final fake = _FakeBridge()..reachable = false;
    final store = InMemoryCredentialStore(
      const HueCredentials(bridge: _bridge, applicationKey: 'key-1'),
    );
    final controller = _controller(fake, store);
    await controller.initialize();
    expect(controller.status, BridgeStatus.unreachable);

    fake.reachable = true;
    await controller.refresh();
    expect(controller.status, BridgeStatus.connected);
  });

  test('a second bridge keeps the first one to switch back to', () async {
    const second = HueBridgeInfo(id: '001788fffe000002', host: '10.0.0.3');
    final fake = _FakeBridge();
    final store = InMemoryCredentialStore();
    final controller = _controller(fake, store);
    await controller.initialize();
    expect(await controller.pair(_bridge, interval: Duration.zero), isTrue);
    expect(controller.otherBridges, isEmpty);
    expect(await controller.pair(second, interval: Duration.zero), isTrue);
    expect(controller.credentials?.bridge.id, second.id);
    expect(
        [for (final c in controller.otherBridges) c.bridge.id], [_bridge.id]);

    // Pairing the same bridge again does not list it twice.
    expect(await controller.pair(second, interval: Duration.zero), isTrue);
    expect(controller.otherBridges, hasLength(1));

    await controller.switchTo(_bridge.id);
    expect(controller.credentials?.bridge.id, _bridge.id);
    expect(controller.status, BridgeStatus.connected);
    expect([for (final c in controller.otherBridges) c.bridge.id], [second.id]);
    expect((await store.load())?.bridge.id, _bridge.id);

    // After a restart both are still there.
    final again = _controller(fake, store);
    await again.initialize();
    expect(again.credentials?.bridge.id, _bridge.id);
    expect([for (final c in again.otherBridges) c.bridge.id], [second.id]);

    // Forgetting one leaves the other in use; forgetting both unpairs.
    await again.forget();
    expect(again.credentials?.bridge.id, second.id);
    expect(again.otherBridges, isEmpty);
    await again.forget();
    expect(again.status, BridgeStatus.unpaired);
    expect(await store.loadOthers(), isEmpty);
  });

  test('forget clears credentials', () async {
    final store = InMemoryCredentialStore(
      const HueCredentials(bridge: _bridge, applicationKey: 'key-1'),
    );
    final controller = _controller(_FakeBridge(), store);
    await controller.initialize();
    await controller.forget();
    expect(controller.status, BridgeStatus.unpaired);
    expect(await store.load(), isNull);
  });

  test('finds the bridge at a new address when the old one stops answering',
      () async {
    const movedBridge = HueBridgeInfo(id: '001788fffe000001', host: '10.0.0.9');
    final hostsSeen = <String>[];
    final store = InMemoryCredentialStore(
      const HueCredentials(bridge: _bridge, applicationKey: 'key-1'),
    );
    final fake = _FakeBridge();
    final controller = BridgeController(
      store: store,
      discovery: _ListDiscovery([
        const HueBridgeInfo(id: 'ffffffffffffffff', host: '10.0.0.3'),
        movedBridge,
      ]),
      clientFactory: (pin, key) {
        hostsSeen.add(pin.host);
        // Only the new address answers.
        fake.reachable = pin.host == movedBridge.host;
        return HueBridgeClient(
          host: pin.host,
          client: fake.client,
          applicationKey: key,
        );
      },
    );
    await controller.initialize();

    expect(controller.status, BridgeStatus.connected);
    expect(hostsSeen, [_bridge.host, movedBridge.host]);
    expect((await store.load())?.bridge.host, movedBridge.host);
    expect(controller.credentials?.applicationKey, 'key-1');
  });

  test('does not search again for a rejected key', () async {
    var searches = 0;
    final controller = BridgeController(
      store: InMemoryCredentialStore(
        const HueCredentials(bridge: _bridge, applicationKey: 'stale'),
      ),
      discovery: _ListDiscovery(const [], onSearch: () => searches++),
      clientFactory: (pin, key) => HueBridgeClient(
        host: pin.host,
        client: _FakeBridge().client,
        applicationKey: key,
      ),
    );
    await controller.initialize();
    expect(controller.status, BridgeStatus.unreachable);
    expect(searches, 0);
  });
  test(
      'a different device at the old address triggers the search, '
      'a changed certificate of the same bridge does not', () async {
    Future<BridgeStatus> run(CertificateMismatch mismatch) async {
      const moved = HueBridgeInfo(id: '001788fffe000001', host: '10.0.0.9');
      final fake = _FakeBridge();
      final controller = BridgeController(
        store: InMemoryCredentialStore(
          const HueCredentials(bridge: _bridge, applicationKey: 'key-1'),
        ),
        discovery: _ListDiscovery(const [moved]),
        clientFactory: (pin, key) => HueBridgeClient(
          host: pin.host,
          applicationKey: key,
          client: pin.host == moved.host
              ? fake.client
              : MockClient((_) async {
                  pin.mismatch = mismatch;
                  throw const HandshakeException('rejected');
                }),
        ),
      );
      await controller.initialize();
      return controller.status;
    }

    expect(
        await run(CertificateMismatch.differentDevice), BridgeStatus.connected);
    expect(await run(CertificateMismatch.differentCertificate),
        BridgeStatus.unreachable);
  });

  test('forgetting the bridge during the search wins', () async {
    const moved = HueBridgeInfo(id: '001788fffe000001', host: '10.0.0.9');
    final store = InMemoryCredentialStore(
      const HueCredentials(bridge: _bridge, applicationKey: 'key-1'),
    );
    final fake = _FakeBridge();
    late BridgeController controller;
    controller = BridgeController(
      store: store,
      discovery: _ListDiscovery(const [moved], onSearch: () {
        // The user taps "Forget" while discovery is running.
        controller.forget();
      }),
      clientFactory: (pin, key) {
        fake.reachable = pin.host == moved.host;
        return HueBridgeClient(
            host: pin.host, client: fake.client, applicationKey: key);
      },
    );
    await controller.initialize();
    expect(controller.status, BridgeStatus.unpaired);
    expect(await store.load(), isNull);
  });

  test('unavailable storage keeps the pairing and lets the user retry',
      () async {
    final store = _FlakyStore(
      const HueCredentials(bridge: _bridge, applicationKey: 'key-1'),
      failures: 1,
    );
    final controller = BridgeController(
      store: store,
      clientFactory: (pin, key) => HueBridgeClient(
          host: pin.host, client: _FakeBridge().client, applicationKey: key),
    );
    await controller.initialize();
    expect(controller.status, BridgeStatus.unreachable);
    expect(controller.problem, BridgeProblem.storageUnavailable);

    await controller.refresh();
    expect(controller.status, BridgeStatus.connected);
  });
}

class _ListDiscovery implements BridgeDiscovery {
  _ListDiscovery(this.bridges, {this.onSearch});

  final List<HueBridgeInfo> bridges;
  final void Function()? onSearch;

  @override
  Stream<HueBridgeInfo> discover({Duration timeout = Duration.zero}) {
    onSearch?.call();
    return Stream.fromIterable(bridges);
  }
}

/// Fails the first [failures] reads with a platform-style error.
class _FlakyStore implements CredentialStore {
  _FlakyStore(this._credentials, {required this.failures});

  HueCredentials? _credentials;
  int failures;

  @override
  Future<HueCredentials?> load() async {
    if (failures-- > 0) {
      throw const CredentialStoreException('keychain locked');
    }
    return _credentials;
  }

  @override
  Future<void> save(HueCredentials credentials) async =>
      _credentials = credentials;

  @override
  Future<void> clear() async => _credentials = null;

  @override
  Future<List<HueCredentials>> loadOthers() async => const [];

  @override
  Future<void> saveOthers(List<HueCredentials> others) async {}
}
