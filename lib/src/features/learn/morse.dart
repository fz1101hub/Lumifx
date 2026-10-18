import '../../core/effects/effect.dart';
import '../../core/effects/effect_event.dart';
import '../search/effect_search.dart';

/// International Morse code for letters and numbers.
const morseCode = {
  'a': '.-', 'b': '-...', 'c': '-.-.', 'd': '-..', 'e': '.', 'f': '..-.', //
  'g': '--.', 'h': '....', 'i': '..', 'j': '.---', 'k': '-.-', 'l': '.-..',
  'm': '--', 'n': '-.', 'o': '---', 'p': '.--.', 'q': '--.-', 'r': '.-.',
  's': '...', 't': '-', 'u': '..-', 'v': '...-', 'w': '.--', 'x': '-..-',
  'y': '-.--', 'z': '--..', '0': '-----', '1': '.----', '2': '..---',
  '3': '...--', '4': '....-', '5': '.....', '6': '-....', '7': '--...',
  '8': '---..', '9': '----.',
};

/// One signal of a message: a dot or a dash, of [letter] (its index in
/// [MorseMessage.letters]), starting [at] units in and lasting [length].
typedef MorseSignal = ({int at, int length, int letter});

/// A short message sent with the lamps: a dot is one unit of light, a dash
/// three; one unit dark between signals, three between letters, seven
/// between words.
class MorseMessage {
  MorseMessage(String text) {
    var at = 0;
    var gap = 0;
    for (final word in foldForSearch(text).split(RegExp(r'\s+'))) {
      final codes = [
        for (final char in word.split(''))
          if (morseCode[char] case final code?) (char, code),
      ];
      if (codes.isEmpty) {
        continue;
      }
      if (letters.isNotEmpty) {
        letters.add(' ');
        gap = 7;
      }
      for (final (char, code) in codes) {
        at += gap;
        letters.add(char.toUpperCase());
        for (final (i, sign) in code.split('').indexed) {
          if (i > 0) {
            at += 1;
          }
          final length = sign == '.' ? 1 : 3;
          signals.add((at: at, length: length, letter: letters.length - 1));
          at += length;
        }
        gap = 3;
      }
    }
    units = at;
  }

  /// The longest message sent.
  static const maxLength = 30;

  /// How long a unit lasts: slow enough to read a dash from a dot.
  static const unit = Duration(milliseconds: 350);

  static const _prefix = '${LightingEffect.generatedPrefix}morse:';

  /// What is sent, upper case, a space between words; characters with no
  /// Morse code are left out.
  final letters = <String>[];
  final signals = <MorseSignal>[];

  /// How long the message lasts, in units.
  late final int units;

  bool get isEmpty => signals.isEmpty;

  String get text => letters.join();

  /// "... --- ..." for the letters sent.
  String get code => [
        for (final letter in letters)
          letter == ' ' ? '/' : morseCode[letter.toLowerCase()]!,
      ].join(' ');

  /// The letter being sent [position] into the effect, or null between
  /// words, before the start and after the end.
  int? letterAt(Duration position) {
    final now = position - _lead;
    if (now.isNegative) {
      return null;
    }
    int? letter;
    for (final signal in signals) {
      if (unit * signal.at <= now) {
        letter = signal.letter;
      }
    }
    final end = unit * units + unit * 3;
    return now > end ? null : letter;
  }

  /// A breath before the first signal.
  static const _lead = Duration(seconds: 1);

  /// The message on the lamps in [color], once.
  LightingEffect effect(String name, String color) => LightingEffect(
        id: '$_prefix${color.replaceAll('#', '')}:${Uri.encodeComponent(text)}',
        name: name,
        kind: EffectKind.interactive,
        isLooping: false,
        loopDuration: _lead + unit * units + const Duration(seconds: 2),
        events: [
          EffectEvent(
            at: Duration.zero,
            duration: _lead + unit * units + const Duration(seconds: 2),
            type: EffectEventTypes.ambientPalette,
            parameters: const {
              'palette': <String>['#14172E', '#1C2040'],
              'brightnessMin': 0.04,
              'brightnessMax': 0.08,
              'speed': 0.01,
            },
          ),
          for (final signal in signals)
            EffectEvent(
              at: _lead + unit * signal.at,
              duration: unit * signal.length,
              type: EffectEventTypes.magicFlash,
              parameters: {
                'color': color,
                'target': 'all',
                'brightness': 0.9,
              },
            ),
        ],
      );

  /// The message and colour of a Morse effect, or null for any other.
  static (MorseMessage, String)? of(LightingEffect effect) {
    if (!effect.id.startsWith(_prefix)) {
      return null;
    }
    final rest = effect.id.substring(_prefix.length);
    final colon = rest.indexOf(':');
    if (colon != 6) {
      return null;
    }
    try {
      final message = MorseMessage(Uri.decodeComponent(rest.substring(7)));
      return message.isEmpty ? null : (message, '#${rest.substring(0, 6)}');
    } on ArgumentError {
      return null;
    }
  }
}
