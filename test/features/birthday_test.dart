import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumifx/l10n/generated/app_localizations.dart';
import 'package:lumifx/src/core/effects/effect_event.dart';
import 'package:lumifx/src/features/effects/catalog/builtin_stories.dart';
import 'package:lumifx/src/features/effects/read_along.dart';
import 'package:lumifx/src/features/fun/birthday.dart';
import 'package:lumifx/src/features/fun/blow_detector.dart';
import 'package:lumifx/src/features/library/effect_library.dart';
import 'package:lumifx/src/features/library/preferences_controller.dart';

/// [seconds] of 16-bit noise at [level] of full scale (RMS).
Uint8List _noise(double seconds, double level, {int rate = 44100}) {
  final random = math.Random(1);
  final count = (seconds * rate).round();
  final bytes = ByteData(count * 2);
  // Uniform noise in ±a has an RMS of a/√3.
  final amplitude = (level * math.sqrt(3)).clamp(0.0, 1.0);
  for (var i = 0; i < count; i++) {
    final s = (random.nextDouble() * 2 - 1) * amplitude;
    bytes.setInt16(i * 2, (s * 32767).round(), Endian.little);
  }
  return bytes.buffer.asUint8List();
}

void main() {
  final english = lookupAppLocalizations(const Locale('en'));
  final library =
      EffectLibrary(PreferencesController(store: InMemoryKeyValueStore()));

  test('the name and age travel with the effects', () {
    final birthday = Birthday(name: '  Anna: the Great ', age: 7);
    for (final effect in [
      birthday.candlesEffect(english),
      birthday.partyEffect(english),
    ]) {
      expect(effect.isGenerated, isTrue, reason: 'not kept in recents');
      expect(effect.isLooping, isFalse);
      final back = Birthday.of(effect)!;
      expect(back.name, 'Anna: the Great');
      expect(back.age, 7);
    }
    expect(Birthday.of(sleepingDragon), isNull);
  });

  test('names are kept short and ages sensible', () {
    expect(Birthday(name: 'x' * 50).name, hasLength(Birthday.maxName));
    expect(Birthday(age: 500).age, Birthday.maxAge);
    expect(Birthday(age: -3).age, 0);
  });

  test('one candle per year, up to ten; five when the age is not said', () {
    expect(Birthday(age: 3).candles, 3);
    expect(Birthday(age: 40).candles, 10);
    expect(Birthday().candles, 5);
    final candles = Birthday(age: 4).candlesEffect(english);
    expect(
      candles.events.where((e) => e.type == EffectEventTypes.magicFlash),
      hasLength(4),
      reason: 'each candle lights up',
    );
  });

  test('the party plays once, its words in order and in time', () {
    final birthday = Birthday(name: 'Leo', age: 1);
    final party = birthday.partyEffect(english);
    expect(party.cycleLength, Birthday.partyLength);
    for (final event in party.events) {
      expect(
          event.at + event.duration, lessThanOrEqualTo(Birthday.partyLength));
    }
    final lines = narrationOf(party, english, library);
    expect(lines.map((l) => l.$2), [
      'Whoosh! The candles are out.',
      'Hooray for Leo!',
      'One year old today!',
    ]);
    for (var i = 1; i < lines.length; i++) {
      expect(lines[i].$1, greaterThan(lines[i - 1].$1));
    }
    expect(
        narrationOf(Birthday(age: 8).partyEffect(english), english, library)
            .last
            .$2,
        '8 years old today!');
    expect(
        narrationOf(Birthday().partyEffect(english), english, library)
            .map((l) => l.$2),
        contains('Have a wonderful day!'));
  });

  test('the candles greet by name, or without one', () {
    final named = Birthday(name: 'Mia').candlesEffect(english);
    expect(named.name, 'Happy birthday, Mia!');
    expect(
        narrationOf(named, english, library).first.$2, 'Happy birthday, Mia!');
    expect(Birthday().candlesEffect(english).name, 'Happy birthday!');
  });

  group('blowing on the microphone', () {
    test('a long loud rush counts', () {
      final detector = BlowDetector(sampleRate: 44100);
      final blow = _noise(0.5, 0.5);
      var heard = false;
      for (var i = 0; i < blow.length && !heard; i += 4096) {
        heard = detector.add(
            Uint8List.sublistView(blow, i, math.min(i + 4096, blow.length)));
      }
      expect(heard, isTrue);
    });

    test('talking, silence and a short burst do not', () {
      final detector = BlowDetector(sampleRate: 44100);
      expect(detector.add(_noise(1, 0.08)), isFalse, reason: 'talking');
      expect(detector.add(Uint8List(8192)), isFalse, reason: 'silence');
      expect(detector.add(_noise(0.2, 0.6)), isFalse, reason: 'a clap');
      expect(detector.add(_noise(0.1, 0.02)), isFalse);
      expect(detector.add(_noise(0.2, 0.6)), isFalse,
          reason: 'a pause starts over');
      expect(detector.add(Uint8List(0)), isFalse);
    });
  });
}
