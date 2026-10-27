import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumifx/src/app.dart';
import 'package:lumifx/src/core/hue/hue_discovery.dart';
import 'package:lumifx/src/core/hue/hue_models.dart';
import 'package:lumifx/src/core/speech/voice_recordings.dart';
import 'package:lumifx/src/app_scope.dart';
import 'package:lumifx/src/features/bedtime/dream_diary.dart';
import 'package:lumifx/src/features/bedtime/dream_diary_screen.dart';
import 'package:lumifx/src/features/bridge/bridge_controller.dart';
import 'package:lumifx/src/features/bridge/credential_store.dart';
import 'package:lumifx/src/features/library/preferences_controller.dart';
import 'package:lumifx/src/features/library/user_scene.dart';
import 'package:lumifx/src/features/library/user_story.dart';
import 'package:lumifx/src/features/library/voice_recording_screen.dart';

import '../support/fake_audio_input.dart';
import '../support/phone_window.dart';

class _NoDiscovery implements BridgeDiscovery {
  @override
  Stream<HueBridgeInfo> discover({Duration timeout = Duration.zero}) =>
      const Stream.empty();
}

/// Recordings kept in memory.
class _MemoryVoices extends VoiceRecordings {
  final recorded = <(String, int)>{};

  @override
  Future<void> load() async {}

  @override
  String? pathOf(String storyId, int at) =>
      recorded.contains((storyId, at)) ? '/voices/$storyId/$at.m4a' : null;

  @override
  bool hasAny(String storyId) => recorded.any((r) => r.$1 == storyId);

  @override
  Future<String> newPath(String storyId, int at) async =>
      '/voices/$storyId/$at.m4a';

  @override
  void saved(String storyId, int at) {
    recorded.add((storyId, at));
    notifyListeners();
  }

  @override
  Future<void> delete(String storyId, int at) async {
    recorded.remove((storyId, at));
    notifyListeners();
  }

  @override
  Future<void> deleteStory(String storyId) async {
    recorded.removeWhere((r) => r.$1 == storyId);
    notifyListeners();
  }
}

class _FakeRecorder implements VoiceRecorder {
  _FakeRecorder({this.granted = true});

  final bool granted;
  final started = <String>[];
  int stops = 0;

  @override
  Future<bool> requestPermission() async => granted;

  @override
  Future<void> start(String path) async => started.add(path);

  @override
  Future<void> stop() async => stops++;
}

class _FakePlayer implements VoicePlayer {
  final played = <String>[];

  @override
  Future<void> play(String path) async => played.add(path);

  @override
  Future<void> stop() async {}
}

final _story = UserStory(
  id: 'story:7',
  name: 'Grandma tells',
  colors: const ['#000033', '#112266'],
  motion: SceneMotion.calm,
  length: 30,
  moments: const [
    StoryMoment(at: 5, kind: StoryMomentKind.spark, words: 'a time'),
    StoryMoment(at: 0, kind: StoryMomentKind.wordsOnly, words: 'Once upon'),
    StoryMoment(at: 9, kind: StoryMomentKind.darkness),
  ],
);

Future<void> _open(
  WidgetTester tester,
  VoiceRecordings voices,
  VoiceRecorder recorder,
  VoicePlayer player,
) async {
  final bridge = BridgeController(store: InMemoryCredentialStore());
  await tester.runAsync(bridge.initialize);
  final preferences = PreferencesController(store: InMemoryKeyValueStore());
  await preferences.setOnboardingDone();
  await preferences.load();
  await preferences.saveUserStory(_story);
  await tester.pumpWidget(LumiFxApp(
    clock: () => DateTime(2026, 6, 15, 12),
    bridge: bridge,
    discovery: _NoDiscovery(),
    preferences: preferences,
    audioInput: FakeAudioInput(),
    voices: voices,
    voiceRecorder: recorder,
    voicePlayer: player,
  ));
  await tester.pumpAndSettle();
  // ignore: unawaited_futures
  tester.state<NavigatorState>(find.byType(Navigator).first).push(
        MaterialPageRoute<void>(
            builder: (_) => VoiceRecordingScreen(story: _story)),
      );
  await tester.pumpAndSettle();
}

