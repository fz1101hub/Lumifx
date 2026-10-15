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

  test('a stop during start cancels it and releases the microphone', () async {
    final input = FakeAudioInput(startDelay: const Duration(milliseconds: 150));
    final music = MusicSyncController(input);
    final starting = music.start();
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(music.status, MusicSyncStatus.starting);
    final stopping = music.stop();
    await starting;
    await stopping;
    expect(music.status, MusicSyncStatus.idle);
    expect(input.stopped, isTrue);
  });

  test('dispose during start does not leave the microphone on', () async {
    final input = FakeAudioInput(startDelay: const Duration(milliseconds: 100));
    final music = MusicSyncController(input);
    final starting = music.start();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    music.dispose();
    await starting;
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(input.stopped, isTrue);
  });

  test('two starts at once start the microphone once', () async {
    final input = FakeAudioInput();
    final music = MusicSyncController(input);
    await Future.wait([music.start(), music.start()]);
    expect(music.status, MusicSyncStatus.listening);
    expect(input.startCount, 1);
    await music.stop();
  });

  test('a stream that ends marks Music Sync failed and releases the mic',
      () async {
    final input = FakeAudioInput();
    final music = MusicSyncController(input);
    await music.start();
    await Future<void>.delayed(Duration.zero);
    expect(music.features.bass, greaterThan(0));
    await input.endStream();
    await Future<void>.delayed(Duration.zero);
    expect(music.status, MusicSyncStatus.failed);
    expect(music.features.bass, 0);
    await music.stop();
    expect(input.stopped, isTrue);
    expect(music.status, MusicSyncStatus.idle);
  });

  test('a platform pause shows silence, a stall decays to silence', () async {
    final input = FakeAudioInput();
    final music = MusicSyncController(
      input,
      stallTimeout: const Duration(milliseconds: 60),
    );
    await music.start();
    await Future<void>.delayed(Duration.zero);
    expect(music.features.bass, greaterThan(0));

    input.setCapturing(false);
    await Future<void>.delayed(Duration.zero);
    expect(music.features.bass, 0);
    expect(music.isListening, isTrue);

    // Nothing arrives afterwards: the stall timer keeps it silent.
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(music.features.level, 0);
    await music.stop();
  });

  test('a microphone that fails to start reports failed', () async {
    final music = MusicSyncController(FakeAudioInput(failStart: true));
    await music.start();
    expect(music.status, MusicSyncStatus.failed);
    await music.stop();
    expect(music.status, MusicSyncStatus.idle);
  });
}
