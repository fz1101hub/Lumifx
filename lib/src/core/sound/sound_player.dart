import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'melody.dart';
import 'soundscape.dart';
import 'synth.dart';

/// Plays the sounds under an effect.
abstract interface class SoundPlayer {
  /// Starts [soundscape]'s ambiences (replacing what played), looping.
  Future<void> play(Soundscape soundscape, {required double volume});

  Future<void> pause();
  Future<void> resume();

  /// Stops the ambiences (a new soundscape replacing them calls this too).
  Future<void> stop();
  Future<void> setVolume(double volume);

  /// Stops the thunder and the notes ringing on top, and any still being
  /// made: kept apart from [stop] so the piano's notes go on when the
  /// soundscape under them changes.
  Future<void> stopCues();

  /// One clap of thunder on top.
  Future<void> thunder({required double volume});

  /// One note of [instrument] on top (the light piano).
  Future<void> note(int midi, Instrument instrument, {required double volume});
}

class NoSoundPlayer implements SoundPlayer {
  const NoSoundPlayer();

  @override
  Future<void> play(Soundscape soundscape, {required double volume}) async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> resume() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> setVolume(double volume) async {}
  @override
  Future<void> stopCues() async {}
  @override
  Future<void> thunder({required double volume}) async {}
  @override
  Future<void> note(int midi, Instrument instrument,
      {required double volume}) async {}
}

/// Plays generated WAV files with the audioplayers plugin. The files are
/// made once (in a background isolate) and kept in the temporary folder.
/// Other apps' music keeps playing (no audio focus on Android, a mixing
/// session on iOS). On iOS the session is of the playback kind: a lullaby
/// is heard with the silent switch on, and an effect with sounds goes on
/// with the phone locked (the app may run in the background while it
/// plays audio).
class AudioplayersSoundPlayer implements SoundPlayer {
  AudioplayersSoundPlayer();

  final _loops = <AudioPlayer>[];
  AudioPlayer? _thunder;

  /// A few players taking turns, so quick notes ring on together.
  final _notes = <AudioPlayer>[];
  var _nextNote = 0;
  int _generation = 0;

  /// Moves on at [stopCues]: a cue whose file was still being made then
  /// stays silent.
  int _cueGeneration = 0;
  double _volume = 0.6;

  /// Paused while the loops were still being made: they wait to resume.
  bool _paused = false;

  static final _context = AudioContext(
    android: const AudioContextAndroid(
      audioFocus: AndroidAudioFocus.none,
      usageType: AndroidUsageType.media,
      contentType: AndroidContentType.sonification,
    ),
    iOS: AudioContextIOS(
      category: AVAudioSessionCategory.playback,
      options: const {AVAudioSessionOptions.mixWithOthers},
    ),
  );

  static final _files = <String, Future<String>>{};

  /// The WAV file of [name], made by [render] the first time. Written
  /// under another name and renamed, so an app killed mid-write never
  /// leaves half a file; a failure is not remembered, so the next play
  /// tries again.
  static Future<String> _file(String name, Uint8List Function() render) =>
      _files[name] ??= () async {
        final dir = Directory('${Directory.systemTemp.path}/lumifx_sounds');
        final file = File('${dir.path}/$name.wav');
        if (!file.existsSync()) {
          dir.createSync(recursive: true);
          final bytes = await compute((_) => render(), null);
          final partial = File('${file.path}.part');
          await partial.writeAsBytes(bytes, flush: true);
          await partial.rename(file.path);
        }
        return file.path;
      }()
          .catchError((Object error) {
        _files.remove(name);
        throw error;
      });

  static Uint8List _ambienceWav(Ambience a) => wavOf(synthesizeAmbience(a));

