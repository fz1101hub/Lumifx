import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumifx/src/app.dart';
import 'package:lumifx/src/core/hue/hue_discovery.dart';
import 'package:lumifx/src/core/hue/hue_models.dart';
import 'package:lumifx/src/features/bridge/bridge_controller.dart';
import 'package:lumifx/src/features/bridge/credential_store.dart';
import 'package:lumifx/src/features/library/preferences_controller.dart';

import '../support/fake_audio_input.dart';
import '../support/phone_window.dart';

void main() {
  usePhoneWindow();

  Future<void> pumpApp(WidgetTester tester) async {
    final bridge = BridgeController(store: InMemoryCredentialStore());
    await tester.runAsync(bridge.initialize);
    await tester.pumpWidget(LumiFxApp(
      bridge: bridge,
      discovery: const _NoDiscovery(),
      preferences: PreferencesController(store: InMemoryKeyValueStore())
        ..setFlashWarningShown(true),
      audioInput: FakeAudioInput(),
      // In season, so the seasonal shelf is checked too.
      clock: () => DateTime(2026, 10, 20),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> expectGuidelines(WidgetTester tester) async {
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
  }

  testWidgets('home, a list and the player meet the accessibility guidelines',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpApp(tester);
    await expectGuidelines(tester);

    await tester.tap(find.text('Scenes'));
    await tester.pumpAndSettle();
    await expectGuidelines(tester);

    await tester.tap(find.text('Ocean'));
    await tester.pumpAndSettle();
    await expectGuidelines(tester);
    // The lamps are one labelled preview, not five unlabelled circles.
    expect(find.bySemanticsLabel(RegExp('Preview of 5 lamps')), findsOneWidget);

    // Playing, back on the list: the mini-player too.
    await tester.tap(find.text('Play'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await expectGuidelines(tester);
    await tester.tap(find.bySemanticsLabel('Stop'));
    await tester.pumpAndSettle();
    semantics.dispose();
  });

  testWidgets('settings and playlists meet the accessibility guidelines',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpApp(tester);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await expectGuidelines(tester);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Playlists'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Playlists'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New playlist'));
    await tester.pumpAndSettle();
    await expectGuidelines(tester);
    semantics.dispose();
  });

  testWidgets('a phone set to reduce motion softens flashes', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await pumpApp(tester);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.textContaining('reduce motion'), 200);
    final tile = tester.widget<SwitchListTile>(find.ancestor(
      of: find.textContaining('reduce motion'),
      matching: find.byType(SwitchListTile),
    ));
    expect(tile.value, isTrue);
    expect(tile.onChanged, isNull);
  });
}

class _NoDiscovery implements BridgeDiscovery {
  const _NoDiscovery();

  @override
  Stream<HueBridgeInfo> discover({Duration timeout = Duration.zero}) =>
      const Stream.empty();
}
