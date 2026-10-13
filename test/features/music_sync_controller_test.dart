import 'package:flutter_test/flutter_test.dart';
import 'package:lumifx/src/features/music/music_sync_controller.dart';

import '../support/fake_audio_input.dart';

void main() {
  test('listens, detects beats and stops the microphone', () async {
    final input = FakeAudioInput();
    final music = MusicSyncController(input);
    await music.start();
    expect(music.status, MusicSyncStatus.listening);
    await Future<void>.delayed(Duration.zero);

    final features = music.features;
    expect(features.beatCount, greaterThan(4));
    expect(features.bpm, closeTo(120, 8));

    await music.stop();
    expect(input.stopped, isTrue);
    expect(music.status, MusicSyncStatus.idle);
    expect(music.features.beatCount, 0);
  });

  test('reports a refused microphone permission', () async {
    final input = FakeAudioInput(granted: false);
    final music = MusicSyncController(input);
    await music.start();
    expect(music.status, MusicSyncStatus.denied);
    expect(input.started, isFalse);
  });

  test('sensitivity scales levels', () async {
    final music = MusicSyncController(FakeAudioInput());
    await music.start();
    await Future<void>.delayed(Duration.zero);
    music.sensitivity = 0.5;
    final half = music.features.bass;
    music.sensitivity = 1;
    expect(half, closeTo(music.features.bass / 2, 1e-9));
    await music.stop();
  });

  test('beat timing keeps advancing between analyses', () async {
    var now = DateTime(2026);
    final music = MusicSyncController(FakeAudioInput(), clock: () => now);
    await music.start();
    await Future<void>.delayed(Duration.zero);
    final first = music.features.secondsSinceBeat;
    now = now.add(const Duration(milliseconds: 500));
    expect(music.features.secondsSinceBeat, closeTo(first + 0.5, 1e-6));
    await music.stop();
  });
}
