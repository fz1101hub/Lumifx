import 'package:lumifx/src/core/sound/melody.dart';
import 'package:lumifx/src/core/sound/sound_player.dart';
import 'package:lumifx/src/core/sound/soundscape.dart';

class FakeSoundPlayer implements SoundPlayer {
  final calls = <String>[];
  Soundscape? playing;
  double? volume;

  /// How many times the cues on top were stopped.
  int cueStops = 0;

  @override
  Future<void> play(Soundscape soundscape, {required double volume}) async {
    playing = soundscape;
    this.volume = volume;
    calls.add('play ${soundscape.ambiences.map((a) => a.name).join('+')}');
  }

  @override
  Future<void> pause() async => calls.add('pause');

  @override
  Future<void> resume() async => calls.add('resume');

  @override
  Future<void> stop() async {
    playing = null;
    calls.add('stop');
  }

  @override
  Future<void> setVolume(double volume) async => this.volume = volume;

  @override
  Future<void> stopCues() async => cueStops++;

  @override
  Future<void> thunder({required double volume}) async => calls.add('thunder');

  @override
  Future<void> note(int midi, Instrument instrument,
          {required double volume}) async =>
      calls.add('note $midi');
}
