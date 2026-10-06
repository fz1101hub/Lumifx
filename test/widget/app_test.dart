import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumifx/src/app.dart';
import 'package:lumifx/src/core/hue/hue_discovery.dart';
import 'package:lumifx/src/core/hue/hue_models.dart';
import 'package:lumifx/src/features/bridge/bridge_controller.dart';
import 'package:lumifx/src/features/bridge/credential_store.dart';

class _FakeDiscovery implements BridgeDiscovery {
  @override
  Stream<HueBridgeInfo> discover({Duration timeout = Duration.zero}) =>
      Stream.value(
        const HueBridgeInfo(id: '001788fffe123456', host: '10.0.0.9'),
      );
}

Future<void> _pumpApp(WidgetTester tester) async {
  final bridge = BridgeController(store: InMemoryCredentialStore());
  await tester.runAsync(bridge.initialize);
  await tester.pumpWidget(
    LumiFxApp(bridge: bridge, discovery: _FakeDiscovery()),
  );
}

void main() {
  testWidgets('home offers bridge setup and the three experience types',
      (tester) async {
    await _pumpApp(tester);
    expect(find.text('Connect your Hue Bridge'), findsOneWidget);
    expect(find.text('Scenes'), findsOneWidget);
    expect(find.text('Stories'), findsOneWidget);
    expect(find.text('Interactive'), findsOneWidget);
  });

  testWidgets('a story can be previewed without a bridge', (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.text('Stories'));
    await tester.pumpAndSettle();
    expect(find.text('Emerald Trickster'), findsOneWidget);

    await tester.tap(find.text('Emerald Trickster'));
    await tester.pumpAndSettle();
    expect(find.text('Preview only'), findsOneWidget);
    expect(find.text('Lamp 1'), findsOneWidget);

    await tester.tap(find.text('Play'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Pause'), findsOneWidget);

    await tester.tap(find.text('Pause'));
    await tester.pump();
    expect(find.text('Play'), findsOneWidget);

    // Leave the screen so the player stops its timer.
    await tester.pageBack();
    await tester.pumpAndSettle();
  });

  testWidgets('bridge setup lists discovered bridges', (tester) async {
    await _pumpApp(tester);
    await tester.tap(find.text('Connect your Hue Bridge'));
    await tester.pumpAndSettle();
    expect(find.text('Hue Bridge 123456'), findsOneWidget);
    expect(find.text('10.0.0.9'), findsOneWidget);
    expect(find.byType(OutlinedButton), findsOneWidget);
  });
}
