import 'dart:math' as math;

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

  test('Repeat after me grows by one note each time it is right', () {
    final echo = PianoEcho(math.Random(3))..start();
    expect(echo.keys, hasLength(PianoEcho.firstLength));
    for (final (i, key) in echo.keys.indexed) {
      expect(key, inInclusiveRange(0, pianoKeys.length - 1));
      if (i > 0) {
        expect((key - echo.keys[i - 1]).abs(), lessThanOrEqualTo(2),
            reason: 'small steps');
      }
    }
    final tune = echo.keys;
    for (final key in tune.take(tune.length - 1)) {
      expect(echo.press(key), EchoPress.right);
    }
    expect(echo.press(tune.last), EchoPress.done);
    expect(echo.best, PianoEcho.firstLength);
    echo.grow();
    expect(echo.keys, hasLength(PianoEcho.firstLength + 1));
    expect(echo.keys.take(tune.length), tune, reason: 'the same tune, longer');

    // A wrong key starts the same tune again.
    expect(echo.press(echo.keys.first), EchoPress.right);
    final wrong = (echo.keys[1] + 1) % pianoKeys.length;
    expect(echo.press(wrong), EchoPress.wrong);
    expect(echo.played, 0);
    expect(echo.keys, hasLength(PianoEcho.firstLength + 1));
  });

  test('a tune never repeats a note three times or grows past the limit', () {
    final echo = PianoEcho(math.Random(8))..start();
    for (var i = 0; i < 30; i++) {
      echo.grow();
    }
    expect(echo.keys, hasLength(PianoEcho.maxLength));
    for (var i = 2; i < echo.keys.length; i++) {
      expect(
          echo.keys[i] == echo.keys[i - 1] && echo.keys[i] == echo.keys[i - 2],
          isFalse);
    }
  });
}
