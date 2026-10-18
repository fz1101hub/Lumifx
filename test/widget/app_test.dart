import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lumifx/src/app.dart';
import 'package:lumifx/src/app_scope.dart';
import 'package:lumifx/src/core/audio/audio_input.dart';
import 'package:lumifx/src/core/hue/hue_bridge_client.dart';
import 'package:lumifx/src/core/hue/hue_discovery.dart';
import 'package:lumifx/src/core/hue/hue_models.dart';
import 'package:lumifx/src/core/photos/photo_picker.dart';
import 'package:lumifx/src/core/weather/weather.dart';
import 'package:lumifx/src/features/bridge/bridge_controller.dart';
import 'package:lumifx/src/features/calm/breathing.dart';
import 'package:lumifx/src/features/calm/breathing_screen.dart';
import 'package:lumifx/src/features/bridge/credential_store.dart';
import 'package:lumifx/src/features/effects/mini_player.dart';
import 'package:lumifx/src/features/effects/playback_controller.dart';
import 'package:lumifx/src/features/home/home_screen.dart';
import 'package:lumifx/src/features/fun/advent_screen.dart';
import 'package:lumifx/src/features/fun/birthday_screen.dart';
import 'package:lumifx/src/features/fun/countdowns_screen.dart';
import 'package:lumifx/src/features/fun/game_screen.dart';
import 'package:lumifx/src/features/fun/light_games.dart';
import 'package:lumifx/src/features/fun/noise_light.dart';
import 'package:lumifx/src/features/fun/noise_light_screen.dart';
import 'package:lumifx/src/features/kids/kids_mode.dart';
import 'package:lumifx/src/features/fun/simon.dart';
import 'package:lumifx/src/features/fun/simon_screen.dart';
import 'package:lumifx/src/features/library/preferences_controller.dart';
import 'package:lumifx/src/features/library/scene_editor.dart';
import 'package:lumifx/src/core/hue/hue_buttons.dart';
import 'package:lumifx/src/core/hue/hue_house.dart';
import 'package:lumifx/src/core/live_activity.dart';
import 'package:lumifx/src/core/nfc/nfc_writer.dart';
import 'package:lumifx/src/core/notification_lights_platform.dart';
import 'package:lumifx/src/core/sound/sound_player.dart';
import 'package:lumifx/src/core/speech/speaker.dart';
import 'package:lumifx/src/features/bedtime/monster_spray.dart';
import 'package:lumifx/src/features/cinema/cinema.dart';
import 'package:lumifx/src/features/cinema/cinema_screen.dart';
import 'package:lumifx/src/features/bedtime/monster_spray_screen.dart';
import 'package:lumifx/src/features/bedtime/nap_light.dart';
import 'package:lumifx/src/features/bedtime/nap_light_screen.dart';
import 'package:lumifx/src/features/bedtime/ritual_screen.dart';
import 'package:lumifx/src/features/learn/colour_words.dart';
import 'package:lumifx/src/features/links/nfc_stickers_screen.dart';
import 'package:lumifx/src/features/notifications/notification_lights_screen.dart';
import 'package:lumifx/src/features/effects/playing_route.dart';
import 'package:lumifx/src/features/learn/colour_mixing.dart';
import 'package:lumifx/src/features/learn/colour_mixing_screen.dart';
import 'package:lumifx/src/features/learn/colour_words_screen.dart';
import 'package:lumifx/src/features/learn/counting.dart';
import 'package:lumifx/src/features/learn/counting_screen.dart';
import 'package:lumifx/src/features/fun/haunted_party.dart';
import 'package:lumifx/src/features/fun/haunted_party_screen.dart';
import 'package:lumifx/src/features/fun/hot_cold.dart';
import 'package:lumifx/src/features/fun/hot_cold_screen.dart';
import 'package:lumifx/src/features/learn/morse.dart';
import 'package:lumifx/src/features/learn/morse_screen.dart';
import 'package:lumifx/src/features/music_box/light_piano.dart';
import 'package:lumifx/src/features/music_box/light_piano_screen.dart';
import 'package:lumifx/src/features/music_box/music_box_screen.dart';
import 'package:lumifx/src/features/tales/tale_maker_screen.dart';
import 'package:lumifx/src/features/paths/path_story_screen.dart';
import 'package:lumifx/src/features/playlists/playlist.dart';
import 'package:lumifx/src/features/routines/routines_screen.dart';
import 'package:lumifx/src/features/routines/star_shop_screen.dart';
import 'package:lumifx/src/features/timers/pomodoro_screen.dart';
import 'package:lumifx/src/features/timers/timers_screen.dart';
import 'package:lumifx/src/features/weather/weather_screen.dart';
import 'package:lumifx/src/features/library/user_scene.dart';
import 'package:lumifx/src/features/library/sharing.dart';
import 'package:lumifx/src/features/library/story_editor.dart';

import '../support/fake_audio_input.dart';
import '../support/fake_sound_player.dart';
import '../support/fake_background_playback.dart';
import '../support/fake_home_widgets.dart';
import '../support/fake_shortcuts.dart';
import '../support/phone_window.dart';

class _RecordingSpeaker implements Speaker {
  final spoken = <(String, String)>[];

  @override
  Future<void> speak(String text, String language) async =>
      spoken.add((text, language));

  @override
  Future<void> stop() async {}
}

class _FakeNfc implements NfcWriter {
  _FakeNfc({this.available = true, this.enabled = true});

  final bool available;
  bool enabled;
  final written = <String>[];
  var settingsOpened = false;
  Completer<NfcWriteResult>? waiting;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<bool> isEnabled() async => enabled;

  @override
  Future<NfcWriteResult> write(String uri) {
    written.add(uri);
    return (waiting = Completer<NfcWriteResult>()).future;
  }

  @override
  Future<void> cancel() async => waiting?.complete(NfcWriteResult.cancelled);

  @override
  Future<void> openSettings() async => settingsOpened = true;
}

class _FakeNotificationLights implements NotificationLightsPlatform {
  var access = false;
  var accessAsked = false;
  final configured = <Map<String, Object?>?>[];

  @override
  bool get isSupported => true;

  @override
  Future<bool> hasAccess() async => access;

  @override
  Future<void> openAccessSettings() async => accessAsked = true;

  @override
  Future<List<InstalledApp>> apps() async => const [
        InstalledApp(package: 'com.ring', label: 'Ring'),
        InstalledApp(package: 'com.whatsapp', label: 'WhatsApp'),
      ];

  @override
  Future<void> configure(Map<String, Object?>? config) async =>
      configured.add(config);

  @override
  Future<bool> test(Map<String, double> xy) async => true;
}

class _FakeLiveActivity implements LiveActivity {
  @override
  bool get isSupported => true;

  @override
  Future<bool> update(LiveActivityState state) async => true;

  @override
  Future<void> end() async {}
}

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

/// Hands back the same photo every time.
class _FakePhotoPicker implements PhotoPicker {
  _FakePhotoPicker(this.photo);

  final Uint8List? photo;
  final asked = <PhotoSource>[];

  @override
  Future<Uint8List?> pick(PhotoSource source) async {
    asked.add(source);
    if (photo == null) {
      throw const PhotoUnavailable('denied');
    }
    return photo;
  }
}

/// The weather of a sunny Milan with rain tomorrow, or no network.
class _FakeWeather implements WeatherService {
  _FakeWeather({this.online = true});

  bool online;
  final searches = <(String, String)>[];

  @override
  Future<List<WeatherPlace>> search(String name,
      {String language = 'en'}) async {
    searches.add((name, language));
    if (!online) {
      throw const WeatherUnavailable('offline');
    }
    return const [
      WeatherPlace(
          name: 'Milan',
          region: 'Lombardy',
          country: 'Italy',
          latitude: 45.46,
          longitude: 9.19),
    ];
  }

  @override
  Future<WeatherReport> forecast(WeatherPlace place) async {
    if (!online) {
      throw const WeatherUnavailable('offline');
    }
    return const WeatherReport(
      now: WeatherReading(kind: WeatherKind.clear, temperature: 21.4),
      tomorrow:
          WeatherReading(kind: WeatherKind.rain, temperature: 18, low: 12),
    );
  }
}