  @override
  Future<void> play(Soundscape soundscape, {required double volume}) async {
    final generation = ++_generation;
    _volume = volume;
    _paused = false;
    await _stopLoops();
    if (soundscape.melody case final melody?) {
      final times = soundscape.melodyTimes;
      final path = await _file('v1_melody_${melody.id}_x$times',
          () => wavOf(synthesizeMelody(melody, times: times)));
      if (generation != _generation) {
        return;
      }
      final player = AudioPlayer();
      _loops.add(player);
      try {
        await player.setAudioContext(_context);
        await player.setReleaseMode(ReleaseMode.stop);
        if (_paused) {
          await player.setSource(DeviceFileSource(path));
          await player.setVolume(_volume);
        } else {
          await player.play(DeviceFileSource(path), volume: _volume);
        }
      } on Object catch (error) {
        debugPrint('Sound: $error');
      }
    }
    for (final ambience in soundscape.ambiences) {
      final path =
          await _file('v1_${ambience.name}', () => _ambienceWav(ambience));
      if (generation != _generation) {
        return;
      }
      final player = AudioPlayer();
      _loops.add(player);
      try {
        await player.setAudioContext(_context);
        await player.setReleaseMode(ReleaseMode.loop);
        // Several ambiences together are each a little quieter.
        final loudness = _loopVolume(soundscape.ambiences.length);
        if (_paused) {
          // Paused meanwhile: ready, and silent until resume().
          await player.setSource(DeviceFileSource(path));
          await player.setVolume(loudness);
        } else {
          await player.play(DeviceFileSource(path), volume: loudness);
        }
      } on Object catch (error) {
        debugPrint('Sound: $error');
      }
    }
  }

  double _loopVolume(int count) =>
      (_volume / (count > 1 ? 1.4 : 1)).clamp(0.0, 1.0);

  // The loops are copied before each walk: play() and stop() change the
  // list while these wait on the plugin.
  @override
  Future<void> pause() async {
    _paused = true;
    for (final player in [..._loops]) {
      try {
        await player.pause();
      } on Object {
        // Released meanwhile.
      }
    }
  }

  @override
  Future<void> resume() async {
    _paused = false;
    for (final player in [..._loops]) {
      try {
        await player.resume();
      } on Object {
        // Released meanwhile.
      }
    }
  }

  @override
  Future<void> stop() async {
    _generation++;
    await _stopLoops();
  }

  Future<void> _stopLoops() async {
    final players = [..._loops];
    _loops.clear();
    for (final player in players) {
      try {
        await player.stop();
        await player.dispose();
      } on Object {
        // Already released.
      }
    }
  }

  @override
  Future<void> setVolume(double volume) async {
    _volume = volume;
    final players = [..._loops];
    for (final player in players) {
      try {
        await player.setVolume(_loopVolume(players.length));
      } on Object {
        // Released meanwhile.
      }
    }
  }

  @override
  Future<void> stopCues() async {
    _cueGeneration++;
    for (final player in [if (_thunder case final t?) t, ..._notes]) {
      try {
        await player.stop();
      } on Object {
        // Released meanwhile.
      }
    }
  }

  @override
  Future<void> thunder({required double volume}) async {
    final generation = _cueGeneration;
    final variant = DateTime.now().millisecond % 3;
    final path = await _file('v1_thunder_$variant',
        () => wavOf(synthesizeCue(SoundCue.thunder, seed: variant + 1)));
    if (generation != _cueGeneration) {
      return;
    }
    final player = _thunder ??= AudioPlayer();
    try {
      await player.setAudioContext(_context);
      await player.stop();
      await player.play(DeviceFileSource(path), volume: volume);
    } on Object catch (error) {
      debugPrint('Sound: $error');
    }
  }

  @override
  Future<void> note(int midi, Instrument instrument,
      {required double volume}) async {
    final generation = _cueGeneration;
    final path = await _file(
        'v1_note_${instrument.name}_$midi',
        () => wavOf(synthesizeMelody(Melody(
              id: 'note',
              bpm: 120,
              notes: [Note(midi, 1)],
              instrument: instrument,
            ))));
    if (_notes.length < 4) {
      final player = AudioPlayer();
      _notes.add(player);
      try {
        await player.setPlayerMode(PlayerMode.lowLatency);
        await player.setAudioContext(_context);
        await player.setReleaseMode(ReleaseMode.stop);
      } on Object catch (error) {
        debugPrint('Sound: $error');
      }
    }
    if (generation != _cueGeneration) {
      return;
    }
    final player = _notes[_nextNote++ % _notes.length];
    try {
      await player.stop();
      await player.play(DeviceFileSource(path), volume: volume);
    } on Object catch (error) {
      debugPrint('Sound: $error');
    }
  }
}
