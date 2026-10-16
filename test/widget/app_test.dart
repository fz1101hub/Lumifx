import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lumifx/src/app.dart';
import 'package:lumifx/src/core/audio/audio_input.dart';
import 'package:lumifx/src/core/hue/hue_bridge_client.dart';
import 'package:lumifx/src/core/hue/hue_discovery.dart';
import 'package:lumifx/src/core/hue/hue_models.dart';
import 'package:lumifx/src/features/bridge/bridge_controller.dart';
import 'package:lumifx/src/features/bridge/credential_store.dart';
import 'package:lumifx/src/features/effects/mini_player.dart';
import 'package:lumifx/src/features/library/preferences_controller.dart';

import '../support/fake_audio_input.dart';
import '../support/fake_shortcuts.dart';
import '../support/phone_window.dart';

class _FakeDiscovery implements BridgeDiscovery {
  @override
  Stream<HueBridgeInfo> discover({Duration timeout = Duration.zero}) =>
      Stream.value(
        const HueBridgeInfo(id: '001788fffe123456', host: '10.0.0.9'),
      );
}

/// Preferences of a user who has already seen the flashing-lights warning.
PreferencesController _warnedPreferences() =>
    PreferencesController(store: InMemoryKeyValueStore())
      ..setFlashWarningShown(true);

Future<void> _pumpApp(WidgetTester tester) async {
  final bridge = BridgeController(store: InMemoryCredentialStore());
  await tester.runAsync(bridge.initialize);
  await tester.pumpWidget(
    LumiFxApp(
      bridge: bridge,
      discovery: _FakeDiscovery(),
      preferences: PreferencesController(store: InMemoryKeyValueStore()),
      audioInput: FakeAudioInput(),
    ),
  );
}

