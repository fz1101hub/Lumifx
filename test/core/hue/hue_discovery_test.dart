import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lumifx/src/core/hue/hue_discovery.dart';
import 'package:lumifx/src/core/hue/hue_models.dart';

class _Fixed implements BridgeDiscovery {
  _Fixed(this.bridges, {this.throws = false});

  final List<HueBridgeInfo> bridges;
  final bool throws;
  bool cancelled = false;

  @override
  Stream<HueBridgeInfo> discover({Duration timeout = Duration.zero}) {
    if (throws) {
      throw StateError('no network');
    }
    final controller =
        StreamController<HueBridgeInfo>(onCancel: () => cancelled = true);
    for (final bridge in bridges) {
      controller.add(bridge);
    }
    // Never closes on its own, like a long mDNS browse.
    return controller.stream;
  }
}

const _a = HueBridgeInfo(id: '001788fffe000001', host: '10.0.0.1');

void main() {
  test('composite de-duplicates and survives a strategy that throws', () async {
    final composite = CompositeBridgeDiscovery([
      _Fixed([_a], throws: true),
      _Fixed([_a, _a]),
    ]);
    final first = await composite.discover().first;
    expect(first, _a);
  });

  test('cancelling the composite cancels the strategies', () async {
    final inner = _Fixed([_a]);
    final subscription =
        CompositeBridgeDiscovery([inner]).discover().listen((_) {});
    await Future<void>.delayed(Duration.zero);
    await subscription.cancel();
    expect(inner.cancelled, isTrue);
  });

  test('cloud discovery ignores entries with malformed ids', () async {
    final discovery = CloudBridgeDiscovery(
      client: MockClient((_) async => http.Response(
            jsonEncode([
              {'id': 'not-a-bridge', 'internalipaddress': '10.0.0.2'},
              {'id': '001788FFFE000001', 'internalipaddress': '10.0.0.1'},
              {'id': 5, 'internalipaddress': '10.0.0.3'},
            ]),
            200,
          )),
    );
    expect(await discovery.discover().toList(), [_a]);
  });
}
