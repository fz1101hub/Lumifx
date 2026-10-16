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
import 'package:lumifx/src/features/calm/breathing_screen.dart';
import 'package:lumifx/src/features/bridge/credential_store.dart';
import 'package:lumifx/src/features/effects/mini_player.dart';
import 'package:lumifx/src/features/fun/advent_screen.dart';
import 'package:lumifx/src/features/fun/birthday_screen.dart';
import 'package:lumifx/src/features/fun/countdowns_screen.dart';
import 'package:lumifx/src/features/fun/game_screen.dart';
import 'package:lumifx/src/features/fun/light_games.dart';
import 'package:lumifx/src/features/fun/simon.dart';
import 'package:lumifx/src/features/fun/simon_screen.dart';
import 'package:lumifx/src/features/library/preferences_controller.dart';
import 'package:lumifx/src/features/library/scene_editor.dart';
import 'package:lumifx/src/features/paths/path_story_screen.dart';
import 'package:lumifx/src/features/playlists/playlist.dart';
import 'package:lumifx/src/features/timers/pomodoro_screen.dart';
import 'package:lumifx/src/features/weather/weather_screen.dart';
import 'package:lumifx/src/features/library/user_scene.dart';
import 'package:lumifx/src/features/library/sharing.dart';
import 'package:lumifx/src/features/library/story_editor.dart';

import '../support/fake_audio_input.dart';
import '../support/fake_background_playback.dart';
import '../support/fake_home_widgets.dart';
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
    expect(find.text('Brush your teeth'), findsOneWidget);
    expect(find.text('2 min'), findsWidgets);

    await tester.tap(find.widgetWithText(FilledButton, 'Start').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining(RegExp(r'^[12]:\d\d$')), findsOneWidget);
    expect(find.text('Pause'), findsOneWidget);

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

    await launch(DateTime(2026, 6, 15));
    expect(find.text('Halloween is coming'), findsNothing);
    expect(find.text('Christmas time'), findsNothing);
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
          return json({
            'data': [
              {'rid': 's2', 'rtype': 'scene'},
            ],
          });
        }
        switch (request.url.path) {
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