void main() {
  usePhoneWindow();
  dreamTests();

  testWidgets('each line with words can be recorded, heard and removed',
      (tester) async {
    final voices = _MemoryVoices();
    final recorder = _FakeRecorder();
    final player = _FakePlayer();
    await _open(tester, voices, recorder, player);
    // In story order; the moment without words is left out.
    expect(find.text('Once upon'), findsOneWidget);
    expect(find.text('a time'), findsOneWidget);
    expect(find.text('Record'), findsNWidgets(2));

    await tester.tap(find.text('Record').first);
    await tester.pumpAndSettle();
    expect(recorder.started, ['/voices/story:7/0.m4a']);
    await tester.tap(find.text('Stop'));
    await tester.pumpAndSettle();
    expect(recorder.stops, 1);
    expect(find.text('Recorded'), findsOneWidget);
    expect(voices.hasAny('story:7'), isTrue);

    await tester.tap(find.byTooltip('Listen'));
    await tester.pump();
    expect(player.played, ['/voices/story:7/0.m4a']);
    await tester.tap(find.byTooltip('Delete recording'));
    await tester.pumpAndSettle();
    expect(find.text('Recorded'), findsNothing);
  });

  testWidgets('a line stops by itself after 30 seconds', (tester) async {
    final voices = _MemoryVoices();
    final recorder = _FakeRecorder();
    await _open(tester, voices, recorder, _FakePlayer());
    await tester.tap(find.text('Record').last);
    await tester.pump();
    await tester.pump(const Duration(seconds: 31));
    await tester.pumpAndSettle();
    expect(recorder.stops, 1);
    expect(voices.recorded, {('story:7', 5)});
  });

  testWidgets('without the microphone it says so', (tester) async {
    final recorder = _FakeRecorder(granted: false);
    await _open(tester, _MemoryVoices(), recorder, _FakePlayer());
    await tester.tap(find.text('Record').first);
    await tester.pump();
    expect(find.textContaining('needs the microphone'), findsOneWidget);
    expect(recorder.started, isEmpty);
  });
}

void dreamTests() {
  testWidgets('a dream is told, recorded, shown in the room and deleted',
      (tester) async {
    final voices = _MemoryVoices();
    final recorder = _FakeRecorder();
    final player = _FakePlayer();
    final bridge = BridgeController(store: InMemoryCredentialStore());
    await tester.runAsync(bridge.initialize);
    final preferences = PreferencesController(store: InMemoryKeyValueStore());
    await preferences.setOnboardingDone();
    await preferences.load();
    await tester.pumpWidget(LumiFxApp(
      clock: () => DateTime(2026, 6, 16, 7, 30),
      bridge: bridge,
      discovery: _NoDiscovery(),
      preferences: preferences,
      audioInput: FakeAudioInput(),
      voices: voices,
      voiceRecorder: recorder,
      voicePlayer: player,
    ));
    await tester.pumpAndSettle();
    // ignore: unawaited_futures
    tester.state<NavigatorState>(find.byType(Navigator).first).push(
        MaterialPageRoute<void>(builder: (_) => const DreamDiaryScreen()));
    await tester.pumpAndSettle();
    expect(find.textContaining('No dreams yet'), findsOneWidget);

    await tester.tap(find.text('Tell a dream'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextField), 'I was flying over the sea at night');
    await tester.pump();
    await tester.tap(find.text('Record my voice'));
    await tester.pump();
    expect(recorder.started, hasLength(1));
    await tester.tap(find.text('Stop'));
    await tester.pump();
    expect(find.text('Listen'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    final dream = preferences.dreamsOf('').single;
    expect(dream.words, 'I was flying over the sea at night');
    expect(dream.colors, contains('#00B3FF'), reason: 'the sea');
    expect(dream.date, DateTime(2026, 6, 16, 7, 30));
    expect(voices.recorded, {(dream.recordingKey, 0)});
    final playback =
        AppScope.of(tester.element(find.byType(DreamDiaryScreen))).playback;
    expect(Dream.isDream(playback.effect), isTrue);
    await playback.stop(restore: false);
    await tester.pumpAndSettle();

    expect(find.text('I was flying over the sea at night'), findsOneWidget);
    await tester.tap(find.text('Listen'));
    await tester.pump();
    expect(player.played, ['/voices/${dream.recordingKey}/0.m4a']);

    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(preferences.dreamsOf(''), isEmpty);
    expect(voices.recorded, isEmpty);
  });

  testWidgets('a dream told but not kept leaves no recording behind',
      (tester) async {
    final voices = _MemoryVoices();
    final recorder = _FakeRecorder();
    final bridge = BridgeController(store: InMemoryCredentialStore());
    await tester.runAsync(bridge.initialize);
    final preferences = PreferencesController(store: InMemoryKeyValueStore());
    await preferences.setOnboardingDone();
    await preferences.load();
    await tester.pumpWidget(LumiFxApp(
      bridge: bridge,
      discovery: _NoDiscovery(),
      preferences: preferences,
      audioInput: FakeAudioInput(),
      voices: voices,
      voiceRecorder: recorder,
      voicePlayer: _FakePlayer(),
    ));
    await tester.pumpAndSettle();
    // ignore: unawaited_futures
    tester.state<NavigatorState>(find.byType(Navigator).first).push(
        MaterialPageRoute<void>(builder: (_) => const DreamEditorScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Record my voice'));
    await tester.pump();
    await tester.tap(find.text('Stop'));
    await tester.pump();
    expect(voices.recorded, hasLength(1));
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(voices.recorded, isEmpty);
    expect(preferences.dreamsOf(''), isEmpty);
  });
}
