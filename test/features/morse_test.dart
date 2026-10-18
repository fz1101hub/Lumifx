import 'package:flutter_test/flutter_test.dart';
import 'package:lumifx/src/core/effects/effect_event.dart';
import 'package:lumifx/src/features/learn/morse.dart';

void main() {
  test('SOS is three dots, three dashes, three dots', () {
    final sos = MorseMessage('sos');
    expect(sos.text, 'SOS');
    expect(sos.code, '... --- ...');
    expect(
        [for (final s in sos.signals) s.length], [1, 1, 1, 3, 3, 3, 1, 1, 1]);
    // One unit between signals, three between letters.
    expect(
        [for (final s in sos.signals) s.at], [0, 2, 4, 8, 12, 16, 22, 24, 26]);
    expect(sos.units, 27);
  });

  test('words, accents and characters with no code', () {
    final message = MorseMessage('  Ciao   àmico! ありがとう ');
    expect(message.text, 'CIAO AMICO');
    expect(message.code.contains(' / '), isTrue);
    // Seven units between words.
    final firstOfSecondWord = message.signals.firstWhere((s) => s.letter == 5);
    final lastOfFirstWord = message.signals.lastWhere((s) => s.letter == 3);
    expect(firstOfSecondWord.at - (lastOfFirstWord.at + lastOfFirstWord.length),
        7);
    expect(MorseMessage('ありがとう').isEmpty, isTrue);
  });

  test('the lamps flash every signal, and the letter can be followed', () {
    final message = MorseMessage('Hi 2');
    final effect = message.effect('Secret messages', '#FF3B30');
    final flashes = [
      for (final e in effect.events)
        if (e.type == EffectEventTypes.magicFlash) e,
    ];
    expect(flashes, hasLength(message.signals.length));
    expect(effect.hasRapidFlashes, isFalse);
    expect(effect.isLooping, isFalse);
    final (back, color) = MorseMessage.of(effect)!;
    expect(back.text, 'HI 2');
    expect(color, '#FF3B30');

    expect(message.letterAt(Duration.zero), isNull, reason: 'a breath first');
    expect(message.letterAt(flashes.first.at), 0);
    final i = message.signals.indexWhere((s) => s.letter == 1);
    expect(message.letterAt(flashes[i].at), 1);
    expect(message.letterAt(effect.cycleLength), isNull);
  });
}
