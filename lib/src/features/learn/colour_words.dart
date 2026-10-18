import 'dart:math' as math;

import '../../core/effects/effect.dart';
import '../../core/effects/effect_event.dart';

/// The colours a child learns to name, as the lamps show them.
enum LearnColour {
  red('#FF2020'),
  orange('#FF8C1A'),
  yellow('#FFD60A'),
  green('#2BD94F'),
  blue('#1F6BFF'),
  purple('#9B3BFF'),
  pink('#FF6FB5'),
  white('#FFF4E0');

  const LearnColour(this.hex);

  final String hex;

  /// The colour's name in [languageCode] (English for any other).
  String word(String languageCode) =>
      (colourWords[languageCode] ?? colourWords['en']!)[index];

  static const _prefix = '${LightingEffect.generatedPrefix}colourword:';

  /// The whole room in this colour.
  LightingEffect effect(String name) => LightingEffect(
        id: '$_prefix${this.name}',
        name: name,
        kind: EffectKind.scene,
        loopDuration: const Duration(minutes: 1),
        events: [
          EffectEvent(
            at: Duration.zero,
            duration: const Duration(minutes: 1),
            type: EffectEventTypes.ambientPalette,
            parameters: {
              'palette': [hex, hex],
              'brightnessMin': 0.7,
              'brightnessMax': 0.8,
              'speed': 0.02,
            },
          ),
        ],
      );

  /// The colour an effect shows, or null for any other effect.
  static LearnColour? of(LightingEffect effect) => effect.id.startsWith(_prefix)
      ? values.asNameMap()[effect.id.substring(_prefix.length)]
      : null;
}

/// The languages to learn the colours in, each by its own name.
const learnLanguages = {
  'en': 'English',
  'it': 'Italiano',
  'de': 'Deutsch',
  'fr': 'Français',
  'es': 'Español',
  'nl': 'Nederlands',
  'pt': 'Português',
  'ja': '日本語',
};

/// The colours' names, in the order of [LearnColour].
const colourWords = {
  'en': [
    'red', 'orange', 'yellow', 'green', 'blue', 'purple', 'pink', 'white', //
  ],
  'it': [
    'rosso', 'arancione', 'giallo', 'verde', 'blu', 'viola', 'rosa', //
    'bianco',
  ],
  'de': ['Rot', 'Orange', 'Gelb', 'Grün', 'Blau', 'Lila', 'Rosa', 'Weiß'],
  'fr': [
    'rouge', 'orange', 'jaune', 'vert', 'bleu', 'violet', 'rose', 'blanc', //
  ],
  'es': [
    'rojo', 'naranja', 'amarillo', 'verde', 'azul', 'morado', 'rosa', //
    'blanco',
  ],
  'nl': ['rood', 'oranje', 'geel', 'groen', 'blauw', 'paars', 'roze', 'wit'],
  'pt': [
    'vermelho', 'laranja', 'amarelo', 'verde', 'azul', 'roxo', 'rosa', //
    'branco',
  ],
  'ja': ['あか', 'オレンジ', 'きいろ', 'みどり', 'あお', 'むらさき', 'ピンク', 'しろ'],
};

/// Hear a colour's name, tap the colour: four to choose from.
class ColourQuiz {
  ColourQuiz([math.Random? random]) : _random = random ?? math.Random();

  final math.Random _random;
  LearnColour? _target;
  var _choices = const <LearnColour>[];
  var _score = 0;

  LearnColour get target => _target!;
  List<LearnColour> get choices => _choices;
  int get score => _score;

  /// A new colour to find, never the same twice in a row, among three
  /// others in any order.
  void next() {
    final others = [...LearnColour.values]..remove(_target);
    final target = others[_random.nextInt(others.length)];
    final choices = [...LearnColour.values]
      ..remove(target)
      ..shuffle(_random);
    _target = target;
    _choices = [target, ...choices.take(3)]..shuffle(_random);
  }

  bool answer(LearnColour colour) {
    final right = colour == _target;
    if (right) {
      _score++;
    }
    return right;
  }
}