Future<void> _pumpApp(
  WidgetTester tester, {
  PhotoPicker photos = const NoPhotoPicker(),
  AudioInput? audioInput,
  WeatherService weather = const NoWeatherService(),
  DateTime Function()? clock,
  Speaker speaker = const NoSpeaker(),
  NfcWriter nfc = const NoNfcWriter(),
  NotificationLightsPlatform notificationLights = const NoNotificationLights(),
  LiveActivity liveActivity = const NoLiveActivity(),
  SoundPlayer? sound,
}) async {
  final bridge = BridgeController(store: InMemoryCredentialStore());
  await tester.runAsync(bridge.initialize);
  // Loaded as on a phone (links wait for that), past the welcome pages.
  final preferences = PreferencesController(store: InMemoryKeyValueStore());
  // In the test's own zone: the store answers at once, and later writes
  // must chain onto futures of this zone to complete in fake time.
  await preferences.setOnboardingDone();
  await preferences.load();
  await tester.pumpWidget(
    LumiFxApp(
      bridge: bridge,
      discovery: _FakeDiscovery(),
      preferences: preferences,
      audioInput: audioInput ?? FakeAudioInput(),
      photos: photos,
      weather: weather,
      clock: clock ?? DateTime.now,
      speaker: speaker,
      nfc: nfc,
      notificationLights: notificationLights,
      liveActivity: liveActivity,
      sound: sound ?? const NoSoundPlayer(),
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

  testWidgets('a story shows its words to read along, and can hide them',
      (tester) async {
    await _pumpApp(tester);
    await tester.tap(find.text('Stories'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Emerald Trickster'));
    await tester.pumpAndSettle();
    const opening = 'Shh… something small and green is hiding in this room.';
    expect(find.text(opening), findsOneWidget);

    await tester.tap(find.text('Play'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text(opening), findsOneWidget, reason: 'the story begins');

    await tester.scrollUntilVisible(find.text('Read-along'), 200);
    await tester.tap(find.text('Read-along'));
    await tester.pump();
    expect(find.text(opening), findsNothing);

    await tester.drag(find.text('Read-along'), const Offset(0, 600));
    await tester.pump();
    await tester.tap(find.text('Pause'));
    await tester.pump();
    await tester.pageBack();
    await tester.pumpAndSettle();
  });

  testWidgets('TV Sync explains itself and a missing camera', (tester) async {
    await _pumpApp(tester);
    await tester.tap(find.text('Interactive'));
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.text('TV Sync'),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.ensureVisible(find.text('TV Sync'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('TV Sync'));
    await tester.pumpAndSettle();
    expect(find.textContaining('point the camera at the TV'), findsOneWidget);

    await tester.tap(find.text('Play'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('The camera could not be started.'), findsOneWidget);
    expect(find.text('Play'), findsOneWidget, reason: 'nothing plays');
    await tester.pageBack();
    await tester.pumpAndSettle();
  });

  testWidgets('bedtime starts a calm story with its words, then glows',
      (tester) async {
    await _pumpApp(tester);
    await tester.scrollUntilVisible(
      find.text('Bedtime'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Bedtime'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bedtime'));
    await tester.pumpAndSettle();
    expect(find.text('Sleeping Dragon'), findsOneWidget);
    // Nothing that flashes is offered at bedtime.
    await tester.tap(find.text('Sleeping Dragon'));
    await tester.pumpAndSettle();
    expect(find.text('Haunted Manor'), findsNothing);
    expect(find.text('Silent Snowfall'), findsWidgets);
    await tester.tap(find.text('Silent Snowfall').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('5 min').first);
    await tester.pump();

    await tester.scrollUntilVisible(find.text('Start bedtime'), 200);
    await tester.tap(find.text('Start bedtime'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Silent Snowfall'), findsOneWidget, reason: 'player');
    expect(find.text('Outside, the world is quiet.'), findsOneWidget);
    expect(find.textContaining('night glow at'), findsOneWidget);
    expect(find.text('Pause'), findsOneWidget);

    await tester.tap(find.text('Pause'));
    await tester.pump();
    await tester.pageBack();
    await tester.pumpAndSettle();
  });

  testWidgets('a light timer counts down on screen and can be stopped',
      (tester) async {
    final sound = FakeSoundPlayer();
    await _pumpApp(tester, sound: sound);
    await tester.scrollUntilVisible(
      find.text('Light timers'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Light timers'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Light timers'));
    await tester.pumpAndSettle();
    expect(find.text('Brush your teeth'), findsOneWidget);
    expect(find.text('2 min'), findsWidgets);

    await tester.tap(find.widgetWithText(FilledButton, 'Start').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining(RegExp(r'^[12]:\d\d$')), findsOneWidget);
    expect(find.text('Pause'), findsOneWidget);
    expect(sound.playing?.melody?.id, 'twinkle',
        reason: 'a tune while brushing');

    await tester.tap(find.text('Stop'));
    await tester.pump();
    expect(find.text("Time's up!"), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Brush your teeth'), findsOneWidget);
  });

  Future<void> openBirthday(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.text('Parties and games'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Parties and games'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Parties and games'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Birthday party'));
    await tester.pumpAndSettle();
  }

  testWidgets('a birthday: candles, a wish, blow them out, a party',
      (tester) async {
    await _pumpApp(tester);
    await openBirthday(tester);
    await tester.enterText(find.byType(TextField).first, 'Anna');
    await tester.enterText(find.byType(TextField).last, '7');
    await tester.tap(find.text('Light the candles'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Happy birthday, Anna!'), findsWidgets);
    expect(find.text('Blow out the candles'), findsOneWidget);

    await tester.tap(find.text('Blow out the candles'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Whoosh! The candles are out.'), findsOneWidget);

    // The party plays once, then the lights go back.
    final playback =
        AppScope.of(tester.element(find.byType(BirthdayScreen))).playback;
    playback.player!.advance(const Duration(seconds: 31));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('7 years old today!'), findsOneWidget);
    expect(find.text('Again!'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Birthday party'), findsOneWidget);
  });

  testWidgets('leaving with the candles lit puts them out', (tester) async {
    await _pumpApp(tester);
    await openBirthday(tester);
    await tester.tap(find.text('Light the candles'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final playback =
        AppScope.of(tester.element(find.byType(BirthdayScreen))).playback;
    expect(playback.isPlaying, isTrue);
    await tester.pageBack();
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
    expect(playback.status, PlaybackStatus.idle);
  });

  testWidgets('blowing on the phone blows the candles out', (tester) async {
    final random = math.Random(3);
    final blow = Uint8List(44100 * 2);
    final data = ByteData.sublistView(blow);
    for (var i = 0; i < 44100; i++) {
      data.setInt16(i * 2, random.nextInt(50000) - 25000, Endian.little);
    }
    final microphone = FakeAudioInput(pcm: blow);
    await _pumpApp(tester, audioInput: microphone);
    await openBirthday(tester);
    await tester.tap(find.text('Light the candles'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Happy birthday!'), findsWidgets);

    await tester.tap(find.text('Blow on the phone'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Whoosh! The candles are out.'), findsOneWidget);
    expect(microphone.stopped, isTrue, reason: 'it stops listening');
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
  });

  testWidgets('a light game shows its calls and ends with a cheer',
      (tester) async {
    await _pumpApp(tester);
    await openBirthday(tester);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Red light, green light'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.text('Red light, green light'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Red light, green light'));
    await tester.pumpAndSettle();
    expect(find.textContaining('freeze on red'), findsOneWidget);
    expect(find.text('Say the calls out loud'), findsOneWidget);

    await tester.tap(find.text('Start'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Green light: go!'), findsOneWidget);

    final playback =
        AppScope.of(tester.element(find.byType(GameScreen))).playback;
    final plan = GamePlan.of(playback.effect)!;
    final stop = plan.phases.firstWhere((p) => p.cue == GameCue.stop);
    playback.player!.advance(Duration(seconds: stop.at) -
        playback.player!.position +
        const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Red light: stop!'), findsOneWidget);

    playback.player!.advance(plan.length);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Game over! Well played!'), findsOneWidget);
    expect(find.text('Play again'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
  });

  Future<void> openWeather(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.text('Weather lights'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Weather lights'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Weather lights'));
    await tester.pumpAndSettle();
  }

  testWidgets('weather lights: a city, the weather, on the lamps',
      (tester) async {
    tester.platformDispatcher.localeTestValue = const Locale('en', 'GB');
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
    final weather = _FakeWeather();
    await _pumpApp(tester, weather: weather);
    await openWeather(tester);
    expect(find.textContaining('Open-Meteo.com'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Mil');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(weather.searches, [('Mil', 'en')]);
    await tester.tap(find.text('Milan, Lombardy, Italy'));
    await tester.pumpAndSettle();

    expect(find.text('Now'), findsOneWidget);
    expect(find.text('Clear sky'), findsOneWidget);
    expect(find.text('21°'), findsOneWidget);
    expect(find.text('Tomorrow'), findsOneWidget);
    expect(find.text('Rain'), findsOneWidget);
    expect(find.text('18° / 12°'), findsOneWidget);

    await tester.tap(find.text('Show on the lights').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final playback =
        AppScope.of(tester.element(find.byType(WeatherScreen))).playback;
    expect(playback.effect.name, 'Weather in Milan');
    expect(playback.isPlaying, isTrue);
    // Its player, from the mini player, offers no favourite star.
    await tester.tap(find.descendant(
        of: find.byType(MiniPlayer), matching: find.text('Weather in Milan')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Weather in Milan'), findsWidgets);
    expect(find.byTooltip('Add to favorites'), findsNothing);
    await tester.pageBack();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await playback.stop();
    await tester.pump(const Duration(seconds: 2));

    // Remembered, and can be changed.
    await tester.pageBack();
    await tester.pumpAndSettle();
    await openWeather(tester);
    expect(find.text('Milan, Lombardy, Italy'), findsOneWidget);
    await tester.tap(find.text('Change'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('weather lights say so when offline', (tester) async {
    final weather = _FakeWeather(online: false);
    await _pumpApp(tester, weather: weather);
    await openWeather(tester);
    await tester.enterText(find.byType(TextField), 'Milan');
    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();
    expect(find.textContaining("Couldn't get the weather"), findsOneWidget);
  });

  testWidgets('light memory: watch, repeat, a wrong colour ends the game',
      (tester) async {
    await _pumpApp(tester);
    await openBirthday(tester);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Light memory'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Light memory'), findsOneWidget);
    // The same draw as the screen's, to know the colours.
    final expected = SimonGame(math.Random(3));
    unawaited(tester.state<NavigatorState>(find.byType(Navigator).first).push(
        MaterialPageRoute<void>(builder: (_) => const SimonScreen(seed: 3))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Watch the lights…'), findsOneWidget);

    Future<void> watch(int colours) async {
      for (var i = 0; i < colours * 3 + 3; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
    }

    String name(SimonColor color) => switch (color) {
          SimonColor.red => 'Red',
          SimonColor.green => 'Green',
          SimonColor.blue => 'Blue',
          SimonColor.yellow => 'Yellow',
        };

    expected.nextRound();
    await watch(1);
    expect(find.text('Your turn!'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel(name(expected.sequence[0])));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Round 2'), findsOneWidget);

    expected.nextRound();
    await watch(2);
    expect(find.text('Your turn!'), findsOneWidget);
    final wrong =
        SimonColor.values.firstWhere((c) => c != expected.sequence[0]);
    await tester.tap(find.bySemanticsLabel(name(wrong)));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Oops! You remembered 1 round.'), findsOneWidget);
    expect(find.text('New record!'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('calm breathing: choose, breathe with the circle, done',
      (tester) async {
    await _pumpApp(tester);
    await tester.scrollUntilVisible(
      find.text('Calm breathing'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Calm breathing'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Calm breathing'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Square breathing'));
    await tester.tap(find.text('1 min'));
    await tester.pump();
    await tester.tap(find.text('Start'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Breathe in…'), findsOneWidget);
    expect(find.text('1:04'), findsOneWidget);
    final playback =
        AppScope.of(tester.element(find.byType(BreathingScreen))).playback;
    playback.player!.advance(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Hold…'), findsOneWidget);
    expect(find.text('0:59'), findsOneWidget);

    playback.player!.advance(const Duration(seconds: 64));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(seconds: 2));
    expect(find.textContaining('Well done'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
  });

  testWidgets('a pomodoro shows the round and the time left', (tester) async {
    await _pumpApp(tester);
    await tester.scrollUntilVisible(
      find.text('Light timers'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Light timers'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Light timers'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('2 rounds'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.text('2 rounds'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2 rounds'));
    await tester.pump();
    await tester.tap(find.descendant(
        of: find.ancestor(
            of: find.text('Pomodoro'), matching: find.byType(ListTile)),
        matching: find.text('Start')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Focus: round 1 of 2'), findsOneWidget);
    expect(find.textContaining(RegExp(r'^2[45]:\d\d$')), findsOneWidget);

    final playback =
        AppScope.of(tester.element(find.byType(PomodoroRunningScreen)))
            .playback;
    playback.player!.advance(const Duration(minutes: 25));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Break: stretch and drink some water'), findsOneWidget);

    await tester.tap(find.text('Stop'));
    await tester.pump();
    expect(find.text('Well done, all rounds finished!'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
  });

  testWidgets('a choose-your-path story waits for the choice and follows it',
      (tester) async {
    await _pumpApp(tester);
    await tester.tap(find.text('Stories'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose your path'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('The Lost Star'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('A little star has slipped'), findsOneWidget);
    expect(find.text('The quiet lake'), findsNothing);

    final playback =
        AppScope.of(tester.element(find.byType(PathStoryScreen))).playback;
    playback.player!.advance(const Duration(seconds: 18));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('The dark forest'), findsOneWidget);
    await tester.tap(find.text('The quiet lake'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('At the lake'), findsOneWidget);

    playback.player!.advance(const Duration(seconds: 18));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Ask the frog'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('The frog croaks'), findsOneWidget);

    // The ending plays once, then the lights go back.
    playback.player!.advance(const Duration(seconds: 21));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('The end'), findsOneWidget);
    expect(find.text('Try another path'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
  });

  Future<void> openFun(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.text('Parties and games'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Parties and games'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Parties and games'));
    await tester.pumpAndSettle();
  }

  testWidgets('the advent calendar opens today\'s door, not tomorrow\'s',
      (tester) async {
    await _pumpApp(tester, clock: () => DateTime(2026, 12, 5, 18));
    await openFun(tester);
    await tester.tap(find.text('Advent calendar'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Day 6'));
    await tester.pump();
    expect(
        find.textContaining('This door opens on December 6'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));

    await tester.tap(find.bySemanticsLabel('Day 5'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Day 5'), findsWidgets);
    final playback =
        AppScope.of(tester.element(find.byType(AdventScreen))).playback;
    expect(playback.effect.name, 'Day 5');
    playback.player!.advance(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('The northern lights are glowing!'), findsOneWidget);
    await playback.stop();
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('a countdown counts the sleeps and shows them on the lights',
      (tester) async {
    await _pumpApp(tester, clock: () => DateTime(2026, 10, 16, 9));
    await openFun(tester);
    await tester.tap(find.text('How many sleeps?'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No countdowns yet'), findsOneWidget);
    await tester.tap(find.text('New countdown'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Grandma');
    await tester.pump();
    // A week ahead by default.
    expect(find.text('October 23, 2026'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('7 sleeps to Grandma!'), findsOneWidget);

    await tester.tap(find.byTooltip('Show on the lights'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final playback =
        AppScope.of(tester.element(find.byType(CountdownsScreen))).playback;
    expect(playback.effect.name, '7 sleeps to Grandma!');
    await playback.stop();
    await tester.pump(const Duration(seconds: 2));

    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('7 sleeps to Grandma!'), findsNothing);
  });

  Future<void> answerGrownUpSum(WidgetTester tester,
      {bool right = true}) async {
    final question = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .firstWhere((t) => t.contains(' + '));
    final match = RegExp(r'(\d+) \+ (\d+)').firstMatch(question)!;
    final sum = int.parse(match[1]!) + int.parse(match[2]!);
    await tester.enterText(
        find.descendant(
            of: find.byType(AlertDialog), matching: find.byType(TextField)),
        '${right ? sum : sum + 1}');
    await tester.tap(find.widgetWithText(FilledButton, 'Exit'));
    await tester.pumpAndSettle();
  }

  testWidgets('kids mode: big buttons, no way out without a grown-up',
      (tester) async {
    await _pumpApp(tester);
    await tester.scrollUntilVisible(find.text('Kids mode'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.text('Kids mode'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kids mode'));
    await tester.pumpAndSettle();
    // Flashing effects cannot be chosen.
    for (var i = 0;
        i < 20 && find.text('Has flashes: not offered').evaluate().isEmpty;
        i++) {
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
      await tester.pumpAndSettle();
    }
    expect(find.text('Has flashes: not offered'), findsWidgets);
    await tester.scrollUntilVisible(find.text('Start kids mode'), -300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Start kids mode'));
    await tester.pumpAndSettle();
    expect(find.byType(KidsModeScreen), findsOneWidget);

    await tester.tap(find
        .descendant(of: find.byType(GridView), matching: find.byType(InkWell))
        .first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final playback =
        AppScope.of(tester.element(find.byType(KidsModeScreen))).playback;
    expect(playback.isPlaying, isTrue);
    expect(find.byType(MiniPlayer), findsNothing);

    // Back does nothing.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(KidsModeScreen), findsOneWidget);

    await tester.tap(find.text('Stop'));
    await tester.pump(const Duration(seconds: 2));
    expect(playback.isPlaying, isFalse);

    await tester.tap(find.byTooltip('Grown-ups: exit'));
    await tester.pumpAndSettle();
    await answerGrownUpSum(tester, right: false);
    expect(find.text("That's not right."), findsOneWidget);
    await answerGrownUpSum(tester);
    expect(find.byType(KidsModeScreen), findsNothing);
    expect(
        AppScope.of(tester.element(find.byType(KidsSetupScreen)))
            .preferences
            .kidsLocked,
        isFalse);
  });

  testWidgets('kids mode is still on when LumiFX opens again', (tester) async {
    final bridge = BridgeController(store: InMemoryCredentialStore());
    await tester.runAsync(bridge.initialize);
    final preferences = PreferencesController(store: InMemoryKeyValueStore());
    await preferences.setOnboardingDone();
    await preferences.setKidsLocked(true);
    await preferences.load();
    await tester.pumpWidget(LumiFxApp(
      bridge: bridge,
      discovery: _FakeDiscovery(),
      preferences: preferences,
      audioInput: FakeAudioInput(),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(KidsModeScreen), findsOneWidget);
  });

  testWidgets('kids mode offers the games a grown-up kept', (tester) async {
    final bridge = BridgeController(store: InMemoryCredentialStore());
    await tester.runAsync(bridge.initialize);
    final preferences = PreferencesController(store: InMemoryKeyValueStore());
    await preferences.setOnboardingDone();
    await preferences.setKidsLocked(true);
    await preferences.load();
    await tester.pumpWidget(LumiFxApp(
      bridge: bridge,
      discovery: _FakeDiscovery(),
      preferences: preferences,
      audioInput: FakeAudioInput(),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Count the lights'), findsOneWidget);
    expect(find.text('Colours in another language'), findsOneWidget);
    expect(find.text('Light memory'), findsOneWidget);
    expect(find.text('Calm breathing'), findsOneWidget);

    await tester.tap(find.text('Light piano'));
    await tester.pumpAndSettle();
    expect(find.byType(LightPianoScreen), findsOneWidget);
    await tester.tap(find.text('E'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(MiniPlayer), findsNothing,
        reason: 'no way to the player from a kids mode game');
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(KidsModeScreen), findsOneWidget);

    await preferences.setKidsActivities(['counting']);
    await tester.pumpAndSettle();
    expect(find.text('Count the lights'), findsOneWidget);
    expect(find.text('Light piano'), findsNothing);
  });

  testWidgets('the mini-player leads back to a timer or a game screen',
      (tester) async {
    await _pumpApp(tester);
    await tester.scrollUntilVisible(
      find.text('Light timers'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Light timers'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Light timers'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Start').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(TimerRunningScreen), findsOneWidget);
    await tester.pageBack();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pageBack();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.descendant(
        of: find.byType(MiniPlayer), matching: find.text('Brush your teeth')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(TimerRunningScreen), findsOneWidget);
    expect(find.textContaining(RegExp(r'^[12]:\d\d$')), findsOneWidget);
    await tester.tap(find.text('Stop'));
    await tester.pump(const Duration(seconds: 2));
    // Back on the home, where the mini-player was tapped.
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    await openBirthday(tester);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Statues'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.text('Statues'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Statues'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pageBack();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.descendant(
        of: find.byType(MiniPlayer), matching: find.text('Statues')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Dance!'), findsOneWidget,
        reason: 'the running game, not its rules');
    await tester.tap(find.text('Stop'));
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('a picture routine fills the lamps and earns a star',
      (tester) async {
    await _pumpApp(tester, clock: () => DateTime(2026, 10, 18, 7, 30));
    await tester.scrollUntilVisible(find.text('Morning and evening'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.text('Morning and evening'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Morning and evening'));
    await tester.pumpAndSettle();
    expect(find.text('No stars yet'), findsOneWidget);

    // Only two steps, chosen by a grown-up.
    await tester.tap(find.byTooltip('Choose the steps').first);
    await tester.pumpAndSettle();
    for (final step in [
      'Wash your face',
      'Get dressed',
      'Breakfast',
      'Shoes and backpack',
    ]) {
      await tester.tap(find.text(step));
      await tester.pump();
    }
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Start').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('0 of 2 done'), findsOneWidget);
    final playback =
        AppScope.of(tester.element(find.byType(RoutineScreen))).playback;
    expect(playback.isPlaying, isTrue);

    await tester.tap(find.bySemanticsLabel('Get up'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('1 of 2 done'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Brush your teeth'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Well done! You earned a star!'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    expect(find.text('1 star'), findsOneWidget);
    // Next to the morning routine, and in the week.
    expect(find.byIcon(Icons.star), findsNWidgets(2));
  });

  testWidgets('a lullaby plays its tune and then fades the lights out',
      (tester) async {
    await _pumpApp(tester);
    await tester.scrollUntilVisible(find.text('Lullabies'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.text('Lullabies'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lullabies'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Just once'));
    await tester.pump();
    await tester.tap(find.text("Brahms's Lullaby"));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final playback =
        AppScope.of(tester.element(find.byType(MusicBoxScreen))).playback;
    expect(playback.isPlaying, isTrue);
    expect(playback.soundscape.melody?.id, 'brahms');
    expect(playback.soundscape.melodyTimes, 1);
    expect(playback.sleepTimer, isNotNull, reason: 'then the lights fade');
    expect(find.byTooltip('Stop'), findsOneWidget);
    await tester.tap(find.byTooltip('Stop'));
    await tester.pump(const Duration(seconds: 2));
    expect(playback.isPlaying, isFalse);
  });

  testWidgets('the story maker tells the story the child chose',
      (tester) async {
    await _pumpApp(tester);
    await tester.scrollUntilVisible(find.text('Story maker'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.text('Story maker'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Story maker'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Owl'));
    await tester.pump();
    expect(find.widgetWithText(TextField, 'Momo'), findsOneWidget,
        reason: 'the hero brings its own name');
    await tester.enterText(find.byType(TextField), 'Sofia');
    await tester.tap(find.text('Kitten'));
    await tester.pump();
    expect(find.widgetWithText(TextField, 'Sofia'), findsOneWidget,
        reason: 'a name the child typed stays');
    for (final choice in ['Cloud castle', 'A treasure map', 'Tell the story']) {
      await tester.scrollUntilVisible(find.text(choice), 200,
          scrollable: find.byType(Scrollable).first);
      await tester.ensureVisible(find.text(choice));
      await tester.pumpAndSettle();
      await tester.tap(find.text(choice));
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 500));
    final playback =
        AppScope.of(tester.element(find.byType(TaleMakerScreen))).playback;
    expect(playback.isPlaying, isTrue);
    expect(playback.effect.name, 'The story of Sofia');
    expect(find.textContaining('Once upon a time there was Sofia, a curious'),
        findsOneWidget);
    playback.player!.advance(const Duration(seconds: 31));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Sofia follows the map'), findsOneWidget);
    playback.player!.advance(const Duration(seconds: 30));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('The end'), findsOneWidget);
    await tester.tap(find.text('Save to My stories'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Saved in My stories'), findsOneWidget);
    final saved = AppScope.of(tester.element(find.byType(TaleMakerScreen)))
        .preferences
        .userStories
        .single;
    expect(saved.name, 'The story of Sofia');
    expect(saved.narration.first.$2, startsWith('Once upon a time'));
    await tester.tap(find.text('Another story'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(playback.isPlaying, isTrue);
    expect(playback.effect.name, 'The story of Sofia');
    await playback.stop();
    await tester.pumpAndSettle();
  });

  testWidgets('counting the lights: the blinks, the number, the voice',
      (tester) async {
    final speaker = _RecordingSpeaker();
    await _pumpApp(tester, speaker: speaker);
    await tester.scrollUntilVisible(find.text('Parties and games'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.text('Parties and games'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Parties and games'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.text('Colours in another language'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Count the lights'), findsOneWidget);

    unawaited(tester.state<NavigatorState>(find.byType(Navigator).first).push(
        MaterialPageRoute<void>(
            builder: (_) => const CountingScreen(seed: 7))));
    await tester.pumpAndSettle();
    final target = (CountingGame(math.Random(7))..next()).target;
    await tester.tap(find.text('Start'));
    await tester.pump();
    expect(find.text('Watch and count…'), findsOneWidget);
    // The answers wait until the blinks are over.
    await tester.tap(find.text('1'));
    await tester.pump(const Duration(seconds: 8));
    expect(find.text('How many?'), findsOneWidget);
    final wrong = target == 1 ? 2 : 1;
    await tester.tap(find.text('$wrong'));
    await tester.pump();
    expect(find.text("Not quite: let's count again"), findsOneWidget);
    await tester.pump(const Duration(seconds: 8));
    await tester.tap(find.text('$target'));
    await tester.pump();
    expect(find.text('Yes, $target!'), findsOneWidget);
    expect(find.textContaining('One right answer'), findsOneWidget);
    expect(find.textContaining('New record!'), findsOneWidget);
    expect(
        AppScope.of(tester.element(find.byType(CountingScreen)))
            .preferences
            .countingBest,
        1);
    expect(speaker.spoken.last, ('$target', 'en-US'));
    final playback =
        AppScope.of(tester.element(find.byType(CountingScreen))).playback;
    await tester.pageBack();
    await tester.pump(const Duration(seconds: 2));
    await playback.stop();
    await tester.pumpAndSettle();
  });

  testWidgets('the colours are said in the language to learn', (tester) async {
    final speaker = _RecordingSpeaker();
    await _pumpApp(tester, speaker: speaker);
    unawaited(tester.state<NavigatorState>(find.byType(Navigator).first).push(
        MaterialPageRoute<void>(
            builder: (_) => const ColourWordsScreen(seed: 3))));
    await tester.pumpAndSettle();
    final playback =
        AppScope.of(tester.element(find.byType(ColourWordsScreen))).playback;
    // English speakers start with Spanish.
    expect(find.text('rojo'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Next colour'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Next colour'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('naranja'), findsOneWidget);
    expect(speaker.spoken.last, ('naranja', 'es-ES'));
    expect(LearnColour.of(playback.effect), LearnColour.orange);

    await tester.scrollUntilVisible(find.text('Italiano'), -200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Italiano'));
    await tester.pump();
    expect(find.text('arancione'), findsOneWidget);
    expect(speaker.spoken.last, ('arancione', 'it-IT'));
    expect(
        AppScope.of(tester.element(find.byType(ColourWordsScreen)))
            .preferences
            .learnLanguage,
        'it',
        reason: 'chosen again next time');

    await tester.tap(find.text('Quiz'));
    await tester.pump();
    final quiz = ColourQuiz(math.Random(3))..next();
    expect(speaker.spoken.last, (quiz.target.word('it'), 'it-IT'));
    expect(find.text('Which colour is it?'), findsOneWidget);
    final wrong = quiz.choices.firstWhere((c) => c != quiz.target);
    await tester.scrollUntilVisible(
        find.bySemanticsLabel(wrong.word('en')), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.bySemanticsLabel(wrong.word('en')));
    await tester.pump();
    expect(find.text('Try again'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel(quiz.target.word('en')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Well done!'), findsOneWidget);
    expect(LearnColour.of(playback.effect), quiz.target);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Which colour is it?'), findsOneWidget,
        reason: 'then the next word');
    await playback.stop();
    await tester.pumpAndSettle();
  });

  testWidgets('two paints mix on the lamps, then the quiz', (tester) async {
    final speaker = _RecordingSpeaker();
    await _pumpApp(tester, speaker: speaker);
    unawaited(tester.state<NavigatorState>(find.byType(Navigator).first).push(
        MaterialPageRoute<void>(
            builder: (_) => const ColourMixingScreen(seed: 5))));
    await tester.pumpAndSettle();
    final playback =
        AppScope.of(tester.element(find.byType(ColourMixingScreen))).playback;
    expect(find.text('Pick a paint'), findsOneWidget);
    await tester.tap(find.text('yellow'));
    await tester.pump();
    expect(find.text('Now pick one to mix it with'), findsOneWidget);
    // White makes no colour with yellow.
    await tester.tap(find.text('white'));
    await tester.pump();
    expect(find.text('Now pick one to mix it with'), findsOneWidget);
    await tester.tap(find.text('blue'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('yellow + blue = green'), findsOneWidget);
    expect(
        ColourMix.of(playback.effect), (LearnColour.yellow, LearnColour.blue));
    await tester.pump(const Duration(seconds: 4));
    expect(speaker.spoken.last, ('green', 'en-US'));

    // The mini-player leads back here.
    expect(
        (routeForPlaying(playback.effect) as MaterialPageRoute<void>)
            .builder(tester.element(find.byType(ColourMixingScreen))),
        isA<ColourMixingScreen>());

    await tester.tap(find.text('Quiz'));
    await tester.pump();
    final quiz = MixQuiz(math.Random(5))..next();
    final (a, b) = quiz.paints;
    expect(find.text('What do ${a.word('en')} and ${b.word('en')} make?'),
        findsOneWidget);
    final wrong = quiz.choices.firstWhere((c) => c != quiz.target);
    await tester.tap(find.text(wrong.word('en')));
    await tester.pump();
    expect(find.text('Try again'), findsOneWidget);
    await tester.tap(find.text(quiz.target.word('en')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Well done!'), findsOneWidget);
    expect(ColourMix.of(playback.effect), (a, b));
    await tester.pump(const Duration(seconds: 6));
    expect(find.text('Well done!'), findsNothing, reason: 'then the next pair');
    await playback.stop();
    await tester.pumpAndSettle();
  });

  testWidgets('the nap light glows amber, then green when the rest is over',
      (tester) async {
    await _pumpApp(tester);
    await tester.scrollUntilVisible(find.text('Nap light'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.text('Nap light'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nap light'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('20 min'));
    await tester.pump();
    await tester.tap(find.text('Start the nap'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final playback =
        AppScope.of(tester.element(find.byType(NapLightScreen))).playback;
    expect(NapLight.restOf(playback.effect), const Duration(minutes: 20));
    expect(find.text('Rest until the light turns green'), findsOneWidget);
    expect(find.text('Green in 20 minutes'), findsOneWidget);

    playback.player!.advance(const Duration(minutes: 20, seconds: 30));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Green: time to get up!'), findsOneWidget);

    // The mini-player leads back here.
    expect(
        (routeForPlaying(playback.effect) as MaterialPageRoute<void>)
            .builder(tester.element(find.byType(NapLightScreen))),
        isA<NapLightScreen>());
    await tester.tap(find.text('Stop'));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Start the nap'), findsOneWidget);

    // The rest chosen comes back next time.
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nap light'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '20 min'))
            .selected,
        isTrue);
  });

  testWidgets('the noise light turns red when it gets too loud',
      (tester) async {
    // Two seconds of shouting next to the phone.
    const rate = 44100;
    final loud = ByteData(rate * 4);
    for (var i = 0; i < rate * 2; i++) {
      loud.setInt16(
          i * 2,
          (0.5 * 32767 * math.sin(2 * math.pi * 440 * i / rate)).round(),
          Endian.little);
    }
    final microphone = FakeAudioInput(pcm: loud.buffer.asUint8List());
    await _pumpApp(tester, audioInput: microphone);
    unawaited(tester.state<NavigatorState>(find.byType(Navigator).first).push(
        MaterialPageRoute<void>(builder: (_) => const NoiseLightScreen())));
    await tester.pumpAndSettle();
    final playback =
        AppScope.of(tester.element(find.byType(NoiseLightScreen))).playback;

    await tester.tap(find.text('Start listening'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(microphone.started, isTrue);
    expect(NoiseZone.of(playback.effect), NoiseZone.tooLoud);
    expect(find.text('Too loud!'), findsOneWidget);
    expect(find.text('Too loud once'), findsOneWidget);

    await tester.tap(find.text('Stop'));
    await tester.pump(const Duration(seconds: 2));
    expect(microphone.stopped, isTrue);
    expect(playback.isPlaying, isFalse);
    expect(find.text('Start listening'), findsOneWidget);

    // Leaving the screen stops listening, and the lamps.
    await tester.tap(find.text('Start listening'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(microphone.startCount, 2);
    await tester.pageBack();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(NoiseLightScreen), findsNothing);
    expect(microphone.stopped, isTrue);
    expect(playback.isPlaying, isFalse);
    await tester.pumpAndSettle();
  });

  testWidgets('the monster spray chases them away and leaves a guardian light',
      (tester) async {
    await _pumpApp(tester);
    await tester.scrollUntilVisible(find.text('Monster spray'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.text('Monster spray'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Monster spray'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start'));
    await tester.pump(const Duration(milliseconds: 500));
    final playback =
        AppScope.of(tester.element(find.byType(MonsterSprayScreen))).playback;
    expect(MonsterHunt.isHunting(playback.effect), isTrue);
    expect(find.text('5 monsters left'), findsOneWidget);
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.text('Spray!'));
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('One monster left'), findsOneWidget);
    await tester.tap(find.text('Spray!'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('All gone! The room is safe.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(MonsterHunt.isGuardian(playback.effect), isTrue);
    expect(playback.sleepTimer, const Duration(minutes: 30));
    await tester.tap(find.text('15 min'));
    await tester.pump();
    expect(playback.sleepTimer, const Duration(minutes: 15));
    await playback.stop();
    playback.setSleepTimer(null);
    await tester.pumpAndSettle();
  });

  testWidgets('cinema mode dims for the film and brings the lights back',
      (tester) async {
    await _pumpApp(tester);
    await tester.scrollUntilVisible(find.text('Cinema mode'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.text('Cinema mode'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cinema mode'));
    await tester.pumpAndSettle();
    final playback =
        AppScope.of(tester.element(find.byType(CinemaScreen))).playback;
    await tester.tap(find.text('Start the film'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(Cinema.phaseOf(playback.effect), CinemaPhase.film);
    expect(playback.effect.id, endsWith(':glow'));
    expect(find.text('Enjoy the film'), findsOneWidget);
    await tester.tap(find.text('Soft glow during the film'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(playback.effect.id, endsWith(':dark'));

    await tester.tap(find.text('Intermission'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(Cinema.phaseOf(playback.effect), CinemaPhase.intermission);
    expect(find.text('Back to the film'), findsOneWidget);

    await tester.tap(find.text('End of the film'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(Cinema.phaseOf(playback.effect), CinemaPhase.end);
    expect(find.text('The lights are coming back'), findsOneWidget);
    playback.player!.advance(Cinema.end('x').cycleLength);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(playback.status, PlaybackStatus.idle,
        reason: 'then the room goes back to how it was');
    await tester.pumpAndSettle();
  });

  testWidgets('a link is written on an NFC sticker', (tester) async {
    final nfc = _FakeNfc();
    await _pumpApp(tester, nfc: nfc);
    await tester.scrollUntilVisible(find.text('NFC stickers'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.text('NFC stickers'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('NFC stickers'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Start bedtime'), 200,
        scrollable: find.byType(Scrollable).first);
    final bedtime = find.ancestor(
        of: find.text('Start bedtime'), matching: find.byType(ListTile));
    await tester.tap(find.descendant(
        of: bedtime, matching: find.byTooltip('Write on a sticker')));
    await tester.pump();
    expect(
        find.text('Hold a sticker near the back of the phone'), findsOneWidget);
    expect(nfc.written, ['lumifx://app/bedtime']);
    // Cancelled: nothing to say.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(
        find.text('Hold a sticker near the back of the phone'), findsNothing);

    await tester.tap(find.descendant(
        of: bedtime, matching: find.byTooltip('Write on a sticker')));
    await tester.pump();
    nfc.waiting!.complete(NfcWriteResult.written);
    await tester.pumpAndSettle();
    expect(
        find.text('Hold a sticker near the back of the phone'), findsNothing);
    expect(find.text('Sticker ready: touch it with the phone to start'),
        findsOneWidget);
  });

  testWidgets('NFC switched off, or missing, is explained', (tester) async {
    final off = _FakeNfc(enabled: false);
    await _pumpApp(tester, nfc: off);
    unawaited(tester.state<NavigatorState>(find.byType(Navigator).first).push(
        MaterialPageRoute<void>(builder: (_) => const NfcStickersScreen())));
    await tester.pumpAndSettle();
    expect(find.text('NFC is off'), findsOneWidget);
    expect(find.byTooltip('Write on a sticker'), findsNothing);
    await tester.tap(find.text('Turn on'));
    expect(off.settingsOpened, isTrue);
    // Back from the settings with NFC on.
    off.enabled = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('NFC is off'), findsNothing);
    expect(find.byTooltip('Write on a sticker'), findsWidgets);
  });

  testWidgets('a phone without NFC is told how else to do it', (tester) async {
    await _pumpApp(tester, nfc: _FakeNfc(available: false));
    unawaited(tester.state<NavigatorState>(find.byType(Navigator).first).push(
        MaterialPageRoute<void>(builder: (_) => const NfcStickersScreen())));
    await tester.pumpAndSettle();
    expect(find.textContaining('This phone cannot write NFC stickers'),
        findsOneWidget);
    expect(find.byTooltip('Write on a sticker'), findsNothing);
    expect(find.byTooltip('Copy link'), findsWidgets);
  });

  testWidgets('notification lights: access, an app and its colour',
      (tester) async {
    final platform = _FakeNotificationLights();
    await _pumpApp(tester, notificationLights: platform);
    expect(platform.configured, [null], reason: 'nothing to flash yet');
    unawaited(tester.state<NavigatorState>(find.byType(Navigator).first).push(
        MaterialPageRoute<void>(
            builder: (_) => const NotificationLightsScreen())));
    await tester.pumpAndSettle();
    expect(find.text('Allow LumiFX to see notifications'), findsOneWidget);
    await tester.tap(find.text('Allow'));
    expect(platform.accessAsked, isTrue);
    platform.access = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Allow LumiFX to see notifications'), findsNothing);

    expect(find.text('No apps chosen yet'), findsOneWidget);
    await tester.tap(find.text('Add an app'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'whats');
    await tester.pump();
    expect(find.text('Ring'), findsNothing);
    await tester.tap(find.text('WhatsApp'));
    await tester.pumpAndSettle();
    expect(find.text('Colour for WhatsApp'), findsOneWidget);
    await tester.tap(find
        .descendant(
            of: find.byType(AlertDialog), matching: find.byType(InkWell))
        .at(1));
    await tester.pumpAndSettle();
    final preferences =
        AppScope.of(tester.element(find.byType(NotificationLightsScreen)))
            .preferences;
    final settings = preferences.notificationLights;
    expect(settings.enabled, isTrue);
    expect(settings.rules.single.package, 'com.whatsapp');
    expect(settings.rules.single.color, '#0A84FF');
    expect(find.text('WhatsApp'), findsOneWidget);
    await tester.tap(find.byTooltip('Remove'));
    await tester.pumpAndSettle();
    expect(preferences.notificationLights.rules, isEmpty);
  });

  testWidgets('on iPhone the screen-off setting tells what iOS allows',
      (tester) async {
    await _pumpApp(tester, liveActivity: _FakeLiveActivity());
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.text('Keep playing with the screen off'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.textContaining('Effects with sounds go on when the iPhone'),
        findsOneWidget);
  });

  testWidgets('a secret message is flashed in Morse, letter by letter',
      (tester) async {
    await _pumpApp(tester);
    unawaited(tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .push(MaterialPageRoute<void>(builder: (_) => const MorseScreen())));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'hi');
    await tester.pump();
    await tester.tap(find.text('Send with the lights'));
    await tester.pump(const Duration(milliseconds: 500));
    final playback =
        AppScope.of(tester.element(find.byType(MorseScreen))).playback;
    expect(MorseMessage.of(playback.effect)?.$1.text, 'HI');
    playback.player!.advance(const Duration(milliseconds: 1100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('H  ....'), findsOneWidget);
    // H takes seven units, then three dark: I starts 3.5 s after H.
    playback.player!.advance(const Duration(milliseconds: 3500));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('I  ..'), findsOneWidget);
    await playback.stop();
    await tester.pumpAndSettle();
    expect(find.text('.... ..'), findsOneWidget, reason: 'the whole code');
  });

  testWidgets('hot and cold: warmer, colder and found it', (tester) async {
    final speaker = _RecordingSpeaker();
    await _pumpApp(tester, speaker: speaker);
    unawaited(tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .push(MaterialPageRoute<void>(builder: (_) => const HotColdScreen())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start'));
    await tester.pump(const Duration(milliseconds: 500));
    final playback =
        AppScope.of(tester.element(find.byType(HotColdScreen))).playback;
    expect(find.text('Cold'), findsOneWidget);
    expect(playback.effect.id, HotCold.effect(HotCold.start, 'x').id);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Warmer'));
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(find.text('Warm'), findsOneWidget);
    expect(speaker.spoken.last, ('Warm', 'en-US'));
    await tester.tap(find.text('Colder'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(playback.effect.id, HotCold.effect(4, 'x').id);
    await tester.tap(find.text('Found it!'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(playback.effect.id, HotCold.found('x').id);
    expect(speaker.spoken.last.$1, 'Found it!');
    await tester.tap(find.text('Play again'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Cold'), findsOneWidget);
    await playback.stop();
    await tester.pumpAndSettle();
  });

  testWidgets('the light piano plays notes and teaches a tune', (tester) async {
    await _pumpApp(tester);
    unawaited(tester.state<NavigatorState>(find.byType(Navigator).first).push(
        MaterialPageRoute<void>(builder: (_) => const LightPianoScreen())));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('E'));
    await tester.pump(const Duration(milliseconds: 500));
    final playback =
        AppScope.of(tester.element(find.byType(LightPianoScreen))).playback;
    expect(isPianoEffect(playback.effect), isTrue);
    expect(playback.isPlaying, isTrue);

    await tester.tap(find.text('Learn a song'));
    await tester.pump();
    expect(find.textContaining('0 of'), findsOneWidget);
    // The first tune offered, and its first key.
    final first = PianoLesson(pianoSongs.first).next!;
    Finder key(int index) {
      final label = pianoNoteName('en', index);
      // Two keys are C: the low one first.
      return find.bySemanticsLabel(label).at(index == 7 ? 1 : 0);
    }

    await tester.tap(key(first == 3 ? 4 : 3));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('0 of'), findsOneWidget, reason: 'not yet');
    await tester.tap(key(first));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('1 of'), findsOneWidget);
    await playback.stop();
    await tester.pumpAndSettle();
  });

  testWidgets(
      'the light piano plays a tune to repeat, one note longer each time',
      (tester) async {
    final sound = FakeSoundPlayer();
    await _pumpApp(tester, sound: sound);
    unawaited(tester.state<NavigatorState>(find.byType(Navigator).first).push(
        MaterialPageRoute<void>(
            builder: (_) => const LightPianoScreen(seed: 4))));
    await tester.pumpAndSettle();
    final playback =
        AppScope.of(tester.element(find.byType(LightPianoScreen))).playback;
    final tune = (PianoEcho(math.Random(4))..start()).keys;
    Finder key(int index) => find
        .bySemanticsLabel(pianoNoteName('en', index))
        .at(index == 7 ? 1 : 0);

    await tester.tap(find.text('Repeat after me'));
    await tester.pump();
    expect(find.text('Listen…'), findsOneWidget);
    expect(find.text('A tune of 3 notes'), findsOneWidget);
    // Keys tapped while the piano plays count for nothing.
    await tester.tap(key(tune.first));
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Your turn!'), findsOneWidget);
    expect(sound.calls.where((c) => c.startsWith('note')),
        [for (final k in tune) 'note ${pianoKeys[k].midi}']);

    for (final k in tune) {
      await tester.tap(key(k));
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(find.text('Bravo! One more note'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('A tune of 4 notes'), findsOneWidget);
    expect(find.text('Listen…'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    expect(find.text('Your turn!'), findsOneWidget);

    // A wrong key: the same tune again.
    await tester.tap(key((tune.first + 1) % pianoKeys.length));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Oops! Listen again'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('A tune of 4 notes'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await playback.stop();
    await tester.pumpAndSettle();
  });

  testWidgets('the light piano records a tune and plays it back',
      (tester) async {
    final sound = FakeSoundPlayer();
    await _pumpApp(tester, sound: sound);
    unawaited(tester.state<NavigatorState>(find.byType(Navigator).first).push(
        MaterialPageRoute<void>(builder: (_) => const LightPianoScreen())));
    await tester.pumpAndSettle();
    final playback =
        AppScope.of(tester.element(find.byType(LightPianoScreen))).playback;
    await tester.tap(find.text('Record'));
    await tester.pump();
    for (final note in ['E', 'G']) {
      await tester.tap(find.bySemanticsLabel(note));
      await tester.pump(const Duration(milliseconds: 400));
    }
    await tester.tap(find.text('Stop recording'));
    await tester.pump();
    expect(
        sound.calls.where((c) => c.startsWith('note')), ['note 64', 'note 67']);
    await tester.tap(find.text('Play it back'));
    await tester.pump(const Duration(seconds: 2));
    expect(sound.calls.where((c) => c.startsWith('note')),
        ['note 64', 'note 67', 'note 64', 'note 67']);
    await playback.stop();
    await tester.pumpAndSettle();
  });

  testWidgets('each child has a profile with their own stars', (tester) async {
    await _pumpApp(tester);
    unawaited(tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .push(MaterialPageRoute<void>(builder: (_) => const RoutinesScreen())));
    await tester.pumpAndSettle();
    final preferences =
        AppScope.of(tester.element(find.byType(RoutinesScreen))).preferences;
    for (final name in ['Anna', 'Leo']) {
      await tester.tap(find.text('Add a child'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), name);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
    }
    expect(find.widgetWithText(ChoiceChip, 'Anna'), findsOneWidget);
    expect(preferences.activeChild?.name, 'Leo');
    preferences.earnStar('2026-10-18:morning');
    await tester.pump();
    expect(find.text('1 star'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Anna'));
    await tester.pumpAndSettle();
    expect(preferences.activeChild?.name, 'Anna');
    expect(find.text('No stars yet'), findsOneWidget);

    await tester.tap(find.byTooltip('Children'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete').last);
    await tester.pumpAndSettle();
    expect(
        find.text('Remove Leo with their routines and stars?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect([for (final c in preferences.children) c.name], ['Anna']);
  });

  testWidgets('the star shop: a grown-up adds a reward, stars buy it',
      (tester) async {
    await _pumpApp(tester);
    unawaited(tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .push(MaterialPageRoute<void>(builder: (_) => const StarShopScreen())));
    await tester.pumpAndSettle();
    final scope = AppScope.of(tester.element(find.byType(StarShopScreen)));
    final preferences = scope.preferences;
    Future<void> grownUp() async {
      final question = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .firstWhere((t) => t.contains(' + '));
      expect(question, startsWith('To go on'));
      final match = RegExp(r'(\d+) \+ (\d+)').firstMatch(question)!;
      await tester.enterText(
          find.descendant(
              of: find.byType(AlertDialog), matching: find.byType(TextField)),
          '${int.parse(match[1]!) + int.parse(match[2]!)}');
      await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
      await tester.pumpAndSettle();
    }

    expect(find.text('No stars to spend yet'), findsOneWidget);
    await tester.tap(find.text('Add a reward'));
    await tester.pumpAndSettle();
    await grownUp();
    await tester.enterText(find.byType(TextField), 'Ice cream');
    await tester.pump();
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byIcon(Icons.remove));
      await tester.pump();
    }
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(preferences.rewards.single.cost, 2);
    expect(find.textContaining('2 more stars'), findsOneWidget);

    preferences.earnStar('2026-10-17:morning');
    preferences.earnStar('2026-10-17:evening');
    preferences.earnStar('2026-10-18:morning');
    await tester.pumpAndSettle();
    expect(find.text('3 stars to spend'), findsOneWidget);
    await tester.tap(find.text('Get it'));
    await tester.pumpAndSettle();
    await grownUp();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Enjoy: Ice cream!'), findsOneWidget);
    expect(find.text('One star to spend'), findsOneWidget);
    expect(scope.playback.isPlaying, isTrue, reason: 'a party of light');
    await scope.playback.stop();
    await tester.pumpAndSettle();
  });

  testWidgets('the bedtime ritual goes from step to step', (tester) async {
    await _pumpApp(tester);
    await tester.scrollUntilVisible(find.text('Bedtime ritual'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.text('Bedtime ritual'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bedtime ritual'));
    await tester.pumpAndSettle();
    final scope = AppScope.of(tester.element(find.byType(BedtimeRitualScreen)));
    final playback = scope.playback;
    await scope.preferences.addChild('Mia');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Start'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.text('Start'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();
    // The evening routine, then the monster spray, on their own screens.
    expect(find.byType(RoutineScreen), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(MonsterSprayScreen), findsOneWidget);
    await tester.pageBack();
    await tester.pump(const Duration(milliseconds: 500));

    Future<void> finish() async {
      playback.player!.advance(playback.effect.cycleLength);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 500));
    }

    // A minute of calm breathing.
    expect(BreathingPattern.of(playback.effect),
        (BreathingPattern.flowerCandle, 1));
    expect(find.text('Step 3 of 6'), findsOneWidget);
    expect(find.text('Smell the flower…'), findsOneWidget);
    await finish();
    expect(playback.effect.name, 'The story of Mia');
    expect(find.text('Step 4 of 6'), findsOneWidget);

    await finish();
    expect(playback.effect.name, "Brahms's Lullaby");
    expect(find.text('Step 5 of 6'), findsOneWidget);
    await finish();
    expect(MonsterHunt.isGuardian(playback.effect), isTrue);
    expect(playback.sleepTimer, const Duration(minutes: 30));
    expect(find.text('Goodnight!'), findsOneWidget);
    await playback.stop();
    playback.setSleepTimer(null);
    await tester.pumpAndSettle();
  });

  testWidgets('the Halloween party scares whoever walks past the sensor',
      (tester) async {
    await _pumpApp(tester);
    final motion = StreamController<HueMotionEvent>.broadcast();
    addTearDown(motion.close);
    unawaited(tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .push(MaterialPageRoute<void>(
            builder: (_) => HauntedPartyScreen(
                  motion: () => motion.stream,
                  sensors: const [HueMotionSensor(id: '5', name: 'Hallway')],
                ))));
    await tester.pumpAndSettle();
    expect(find.text('Hallway'), findsOneWidget);
    await tester.tap(find.text('Start the party'));
    await tester.pump(const Duration(milliseconds: 500));
    final playback =
        AppScope.of(tester.element(find.byType(HauntedPartyScreen))).playback;
    expect(HauntedParty.isParty(playback.effect), isTrue);
    expect(find.text('Waiting for someone to walk past…'), findsOneWidget);

    motion.add(const HueMotionEvent(sensorId: '9', motion: true));
    await tester.pump();
    expect(find.text('No scares yet'), findsOneWidget, reason: 'another one');
    motion.add(const HueMotionEvent(sensorId: '5', motion: true));
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('One scare'), findsOneWidget);
    motion.add(const HueMotionEvent(sensorId: '5', motion: true));
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('One scare'), findsOneWidget, reason: 'a rest between');
    await tester.tap(find.text('Scare now'));
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('2 scares'), findsOneWidget);
    await tester.tap(find.text('Stop'));
    await tester.pumpAndSettle();
    expect(playback.status, PlaybackStatus.idle);
  });

  testWidgets('a link opens the bedtime ritual, once, not in kids mode',
      (tester) async {
    await _pumpApp(tester);
    Future<void> openLink(String location) async {
      final message = const JSONMethodCodec().encodeMethodCall(
        MethodCall('pushRouteInformation', {'location': location}),
      );
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
          SystemChannels.navigation.name, message, (_) {});
    }

    await openLink('lumifx://app/go/ritual');
    await tester.pumpAndSettle();
    expect(find.byType(BedtimeRitualScreen), findsOneWidget);
    await openLink('lumifx://app/go/ritual');
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(BedtimeRitualScreen), findsNothing,
        reason: 'it was opened only once');

    await openLink('lumifx://app/go/colour-mixing');
    await tester.pumpAndSettle();
    expect(find.byType(ColourMixingScreen), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    final preferences =
        AppScope.of(tester.element(find.byType(HomeScreen))).preferences;
    await preferences.setKidsLocked(true);
    await tester.pumpAndSettle();
    await openLink('lumifx://app/go/piano');
    await tester.pumpAndSettle();
    expect(find.byType(LightPianoScreen), findsNothing);
    await preferences.setKidsLocked(false);
  });

  testWidgets('guess the letter the lamps flash in Morse', (tester) async {
    await _pumpApp(tester);
    unawaited(tester.state<NavigatorState>(find.byType(Navigator).first).push(
        MaterialPageRoute<void>(builder: (_) => const MorseScreen(seed: 2))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guess'));
    await tester.pump();
    await tester.tap(find.text('Flash a letter'));
    await tester.pump(const Duration(milliseconds: 500));
    final playback =
        AppScope.of(tester.element(find.byType(MorseScreen))).playback;
    final quiz = MorseQuiz(math.Random(2))..next();
    expect(MorseMessage.of(playback.effect)?.$1.text, quiz.target);
    expect(find.text('Which letter was it?'), findsOneWidget);
    final wrong = quiz.choices.firstWhere((l) => l != quiz.target);
    await tester.tap(find.widgetWithText(FilledButton, wrong));
    await tester.pump();
    expect(find.text('Try again'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, quiz.target));
    await tester.pump();
    expect(find.textContaining('Well done!'), findsOneWidget);
    expect(find.text('One right answer'), findsOneWidget);
    await playback.stop();
    await tester.pumpAndSettle();
  });

  testWidgets('a grown-up adds a step of their own to a routine',
      (tester) async {
    await _pumpApp(tester);
    unawaited(tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .push(MaterialPageRoute<void>(builder: (_) => const RoutinesScreen())));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Choose the steps').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Add a step'), 100,
        scrollable: find
            .descendant(
                of: find.byType(AlertDialog), matching: find.byType(Scrollable))
            .first);
    await tester.tap(find.text('Add a step'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.descendant(
            of: find.byType(AlertDialog).last,
            matching: find.byType(TextField)),
        'Feed the cat');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Feed the cat'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Start').last, 200,
        scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.text('Start').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start').last);
    await tester.pumpAndSettle();
    expect(find.byType(RoutineScreen), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Feed the cat'), 200,
        scrollable: find.byType(Scrollable).last);
    expect(find.text('Feed the cat'), findsOneWidget);
    final playback =
        AppScope.of(tester.element(find.byType(RoutineScreen))).playback;
    await playback.stop();
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
    await tester.ensureVisible(find.text('Playlists'));
    await tester.pumpAndSettle();
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

  testWidgets('a lumifx:// link opens the player and plays, another stops',
      (tester) async {
    await _pumpApp(tester);
    Future<void> openLink(String location) async {
      final message = const JSONMethodCodec().encodeMethodCall(
        MethodCall('pushRouteInformation', {'location': location}),
      );
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
          SystemChannels.navigation.name, message, (_) {});
    }

    await openLink('lumifx://app/play/aurora');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Aurora'), findsOneWidget, reason: 'the player title');
    expect(find.text('Pause'), findsOneWidget);

    await openLink('/stop');
    await tester.pump();
    expect(find.text('Play'), findsOneWidget);

    // A flashing effect only opens until the warning has been seen.
    await openLink('lumifx://app/play/thunderstorm');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Thunderstorm'), findsOneWidget);
    expect(find.text('Play'), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('voice commands play, start bedtime and stop in any language',
      (tester) async {
    await _pumpApp(tester);
    Future<void> say(String words) async {
      final message = const JSONMethodCodec().encodeMethodCall(
        MethodCall('pushRouteInformation',
            {'location': 'lumifx://app/voice/${Uri.encodeComponent(words)}'}),
      );
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
          SystemChannels.navigation.name, message, (_) {});
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }

    await say('Camino');
    expect(find.text('Fireplace'), findsOneWidget);
    expect(find.text('Pause'), findsOneWidget);

    await say('ferma');
    expect(find.text('Play'), findsOneWidget);

    await say('Kaminfeuer bitte');
    expect(find.text('Pause'), findsOneWidget, reason: 'found inside a phrase');

    await say('nanna');
    // The player opens once bedtime has started.
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Sleeping Dragon'), findsOneWidget);
    expect(find.textContaining('night glow at'), findsOneWidget);

    await say('Stop');
    expect(find.text('Play'), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('in kids mode, the voice plays only the chosen effects',
      (tester) async {
    await _pumpApp(tester);
    final preferences =
        AppScope.of(tester.element(find.byType(HomeScreen))).preferences;
    await preferences.setKidsEffects(['ocean']);
    await preferences.setKidsLocked(true);
    Future<void> say(String words) async {
      final message = const JSONMethodCodec().encodeMethodCall(
        MethodCall('pushRouteInformation',
            {'location': 'lumifx://app/voice/${Uri.encodeComponent(words)}'}),
      );
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
          SystemChannels.navigation.name, message, (_) {});
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }

    final playback =
        AppScope.of(tester.element(find.byType(HomeScreen))).playback;
    await say('Fireplace');
    expect(playback.status, PlaybackStatus.idle, reason: 'not chosen');
    await say('Ocean');
    expect(playback.effect.id, 'ocean');
    expect(playback.isPlaying, isTrue);
    expect(find.text('Pause'), findsNothing,
        reason: 'no player opens over kids mode');
    await say('stop');
    expect(playback.isPlaying, isFalse);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('a link on a cold start waits for the saved scenes to load',
      (tester) async {
    final store = InMemoryKeyValueStore();
    final earlier = PreferencesController(store: store);
    await earlier.setOnboardingDone();
    await earlier.saveUserScene(const UserScene(
      id: 'user:mine',
      name: 'My glow',
      colors: ['#FF0000', '#0000FF'],
    ));
    // The app starts with the preferences still loading.
    final preferences = PreferencesController(store: store);
    final bridge = BridgeController(store: InMemoryCredentialStore());
    await tester.runAsync(bridge.initialize);
    await tester.pumpWidget(LumiFxApp(
      bridge: bridge,
      discovery: _FakeDiscovery(),
      preferences: preferences,
      audioInput: FakeAudioInput(),
    ));
    final message = const JSONMethodCodec().encodeMethodCall(
      const MethodCall(
          'pushRouteInformation', {'location': 'lumifx://app/play/user:mine'}),
    );
    await tester.binding.defaultBinaryMessenger
        .handlePlatformMessage(SystemChannels.navigation.name, message, (_) {});
    await tester.pump();
    expect(find.text('My glow'), findsNothing, reason: 'not loaded yet');

    await preferences.load();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('My glow'), findsOneWidget);
    expect(find.text('Pause'), findsOneWidget);
    await tester.tap(find.text('Pause'));
    await tester.pump();
  });

  testWidgets('the welcome pages show once, on the very first launch',
      (tester) async {
    final store = InMemoryKeyValueStore();
    Future<void> launch() async {
      final bridge = BridgeController(store: InMemoryCredentialStore());
      await tester.runAsync(bridge.initialize);
      final preferences = PreferencesController(store: store);
      await tester.runAsync(preferences.load);
      await tester.pumpWidget(LumiFxApp(
        key: UniqueKey(),
        bridge: bridge,
        discovery: _FakeDiscovery(),
        preferences: preferences,
        audioInput: FakeAudioInput(),
      ));
      await tester.pumpAndSettle();
    }

    await launch();
    expect(find.text('Light that tells stories'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Connect now'), findsOneWidget);
    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();
    expect(find.text('Try it right away'), findsOneWidget);
    expect(find.text('Skip'), findsNothing);
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    expect(find.text('Connect your Hue Bridge'), findsOneWidget,
        reason: 'the home with its bridge banner');
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));

    // Next launch: straight to the home.
    await launch();
    expect(find.text('Light that tells stories'), findsNothing);
  });

  testWidgets('people updating the app never see the welcome pages',
      (tester) async {
    final store = InMemoryKeyValueStore();
    await store.write('lumifx.preferences.v1', '{"favorites": ["ocean"]}');
    final bridge = BridgeController(store: InMemoryCredentialStore());
    await tester.runAsync(bridge.initialize);
    final preferences = PreferencesController(store: store);
    await tester.runAsync(preferences.load);
    await tester.pumpWidget(LumiFxApp(
      bridge: bridge,
      discovery: _FakeDiscovery(),
      preferences: preferences,
      audioInput: FakeAudioInput(),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Light that tells stories'), findsNothing);
    expect(find.text('Favorites'), findsOneWidget);
  });

  testWidgets('a scene of your own is made, played, edited and deleted',
      (tester) async {
    await _pumpApp(tester);
    await tester.tap(find.text('Scenes'));
    await tester.pumpAndSettle();
    // The editor's preview animates, so the screen never settles.
    Future<void> step() async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    await tester.tap(find.text('New scene'));
    await step();
    expect(find.text('Save'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Reading corner');
    // Three colours to start with; add a fourth and change the first.
    await tester.tap(find.bySemanticsLabel('Add a colour'));
    await step();
    await tester.tap(find.bySemanticsLabel('Swatch 9'));
    await step();
    await tester.tap(find.bySemanticsLabel('Colour 1'));
    await step();
    await tester.tap(find.bySemanticsLabel('Swatch 20'));
    await step();
    await tester.tap(find.text('Calm'));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await step();
    await tester.pumpAndSettle();

    // First in the list, labelled as the user's own.
    expect(find.text('Reading corner'), findsOneWidget);
    expect(find.text('My scenes'), findsOneWidget);
    await tester.tap(find.text('Reading corner'));
    await step();
    await tester.tap(find.text('Play'));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byTooltip('Edit scene'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(find.byType(TextField), 'Reading nook');
    await tester.tap(find.text('Save'));
    await step();
    await step();
    expect(find.text('Reading nook'), findsOneWidget,
        reason: 'the player shows the edit, and keeps playing');
    expect(find.text('Pause'), findsOneWidget);

    await tester.tap(find.byTooltip('Edit scene'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byTooltip('Delete'));
    await step();
    await tester.tap(find.text('Delete'));
    await step();
    await tester.pumpAndSettle();
    // Back on the list, without the scene, and nothing plays.
    expect(find.text('Reading nook'), findsNothing);
    expect(find.text('New scene'), findsOneWidget);
    expect(find.byType(MiniPlayer), findsNothing);
  });

  testWidgets('a scene takes its colours from a photo', (tester) async {
    // Two thirds blue, one third orange.
    final photo = (await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder)
        ..drawRect(const Rect.fromLTWH(0, 0, 30, 30),
            Paint()..color = const Color(0xFF0040FF))
        ..drawRect(const Rect.fromLTWH(20, 0, 10, 30),
            Paint()..color = const Color(0xFFFF8000));
      final image = await recorder.endRecording().toImage(30, 30);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return data!.buffer.asUint8List();
    }))!;
    final photos = _FakePhotoPicker(photo);
    await _pumpApp(tester, photos: photos);
    await tester.tap(find.text('Scenes'));
    await tester.pumpAndSettle();
    Future<void> step() async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    await tester.tap(find.text('New scene'));
    await step();
    expect(find.bySemanticsLabel('Colour 3'), findsOneWidget);
    await tester.tap(find.text('From a photo'));
    await step();
    await tester.tap(find.text('Take a photo'));
    await step();
    // The photo is decoded for real, outside the test's fake time.
    await tester.runAsync(() => Future<void>.delayed(
          const Duration(milliseconds: 300),
        ));
    await step();
    expect(photos.asked, [PhotoSource.camera]);
    expect(find.bySemanticsLabel('Colour 1'), findsOneWidget);
    expect(find.bySemanticsLabel('Colour 2'), findsOneWidget);
    expect(find.bySemanticsLabel('Colour 3'), findsNothing,
        reason: 'the two colours of the photo');
    final slots = tester.widgetList<ColorSlot>(find.byType(ColorSlot));
    final first = slots.first.color;
    expect(first.b, greaterThan(first.r), reason: 'blue, the most present');
  });

  testWidgets('a photo that cannot be opened says so', (tester) async {
    await _pumpApp(tester, photos: _FakePhotoPicker(null));
    await tester.tap(find.text('Scenes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New scene'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('From a photo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Choose a photo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining("Couldn't open that photo"), findsOneWidget);
    expect(find.bySemanticsLabel('Colour 3'), findsOneWidget,
        reason: 'the colours stay as they were');
  });

  testWidgets('a story of your own is written, read along and deleted',
      (tester) async {
    await _pumpApp(tester);
    await tester.tap(find.text('Stories'));
    await tester.pumpAndSettle();
    // The editor's preview animates, so the screen never settles.
    Future<void> step() async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    await tester.tap(find.text('New story'));
    await step();
    expect(find.text('No moments yet. Add the first one.'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'The lost star');
    await tester.pump();

    // A first moment: words only, at the very start.
    await tester.scrollUntilVisible(
      find.text('Add a moment'),
      300,
      scrollable: find
          .descendant(
              of: find.byType(StoryEditor), matching: find.byType(Scrollable))
          .first,
    );
    await tester.ensureVisible(find.text('Add a moment'));
    await tester.pump();
    await tester.tap(find.text('Add a moment'));
    await step();
    await tester.tap(find.text('Just words'));
    await tester.pump();
    await tester.enterText(
        find.widgetWithText(TextField, 'Words to read along (optional)'),
        'Once upon a time, a star fell.');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await step();
    expect(find.text('0:00  Just words'), findsOneWidget);
    expect(find.text('Once upon a time, a star fell.'), findsOneWidget);

    // A second one: a spark, five seconds later.
    await tester.ensureVisible(find.text('Add a moment'));
    await tester.pump();
    await tester.tap(find.text('Add a moment'));
    await step();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await step();
    expect(find.text('0:05  Spark'), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('Preview from here').last);
    await tester.pump();
    await tester.tap(find.byTooltip('Preview from here').last);
    await step();

    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await step();
    await tester.pumpAndSettle();

    // First in the list, labelled as the user's own.
    expect(find.text('The lost star'), findsOneWidget);
    expect(find.text('My stories'), findsOneWidget);
    await tester.tap(find.text('The lost star'));
    await step();
    expect(find.text('Once upon a time, a star fell.'), findsOneWidget,
        reason: 'its words to read along');

    await tester.tap(find.byTooltip('Edit story'));
    await step();
    await tester.tap(find.byTooltip('Delete'));
    await step();
    await tester.tap(find.text('Delete'));
    await step();
    await tester.pumpAndSettle();
    expect(find.text('The lost star'), findsNothing);
    expect(find.text('New story'), findsOneWidget);
  });

  testWidgets('a shared link adds the scenes and playlists after asking',
      (tester) async {
    await _pumpApp(tester);
    const bundle = SharedBundle(
      scenes: [
        UserScene(
          id: 'user:theirs',
          name: 'Their scene',
          colors: ['#FF0000', '#0000FF'],
        ),
      ],
      playlists: [
        Playlist(
          id: 'their-playlist',
          name: 'Their playlist',
          effectIds: ['user:theirs', 'ocean'],
        ),
      ],
    );
    final message = const JSONMethodCodec().encodeMethodCall(
      MethodCall('pushRouteInformation', {'location': bundle.link}),
    );
    await tester.binding.defaultBinaryMessenger
        .handlePlatformMessage(SystemChannels.navigation.name, message, (_) {});
    await tester.pumpAndSettle();
    expect(find.text('Add these to LumiFX?'), findsOneWidget);
    expect(find.textContaining('Their scene'), findsOneWidget);
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(find.text('2 items added.'), findsOneWidget);

    // The scene is in Scenes, and the playlist plays it.
    await tester.tap(find.text('Scenes'));
    await tester.pumpAndSettle();
    expect(find.text('Their scene'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Playlists'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.text('Playlists'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Playlists'));
    await tester.pumpAndSettle();
    expect(find.text('Their playlist'), findsOneWidget);
    expect(find.text('2 effects · 10 min each'), findsOneWidget,
        reason: 'the playlist points at the imported scene');
  });

  testWidgets('the night light shows the effect full screen', (tester) async {
    await _pumpApp(tester);
    await tester.tap(find.text('Scenes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ocean'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Night light'));
    // The glows move all the time: step instead of settling.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('Tap to show this again'), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
    await tester.pump(const Duration(seconds: 4));
    // The hint fades away, and a tap brings it back.
    await tester.tapAt(const Offset(200, 400));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byTooltip('Close'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Play'), findsOneWidget, reason: 'back on the player');
  });

  testWidgets('the home puts the season\'s stories first', (tester) async {
    Future<void> launch(DateTime day) async {
      final bridge = BridgeController(store: InMemoryCredentialStore());
      await tester.runAsync(bridge.initialize);
      await tester.pumpWidget(LumiFxApp(
        key: UniqueKey(),
        bridge: bridge,
        discovery: _FakeDiscovery(),
        preferences: PreferencesController(store: InMemoryKeyValueStore()),
        audioInput: FakeAudioInput(),
        clock: () => day,
      ));
      await tester.pumpAndSettle();
    }

    await launch(DateTime(2026, 10, 20));
    expect(find.text('Halloween is coming'), findsOneWidget);
    expect(find.text('Pumpkin Patch'), findsOneWidget);

    await launch(DateTime(2026, 12, 24));
    expect(find.text('Christmas time'), findsOneWidget);
    expect(find.text('Halloween is coming'), findsNothing);

    await launch(DateTime(2026, 12, 6));
    expect(find.text('Happy Hanukkah'), findsOneWidget);
    expect(find.text('Eight Little Lights'), findsWidgets);
    expect(find.text('Christmas time'), findsOneWidget,
        reason: 'the festival joins the season');

    await launch(DateTime(2026, 6, 15));
    expect(find.text('Halloween is coming'), findsNothing);
    expect(find.text('Christmas time'), findsNothing);
    expect(find.text('Happy Hanukkah'), findsNothing);
  });

  testWidgets('effects can be searched and filtered', (tester) async {
    await _pumpApp(tester);
    await tester.tap(find.byTooltip('Search effects'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'storm');
    await tester.pump();
    expect(find.text('Thunderstorm'), findsOneWidget);
    expect(find.text('Ocean'), findsNothing);
    await tester.enterText(find.byType(TextField), 'zzzz');
    await tester.pump();
    expect(find.text('No effects found.'), findsOneWidget);
    await tester.tap(find.byTooltip('Clear'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilterChip, 'Scenes'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilterChip, 'Nature'));
    await tester.pump();
    expect(find.text('Ocean'), findsOneWidget);
    expect(find.text('Fireplace'), findsNothing);
    await tester.tap(find.text('Ocean'));
    await tester.pumpAndSettle();
    expect(find.text('Play'), findsOneWidget);
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
    final widgets = FakeHomeWidgets();
    await tester.pumpWidget(LumiFxApp(
      bridge: bridge,
      discovery: _FakeDiscovery(),
      preferences: preferences,
      audioInput: FakeAudioInput(),
      shortcuts: shortcuts,
      widgets: widgets,
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
    // The home-screen widget shows the same, with links that play them.
    expect(widgets.title, 'Preferiti');
    expect(
        widgets.effects.map((e) => e.name), ['La Villa Infestata', 'Aurora']);
    expect(widgets.effects.first.link, 'lumifx://app/play/haunted_manor');
    expect(widgets.effects.first.colors, isNotEmpty);

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
        if (request.method == 'POST') {
          puts?.add('POST ${request.url.path}');
          if (request.url.path.startsWith('/api/')) {
            return json([
              {
                'success': {'id': '${puts?.length ?? 1}'},
              },
            ]);
          }
          return json({
            'data': [
              {'rid': 's2', 'rtype': 'scene'},
            ],
          });
        }
        switch (request.url.path) {
          case '/api/key/sensors':
            return json({
              '2': {'type': 'ZLLPresence', 'name': 'Hallway sensor'},
            });
          case '/api/key/rules':
            return json(<String, Object>{});
          case '/api/key/schedules':
            return json({
              '7': {
                'name': 'Evening fire',
                'description': 'lumifx:abc:start',
                'command': {
                  'address': '/api/key/groups/1/action',
                  'method': 'PUT',
                  'body': {'scene': 'V1'},
                },
                'localtime': 'W003/T20:00:00',
                'status': 'enabled',
              },
              '8': {
                'name': 'Evening fire',
                'description': 'lumifx:abc:stop',
                'command': {
                  'address': '/api/key/groups/1/action',
                  'method': 'PUT',
                  'body': {'on': false},
                },
                'localtime': 'W003/T22:00:00',
                'status': 'enabled',
              },
              '9': {
                'name': 'Mia',
                'description': 'lumifx:ok1:wake-night',
                'command': {
                  'address': '/api/key/groups/1/action',
                  'method': 'PUT',
                  'body': {'on': true, 'bri': 20},
                },
                'localtime': 'W121/T19:30:00',
                'status': 'enabled',
              },
              '10': {
                'name': 'Mia',
                'description': 'lumifx:ok1:wake-green',
                'command': {
                  'address': '/api/key/groups/1/action',
                  'method': 'PUT',
                  'body': {'on': true, 'bri': 160},
                },
                'localtime': 'W124/T06:45:00',
                'status': 'enabled',
              },
            });
          case '/clip/v2/resource/behavior_script':
            return json({
              'data': [
                {
                  'id': 'sleep-script',
                  'metadata': {'name': 'Basic go to sleep routine'},
                },
              ],
            });
          case '/clip/v2/resource/behavior_instance':
            return json({
              'data': [
                {
                  'id': 'w1',
                  'script_id': HueBridgeClient.wakeUpScriptId,
                  'enabled': true,
                  'metadata': {'name': 'School days'},
                  'configuration': {
                    'fade_in_duration': {'seconds': 1800},
                    'when': {
                      'recurrence_days': [
                        'monday',
                        'tuesday',
                        'wednesday',
                        'thursday',
                        'friday',
                      ],
                      'time_point': {
                        'type': 'time',
                        'time': {'hour': 7, 'minute': 0},
                      },
                    },
                    'where': [
                      {
                        'group': {'rid': 'r1', 'rtype': 'room'},
                      },
                    ],
                  },
                },
              ],
            });
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
                  'id_v1': '/groups/1',
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
    await tester.ensureVisible(find.text('Rooms & zones'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rooms & zones'));
    await tester.pumpAndSettle();
    expect(find.text('Living room'), findsOneWidget);
    expect(find.text('Hue scenes'), findsOneWidget);
    await tester.tap(find.text('Movie night'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(puts, contains('/clip/v2/resource/scene/s1'));
    await tester.pumpAndSettle();
  });

  testWidgets('around the house: away mode, night path, natural light',
      (tester) async {
    final puts = <String>[];
    final bridge = await _connectedBridge(tester, puts: puts);
    final preferences = PreferencesController(store: InMemoryKeyValueStore());
    await tester.pumpWidget(LumiFxApp(
      bridge: bridge,
      discovery: _FakeDiscovery(),
      preferences: preferences,
      audioInput: FakeAudioInput(),
    ));
    await tester.scrollUntilVisible(find.text('Around the house'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.text('Around the house'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Around the house'));
    await tester.pumpAndSettle();
    expect(find.text('Away mode'), findsOneWidget);

    await tester.tap(find.text('New away mode'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'Living room'));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(puts.where((p) => p == 'POST /api/key/schedules'), hasLength(2));

    await tester.scrollUntilVisible(find.text('New night path'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('New night path'));
    await tester.pumpAndSettle();
    expect(find.text('Hallway sensor'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(puts.where((p) => p == 'POST /api/key/rules'), hasLength(2));

    await tester.scrollUntilVisible(find.text('Natural light in a room'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Natural light in a room'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Living room').last);
    await tester.pumpAndSettle();
    expect(
        puts.where((p) => p == 'POST /clip/v2/resource/scene'), hasLength(5));
    expect(puts, contains('POST /clip/v2/resource/smart_scene'));
    expect(puts, contains('/clip/v2/resource/smart_scene/s2'),
        reason: 'switched on at once');
    expect(preferences.naturalLightIds, {'s2'});
  });

  testWidgets('a playing effect can be saved as a Hue scene', (tester) async {
    final puts = <String>[];
    final bridge = await _connectedBridge(tester, puts: puts);
    final preferences = PreferencesController(store: InMemoryKeyValueStore());
    await preferences.setLastTarget('group:r1');
    await tester.pumpWidget(LumiFxApp(
      bridge: bridge,
      discovery: _FakeDiscovery(),
      preferences: preferences,
      audioInput: FakeAudioInput(),
    ));
    await tester.tap(find.text('Scenes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ocean'));
    await tester.pumpAndSettle();
    expect(find.text('Save as Hue scene'), findsNothing);
    await tester.runAsync(() async {
      await tester.tap(find.text('Play'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();
    await tester.tap(find.text('Save as Hue scene'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Blue hour');
    await tester.runAsync(() async {
      await tester.tap(find.text('Save'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();
    expect(puts, contains('POST /clip/v2/resource/scene'));
    expect(find.textContaining('in Living room'), findsOneWidget);
    await tester.tap(find.text('Stop'));
    await tester.pump(const Duration(seconds: 1));
  });

  Future<FakeBackgroundPlayback> playOceanInLivingRoom(
    WidgetTester tester, {
    bool keepPlaying = true,
  }) async {
    final bridge = await _connectedBridge(tester);
    final preferences = PreferencesController(store: InMemoryKeyValueStore());
    await preferences.setLastTarget('group:r1');
    await preferences.setKeepPlayingScreenOff(keepPlaying);
    final background = FakeBackgroundPlayback();
    await tester.pumpWidget(LumiFxApp(
      bridge: bridge,
      discovery: _FakeDiscovery(),
      preferences: preferences,
      audioInput: FakeAudioInput(),
      background: background,
    ));
    await tester.tap(find.text('Scenes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ocean'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.text('Play'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();
    return background;
  }

  // The phone locks and unlocks (no frames are drawn while paused).
  void lockAndUnlock(WidgetTester tester) {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  }

  testWidgets('on Android an effect plays on with the screen off',
      (tester) async {
    final background = await playOceanInLivingRoom(tester);
    expect(background.shown, isTrue);
    expect(background.title, 'Ocean');
    expect(background.text, 'Living room');

    lockAndUnlock(tester);
    await tester.pump();
    expect(find.text('Pause'), findsOneWidget, reason: 'the effect went on');

    // Stop from the notification.
    background.pressStop();
    await tester.pump();
    expect(find.text('Play'), findsOneWidget);
    expect(background.shown, isFalse);
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('with the setting off, locking the phone stops the effect',
      (tester) async {
    final background = await playOceanInLivingRoom(tester, keepPlaying: false);
    expect(background.shown, isFalse);
    lockAndUnlock(tester);
    await tester.pump();
    expect(find.text('Play'), findsOneWidget);
    // Let the light commands started in real time finish, then the
    // restore and the output's close timeout run out in test time.
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('wake-up and bedtime routines are listed and created',
      (tester) async {
    final puts = <String>[];
    final bridge = await _connectedBridge(tester, puts: puts);
    await tester.pumpWidget(LumiFxApp(
      bridge: bridge,
      discovery: _FakeDiscovery(),
      preferences: PreferencesController(store: InMemoryKeyValueStore()),
      audioInput: FakeAudioInput(),
    ));
    await tester.scrollUntilVisible(find.text('Wake-up & bedtime'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.text('Wake-up & bedtime'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.text('Wake-up & bedtime'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
    expect(find.text('School days'), findsOneWidget);
    expect(find.textContaining('7:00 AM · Mon, Tue, Wed, Thu, Fri'),
        findsOneWidget);
    expect(find.textContaining('Living room · 30 min'), findsOneWidget);
    // Below the routines: ok-to-wake lights and scheduled effects.
    final list = find.byType(Scrollable).last;
    await tester.scrollUntilVisible(find.text('Mia'), 200, scrollable: list);
    expect(find.textContaining('Amber from 7:30 PM, green at 6:45 AM'),
        findsOneWidget);
    expect(find.text('New ok-to-wake light'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Evening fire'), 200,
        scrollable: list);
    expect(find.text('Scheduled effects'), findsOneWidget);
    expect(find.textContaining('until 10:00 PM'), findsOneWidget);
    await tester.drag(list, const Offset(0, 2000));
    await tester.pumpAndSettle();

    // Switch it off.
    await tester.runAsync(() async {
      await tester.tap(find.byType(Switch).first);
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
    expect(puts, contains('/clip/v2/resource/behavior_instance/w1'));

    // A new bedtime routine for the living room.
    await tester.tap(find.text('New routine'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Go to sleep').first);
    await tester.pump();
    expect(find.text('10:30 PM'), findsOneWidget);
    expect(find.text('Every day'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilterChip, 'Living room'));
    await tester.pump();
    await tester.runAsync(() async {
      await tester.tap(find.text('Save'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
    expect(puts, contains('POST /clip/v2/resource/behavior_instance'));
    expect(find.text('New routine'), findsOneWidget,
        reason: 'back on the list');
  });

  testWidgets('the wall panel shows the time, rooms and favourites',
      (tester) async {
    tester.view.physicalSize = const Size(2048, 1536);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final bridge = await _connectedBridge(tester);
    final preferences = PreferencesController(store: InMemoryKeyValueStore());
    await preferences.toggleFavorite('ocean');
    await tester.pumpWidget(LumiFxApp(
      bridge: bridge,
      discovery: _FakeDiscovery(),
      preferences: preferences,
      audioInput: FakeAudioInput(),
      clock: () => DateTime(2026, 6, 15, 10, 30),
    ));
    await tester.tap(find.byTooltip('Wall panel'));
    await tester.pumpAndSettle();
    expect(find.text('10:30 AM'), findsOneWidget);
    expect(find.textContaining('June 15'), findsOneWidget);
    expect(find.text('Living room'), findsOneWidget);
    expect(find.text('Movie night'), findsOneWidget, reason: 'Hue scenes');

    // A favourite plays at once, on the last room used (here the preview).
    await tester.tap(find.text('Ocean'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(MiniPlayer), findsOneWidget);

    // After two minutes without a touch the panel dims; a tap wakes it.
    await tester.pump(const Duration(minutes: 2, seconds: 2));
    expect(
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity).last).opacity,
      greaterThan(0.5),
    );
    await tester.tapAt(const Offset(500, 300));
    await tester.pump(const Duration(seconds: 2));
    expect(
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity).last).opacity,
      0,
    );
    await tester.tap(find.bySemanticsLabel('Stop'));
    await tester.pump(const Duration(seconds: 1));
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
