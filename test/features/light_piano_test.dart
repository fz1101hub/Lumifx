import 'package:flutter_test/flutter_test.dart';
import 'package:lumifx/src/core/sound/melodies.dart';
import 'package:lumifx/src/features/music_box/light_piano.dart';

void main() {
  test('every note finds its key, an octave away if need be', () {
    expect(pianoKeyFor(60), 0);
    expect(pianoKeyFor(72), 7);
    expect(pianoKeyFor(84), 7);
    expect(pianoKeyFor(55), 4, reason: 'G below plays the G key');
    expect(pianoKeyFor(48), 0);
    expect(pianoKeyFor(61), isNull, reason: 'no black keys');
  });

  test('the tunes to learn have a key for every note', () {
    final ids = [for (final song in pianoSongs) song.id];
    expect(ids.take(3), ['hot_cross_buns', 'twinkle', 'mary_lamb'],
        reason: 'easiest first');
    expect(ids, containsAll(['frere_jacques', 'ode_to_joy', 'au_clair']));
    for (final song in pianoSongs) {
      expect(PianoLesson(song).keys, everyElement(inInclusiveRange(0, 7)));
    }
  });

  test('a lesson waits for the right key', () {
    final lesson = PianoLesson(twinkle);
    expect(lesson.next, 0);
    expect(lesson.press(3), isFalse);
    expect(lesson.done, 0);
    expect(lesson.press(0), isTrue);
    expect(lesson.press(0), isTrue);
    expect(lesson.next, 4, reason: 'twinkle, twinkle, little…');
    for (final key in lesson.keys.skip(2)) {
      expect(lesson.press(key), isTrue);
    }
    expect(lesson.isFinished, isTrue);
    expect(lesson.next, isNull);
  });

  test('the notes are named as children learn them', () {
    expect(pianoNoteName('it', 0), 'Do');
    expect(pianoNoteName('fr', 1), 'Ré');
    expect(pianoNoteName('de', 6), 'H');
    expect(pianoNoteName('en', 6), 'B');
    expect(pianoNoteName('ja', 2), 'ミ');
  });
}
