import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lumifx/src/core/hue/hue_bridge_client.dart';
import 'package:lumifx/src/core/hue/hue_discovery.dart';
import 'package:lumifx/src/core/hue/hue_models.dart';
import 'package:lumifx/src/features/bridge/bridge_controller.dart';
import 'package:lumifx/src/features/bridge/credential_store.dart';

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
    expect(controller.error, isNotNull);
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
