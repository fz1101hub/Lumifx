import 'dart:math' as math;

import '../../core/effects/effect.dart';
import '../../core/effects/effect_event.dart';
import '../../core/sound/melodies.dart';
import '../../core/sound/melody.dart';

/// One key of the light piano: a note and the colour it lights.
typedef PianoKey = ({int midi, String color});

/// Middle C up to the next C, each with a colour of the rainbow.
const pianoKeys = <PianoKey>[
  (midi: 60, color: '#FF3B30'),
  (midi: 62, color: '#FF9500'),
  (midi: 64, color: '#FFD60A'),
  (midi: 65, color: '#34C759'),
  (midi: 67, color: '#00C7BE'),
  (midi: 69, color: '#0A84FF'),
  (midi: 71, color: '#AF52DE'),
  (midi: 72, color: '#FF6FB5'),
];

/// The name of key [index] as children learn it in [languageCode]: do re
/// mi in the Romance languages and Japanese, letters elsewhere (with H for
/// B in German).
String pianoNoteName(String languageCode, int index) {
  const solfege = ['Do', 'Re', 'Mi', 'Fa', 'Sol', 'La', 'Si', 'Do'];
  return switch (languageCode) {
    'it' || 'es' || 'pt' => solfege[index],
    'fr' => const ['Do', 'Ré', 'Mi', 'Fa', 'Sol', 'La', 'Si', 'Do'][index],
    'ja' => const ['ド', 'レ', 'ミ', 'ファ', 'ソ', 'ラ', 'シ', 'ド'][index],
    'de' => const ['C', 'D', 'E', 'F', 'G', 'A', 'H', 'C'][index],
    _ => const ['C', 'D', 'E', 'F', 'G', 'A', 'B', 'C'][index],
  };
}

/// The key that plays [midi], an octave up or down if need be; null for a
/// note the piano has no key for (a sharp or a flat).
int? pianoKeyFor(int midi) {
  final same = [
    for (final (i, key) in pianoKeys.indexed)
      if (key.midi % 12 == midi % 12) i,
  ];
  if (same.isEmpty) {
    return null;
  }
  // Both Cs: the high one only for notes from it up.
  return same.length > 1 && midi < 72 ? same.first : same.last;
}

/// The tunes a child can learn on the piano (every note has a key), the
/// easiest first.
List<Melody> get pianoSongs => [
      for (final melody in {
        hotCrossBuns,
        twinkle,
        maryLamb,
        frereJacques,
        odeToJoy,
        ...lullabies,
        ...carols,
      })
        if (melody.notes.every((n) => pianoKeyFor(n.midi) != null)) melody,
    ];

/// Learning a tune: the key to play next glows until it is played.
class PianoLesson {
  PianoLesson(this.melody)
      : keys = [for (final n in melody.notes) pianoKeyFor(n.midi)!];

  final Melody melody;

  /// The key of each note, in order.
  final List<int> keys;

  var _done = 0;

  int get done => _done;
  int get total => keys.length;
  bool get isFinished => _done >= keys.length;

  /// The key to play now; null once the tune is played.
  int? get next => isFinished ? null : keys[_done];

  /// Whether [key] was the right one (then the next note is due).
  bool press(int key) {
    if (key != next) {
      return false;
    }
    _done++;
    return true;
  }
}

/// What a key played in Repeat after me did.
enum EchoPress {
  /// Right so far; more notes to play.
  right,

  /// The last note of the tune: well done.
  done,

  /// A wrong key: listen again.
  wrong,
}

/// Repeat after me: the piano plays a few notes and the child plays them
/// back; each time it is right, the tune grows by one note. Notes move by
/// small steps, like a tune a child can sing.
class PianoEcho {
  PianoEcho([math.Random? random]) : _random = random ?? math.Random();

  final math.Random _random;
  final _keys = <int>[];
  var _played = 0;

  /// How many notes a tune starts with, and the most it grows to.
  static const firstLength = 3;
  static const maxLength = 12;

  /// The tune to repeat, as key indices.
  List<int> get keys => List.unmodifiable(_keys);

  /// The notes of the tune played back so far.
  int get played => _played;

  /// The longest tune repeated in this game.
  int get best => _best;
  var _best = 0;

  /// A new tune of [firstLength] notes.
  void start() {
    _keys.clear();
    for (var i = 0; i < firstLength; i++) {
      _keys.add(_nextKey());
    }
    _played = 0;
  }

  /// One more note on the same tune, up to [maxLength].
  void grow() {
    if (_keys.length < maxLength) {
      _keys.add(_nextKey());
    }
    _played = 0;
  }

  /// Back to the start of the same tune, to hear it again.
  void again() => _played = 0;

  EchoPress press(int key) {
    if (_played >= _keys.length || key != _keys[_played]) {
      _played = 0;
      return EchoPress.wrong;
    }
    _played++;
    if (_played < _keys.length) {
      return EchoPress.right;
    }
    _best = math.max(_best, _keys.length);
    return EchoPress.done;
  }

  /// Up to two keys away from the last note, never the same note three
  /// times running.
  int _nextKey() {
    if (_keys.isEmpty) {
      return _random.nextInt(5);
    }
    final last = _keys.last;
    final twice = _keys.length >= 2 && _keys[_keys.length - 2] == last;
    while (true) {
      final key =
          (last + _random.nextInt(5) - 2).clamp(0, pianoKeys.length - 1);
      if (!(twice && key == last)) {
        return key;
      }
    }
  }
}

/// A soft glow under the notes.
LightingEffect pianoBackground(String name) => LightingEffect(
      id: _pianoId,
      name: name,
      kind: EffectKind.interactive,
      loopDuration: const Duration(minutes: 1),
      events: const [
        EffectEvent(
          at: Duration.zero,
          duration: Duration(minutes: 1),
          type: EffectEventTypes.ambientPalette,
          parameters: {
            'palette': <String>['#1E2140', '#2A2350'],
            'brightnessMin': 0.08,
            'brightnessMax': 0.14,
            'speed': 0.02,
          },
        ),
      ],
    );

const _pianoId = '${LightingEffect.generatedPrefix}piano';

bool isPianoEffect(LightingEffect effect) => effect.id == _pianoId;