void main() {
  usePhoneWindow();
  _tabletTests();

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

  testWidgets('favorites and recently played appear on the home screen',
      (tester) async {
    await _pumpApp(tester);
    expect(find.text('Favorites'), findsNothing);

    await tester.tap(find.text('Scenes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ocean'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add to favorites'));
    await tester.pump();
    expect(find.byTooltip('Remove from favorites'), findsOneWidget);

    await tester.tap(find.text('Play'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Favorites'), findsOneWidget);
    expect(find.text('Recently played'), findsOneWidget);
    // Both shelves, and the mini-player: Ocean keeps playing.
    expect(find.text('Ocean'), findsNWidgets(3));
    await tester.tap(find.bySemanticsLabel('Stop'));
    await tester.pump();
    expect(find.text('Ocean'), findsNWidgets(2));
  });

  testWidgets('an effect keeps playing across screens, with a mini-player',
      (tester) async {
    await _pumpApp(tester);
    await tester.tap(find.text('Scenes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ocean'));
    await tester.pumpAndSettle();
    // On its own player there is no mini-player.
    await tester.tap(find.text('Play'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(MiniPlayer), findsNothing);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(MiniPlayer), findsOneWidget);
    expect(find.bySemanticsLabel('Pause'), findsOneWidget);

    // Another effect's player says what plays; Play cross-fades to it.
    await tester.tap(find.text('Aurora'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Ocean is playing now'), findsOneWidget);
    await tester.tap(find.text('Play'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Pause'), findsOneWidget);
    expect(find.textContaining('is playing now'), findsNothing);

    // Back on the list, the mini-player shows Aurora; tapping it reopens
    // the player.
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Aurora'), findsNWidgets(2));
    await tester.tap(find.text('Aurora').last);
    // The lamps animate while it plays: no settling, just let the page in.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Pause'), findsOneWidget);
    await tester.tap(find.text('Stop'));
    await tester.pumpAndSettle();
  });

  testWidgets('a playlist is made in the editor and plays its effects',
      (tester) async {
    await _pumpApp(tester);
    await tester.scrollUntilVisible(find.text('Playlists'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Playlists'));
    await tester.pumpAndSettle();
    expect(find.text('No playlists yet.'), findsOneWidget);

    await tester.tap(find.text('New playlist'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Evening');
    await tester.tap(find.text('5 min'));
    await tester.tap(find.text('Choose effects'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fireplace'));
    await tester.tap(find.text('Ocean'));
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('2 effects'), findsOneWidget);
    // Ocean first.
    await tester.tap(find.byTooltip('Move up').last);
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Evening'), findsOneWidget);
    expect(find.text('2 effects · 5 min each'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Play Evening'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Ocean'), findsWidgets);
    expect(find.text('Playlist Evening · 1 of 2'), findsOneWidget);
    await tester.tap(find.byTooltip('Next effect'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Playlist Evening · 2 of 2'), findsOneWidget);
    await tester.tap(find.text('Stop'));
    await tester.pumpAndSettle();
  });

  testWidgets('settings change the controls a new playback starts with',
      (tester) async {
    await _pumpApp(tester);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Connect a Hue Bridge'), findsOneWidget);

    final brightness = find.byType(Slider).first;
    await tester.drag(brightness, const Offset(-1000, 0));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Scenes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ocean'));
    await tester.pumpAndSettle();
    final slider = tester.widget<Slider>(find.byType(Slider).first);
    expect(slider.value, 0);
  });

  testWidgets('Music Sync listens while playing and stops on pause',
      (tester) async {
    final input = FakeAudioInput();
    final bridge = BridgeController(store: InMemoryCredentialStore());
    await tester.runAsync(bridge.initialize);
    await tester.pumpWidget(LumiFxApp(
      bridge: bridge,
      discovery: _FakeDiscovery(),
      // Beat effects flash: the one-time warning has been seen already.
      preferences: _warnedPreferences(),
      audioInput: input,
    ));

    await tester.tap(find.text('Interactive'));
    await tester.pumpAndSettle();
    expect(find.text('Spectrum'), findsOneWidget);
    await tester.tap(find.text('Beat Pulse'));
    await tester.pumpAndSettle();
    expect(find.text('Sensitivity'), findsOneWidget);
    expect(find.text('Speed'), findsNothing);

    await tester.runAsync(() async {
      await tester.tap(find.text('Play'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump(const Duration(milliseconds: 200));
    expect(input.started, isTrue);
    expect(find.textContaining('BPM'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.text('Pause'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    expect(input.stopped, isTrue);

    await tester.pageBack();
    await tester.pumpAndSettle();
  });

  testWidgets('Music Sync can follow the phone audio on Android 10+',
      (tester) async {
    final microphone = FakeAudioInput();
    final phone = FakeAudioInput();
    final preferences = _warnedPreferences();
    final bridge = BridgeController(store: InMemoryCredentialStore());
    await tester.runAsync(bridge.initialize);
    await tester.pumpWidget(LumiFxApp(
      bridge: bridge,
      discovery: _FakeDiscovery(),
      preferences: preferences,
      audioInput: microphone,
      phoneAudioInput: phone,
    ));

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text("This phone's audio"), 200);
    await tester.ensureVisible(find.text("This phone's audio"));
    await tester.pumpAndSettle();
    await tester.tap(find.text("This phone's audio"));
    await tester.pumpAndSettle();
    expect(preferences.musicSource, MusicSource.phoneAudio);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Interactive'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Beat Pulse'));
    await tester.pumpAndSettle();
    expect(find.textContaining('what this phone is playing'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.text('Play'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump(const Duration(milliseconds: 200));
    expect(phone.started, isTrue);
    expect(microphone.started, isFalse);
    await tester.runAsync(() async {
      await tester.tap(find.text('Pause'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    await tester.pageBack();
    await tester.pumpAndSettle();
  });

  testWidgets('the phone audio choice is hidden where it cannot work',
      (tester) async {
    await _pumpApp(tester);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Music Sync source'), findsNothing);
  });

  testWidgets('Music Sync explains a refused microphone', (tester) async {
    final bridge = BridgeController(store: InMemoryCredentialStore());
    await tester.runAsync(bridge.initialize);
    await tester.pumpWidget(LumiFxApp(
      bridge: bridge,
      discovery: _FakeDiscovery(),
      preferences: _warnedPreferences(),
      audioInput: FakeAudioInput(granted: false),
    ));
    await tester.tap(find.text('Interactive'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Party Chase'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.text('Play'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    expect(find.textContaining('microphone access'), findsOneWidget);
    expect(find.text('Play'), findsOneWidget);
  });

  testWidgets('a flashing effect warns once, and softening can be chosen',
      (tester) async {
    final bridge = BridgeController(store: InMemoryCredentialStore());
    await tester.runAsync(bridge.initialize);
    final preferences = PreferencesController(store: InMemoryKeyValueStore());
    await tester.pumpWidget(LumiFxApp(
      bridge: bridge,
      discovery: _FakeDiscovery(),
      preferences: preferences,
      audioInput: FakeAudioInput(),
    ));

    // Ocean has no flashes: no warning.
    await tester.tap(find.text('Scenes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ocean'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Play'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Flashing lights'), findsNothing);
    expect(find.text('Pause'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // The lazy list has not built the card yet: scroll until it exists,
    // then bring it fully into view.
    await tester.scrollUntilVisible(find.text('Thunderstorm'), 200);
    await tester.ensureVisible(find.text('Thunderstorm'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thunderstorm'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Play'));
    await tester.pumpAndSettle();
    expect(find.text('Flashing lights'), findsOneWidget);
    // Nothing plays until the user has chosen.
    expect(find.text('Pause'), findsNothing);
    await tester.tap(find.text('Soften flashes'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Pause'), findsOneWidget);
    expect(preferences.softFlashes, isTrue);
    expect(preferences.flashWarningShown, isTrue);
    await tester.tap(find.text('Stop'));
    await tester.pumpAndSettle();

    // Shown once only.
    await tester.tap(find.text('Play'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Flashing lights'), findsNothing);
    expect(find.text('Pause'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
  });

  testWidgets('colour variants are offered for scenes and remembered',
      (tester) async {
    final bridge = BridgeController(store: InMemoryCredentialStore());
    await tester.runAsync(bridge.initialize);
    final preferences = PreferencesController(store: InMemoryKeyValueStore());
    await tester.pumpWidget(LumiFxApp(
      bridge: bridge,
      discovery: _FakeDiscovery(),
      preferences: preferences,
      audioInput: FakeAudioInput(),
    ));
    await tester.tap(find.text('Scenes'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Aurora'), 200);
    await tester.ensureVisible(find.text('Aurora'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aurora'));
    await tester.pumpAndSettle();
    expect(find.text('Classic'), findsOneWidget);
    await tester.tap(find.text('Rose & gold'));
    await tester.pumpAndSettle();
    expect(preferences.variantOf('aurora'), 'rose_gold');
    await tester.pageBack();
    await tester.pumpAndSettle();
    // Stories have no variants.
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stories'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Emerald Trickster'));
    await tester.pumpAndSettle();
    expect(find.text('Classic'), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
  });

  testWidgets('a sleep timer can be set and shows the time left',
      (tester) async {
    await _pumpApp(tester);
    await tester.tap(find.text('Scenes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ocean'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sleep timer'));
    await tester.pumpAndSettle();
    expect(find.text('Off'), findsOneWidget);
    await tester.tap(find.text('30 min'));
    await tester.pumpAndSettle();
    expect(find.text('30 min'), findsOneWidget);

    await tester.tap(find.text('Play'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Lights off in 30 minutes'), findsOneWidget);
    await tester.tap(find.text('Stop'));
    await tester.pumpAndSettle();
    expect(find.text('30 min'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
  });

  testWidgets('home-screen shortcuts follow the favourites and open the player',
      (tester) async {
    final bridge = BridgeController(store: InMemoryCredentialStore());
    await tester.runAsync(bridge.initialize);
    final preferences = PreferencesController(store: InMemoryKeyValueStore());
    await preferences.recordPlayed('fireplace');
    final shortcuts = FakeShortcuts();
    await tester.pumpWidget(LumiFxApp(
      bridge: bridge,
      discovery: _FakeDiscovery(),
      preferences: preferences,
      audioInput: FakeAudioInput(),
      shortcuts: shortcuts,
      locale: const Locale('it'),
    ));
    await tester.pumpAndSettle();
    // Without favourites, the recently played effects are offered.
    expect(shortcuts.items.map((s) => s.title), ['Camino']);

    await preferences.toggleFavorite('aurora');
    await preferences.toggleFavorite('haunted_manor');
    await tester.pump();
    expect(shortcuts.items.map((s) => s.id),
        ['effect:haunted_manor', 'effect:aurora']);
    expect(shortcuts.items.first.title, 'La Villa Infestata');

    shortcuts.launch('effect:aurora');
    await tester.pumpAndSettle();
    expect(find.text('Riproduci'), findsOneWidget);
    expect(find.text('Solo anteprima'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    // Unknown ids are ignored.
    shortcuts.launch('effect:nope');
    await tester.pumpAndSettle();
    expect(find.text('Riproduci'), findsNothing);
  });

  testWidgets('the app speaks Italian', (tester) async {
    final bridge = BridgeController(store: InMemoryCredentialStore());
    await tester.runAsync(bridge.initialize);
    await tester.pumpWidget(LumiFxApp(
      bridge: bridge,
      discovery: _FakeDiscovery(),
      preferences: PreferencesController(store: InMemoryKeyValueStore()),
      audioInput: FakeAudioInput(),
      locale: const Locale('it'),
    ));
    expect(find.text('Collega il tuo Hue Bridge'), findsOneWidget);
    expect(find.text('Scene'), findsOneWidget);
    await tester.tap(find.text('Storie'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Il Burlone di Smeraldo'));
    await tester.pumpAndSettle();
    expect(find.text('Solo anteprima'), findsOneWidget);
    expect(find.text('Lampada 1'), findsOneWidget);
    expect(find.text('Riproduci'), findsOneWidget);
    expect(find.text('Magia e fantasia'), findsNothing);
    // pageBack() looks for the English "Back" tooltip.
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Magia e fantasia'), findsWidgets);
  });

  streamingTests();
}

Future<BridgeController> _connectedBridge(
  WidgetTester tester, {
  String? clientKey,
  List<String>? puts,
}) async {
  http.Response json(Object body) => http.Response(jsonEncode(body), 200);
  final bridge = BridgeController(
    store: InMemoryCredentialStore(
      HueCredentials(
        bridge: const HueBridgeInfo(id: '001788fffe123456', host: '127.0.0.1'),
        applicationKey: 'key',
        clientKey: clientKey,
      ),
    ),
    clientFactory: (pin, key) => HueBridgeClient(
      host: pin.host,
      applicationKey: key,
      client: MockClient((request) async {
        if (request.method == 'PUT') {
          puts?.add(request.url.path);
          return json({'data': <Object>[]});
        }
        switch (request.url.path) {
          case '/clip/v2/resource/scene':
            return json({
              'data': [
                {
                  'id': 's1',
                  'metadata': {'name': 'Movie night'},
                  'group': {'rid': 'r1', 'rtype': 'room'},
                  'status': {'active': 'inactive'},
                },
              ],
            });
          case '/clip/v2/resource/light':
            return json({
              'data': [
                {
                  'id': 'l1',
                  'owner': {'rid': 'd1', 'rtype': 'device'},
                  'metadata': {'name': 'Sofa'},
                  'on': {'on': true},
                  'dimming': {'brightness': 50.0},
                },
              ],
            });
          case '/clip/v2/resource/room':
            return json({
              'data': [
                {
                  'id': 'r1',
                  'metadata': {'name': 'Living room'},
                  'children': [
                    {'rid': 'd1', 'rtype': 'device'},
                  ],
                  'services': <Object>[],
                },
              ],
            });
          case '/clip/v2/resource/entertainment_configuration':
            return json({
              'data': [
                {
                  'id': '1a8d99cc-967b-44f2-9202-43f976c0fa6b',
                  'metadata': {'name': 'TV area'},
                  'status': 'inactive',
                  'channels': [
                    {
                      'channel_id': 0,
                      'position': {'x': 0, 'y': 0, 'z': 0},
                      'members': <Object>[],
                    },
                  ],
                },
              ],
            });
        }
        return json({'data': <Object>[]});
      }),
    ),
  );
  await tester.runAsync(bridge.initialize);
  return bridge;
}

void streamingTests() {
  testWidgets('rooms list the Hue scenes of each group and recall them',
      (tester) async {
    final puts = <String>[];
    final bridge = await _connectedBridge(tester, puts: puts);
    await tester.pumpWidget(LumiFxApp(
      bridge: bridge,
      discovery: _FakeDiscovery(),
      preferences: PreferencesController(store: InMemoryKeyValueStore()),
      audioInput: FakeAudioInput(),
    ));
    await tester.scrollUntilVisible(find.text('Rooms & zones'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Rooms & zones'));
    await tester.pumpAndSettle();
    expect(find.text('Living room'), findsOneWidget);
    expect(find.text('Hue scenes'), findsOneWidget);
    await tester.tap(find.text('Movie night'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(puts, contains('/clip/v2/resource/scene/s1'));
    await tester.pumpAndSettle();
  });

  testWidgets('player offers entertainment areas and reports start errors',
      (tester) async {
    final bridge = await _connectedBridge(tester);
    expect(bridge.status, BridgeStatus.connected);
    await tester.pumpWidget(
      LumiFxApp(
        bridge: bridge,
        discovery: _FakeDiscovery(),
        preferences: PreferencesController(store: InMemoryKeyValueStore()),
        audioInput: FakeAudioInput(),
      ),
    );

    await tester.tap(find.text('Stories'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Emerald Trickster'));
    await tester.pumpAndSettle();

    // These credentials predate Entertainment support (no client key), so
    // areas are not offered and the player says why.
    expect(find.textContaining('pair again'), findsOneWidget);
    await tester.tap(find.text('Preview only'));
    await tester.pumpAndSettle();
    expect(find.text('TV area · streaming'), findsNothing);
    expect(find.text('Living room · 1 light'), findsWidgets);

    await tester.tap(find.text('Living room · 1 light').last);
    await tester.pumpAndSettle();
    expect(find.text('Sofa'), findsOneWidget);
  });

  testWidgets('player offers entertainment areas when streaming is possible',
      (tester) async {
    final bridge = await _connectedBridge(tester, clientKey: 'A' * 32);
    await tester.pumpWidget(LumiFxApp(
      bridge: bridge,
      discovery: _FakeDiscovery(),
      preferences: PreferencesController(store: InMemoryKeyValueStore()),
      audioInput: FakeAudioInput(),
    ));
    await tester.tap(find.text('Stories'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Emerald Trickster'));
    await tester.pumpAndSettle();
    expect(find.textContaining('pair again'), findsNothing);

    await tester.tap(find.text('Preview only'));
    await tester.pumpAndSettle();
    expect(find.text('TV area · streaming'), findsWidgets);
    await tester.tap(find.text('TV area · streaming').last);
    await tester.pumpAndSettle();
    expect(find.text('Channel 0'), findsOneWidget);
  });
}

/// The tablet layouts: a wide window, as on an iPad or a 10" tablet.
Future<void> _pumpWideApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(2048, 2732);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await _pumpApp(tester);
}

void _tabletTests() {
  testWidgets('on a tablet the home sections sit side by side', (tester) async {
    await _pumpWideApp(tester);
    final scenes = tester.getTopLeft(find.text('Scenes'));
    final stories = tester.getTopLeft(find.text('Stories'));
    final interactive = tester.getTopLeft(find.text('Interactive'));
    expect(stories.dy, scenes.dy);
    expect(interactive.dy, scenes.dy);
    expect(stories.dx, greaterThan(scenes.dx));
    expect(interactive.dx, greaterThan(stories.dx));
  });

  testWidgets('on a tablet the effects form a grid and the player two panes',
      (tester) async {
    await _pumpWideApp(tester);
    await tester.tap(find.text('Stories'));
    await tester.pumpAndSettle();
    final first = tester.getTopLeft(find.text('Emerald Trickster'));
    final second = tester.getTopLeft(find.text('Enchanted Fairy'));
    expect(second.dy, first.dy, reason: 'two cards share the first row');
    expect(second.dx, greaterThan(first.dx));

    await tester.tap(find.text('Emerald Trickster'));
    await tester.pumpAndSettle();
    // The target picker (setup pane) is left of the Play button (stage).
    final target = tester.getCenter(find.text('Play on'));
    final play = tester.getCenter(find.text('Play'));
    expect(play.dx, greaterThan(target.dx + 200));
    expect(find.text('Brightness'), findsOneWidget);
  });
}
