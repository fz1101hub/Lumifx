import 'user_scene.dart';

/// A picture a sentence can name: its colours and, for some, how they
/// move.
class _Concept {
  const _Concept(this.colors, {this.motion, required this.words});

  final List<String> colors;
  final SceneMotion? motion;

  /// Word beginnings in the eight languages, lower case without accents
  /// (Japanese words are found anywhere in the sentence).
  final List<String> words;
}

/// Words that only say how the colours move.
const _motionWords = <SceneMotion, List<String>>{
  SceneMotion.calm: [
    'calm', 'slow', 'quiet', 'peace', 'relax', 'gentle', 'soft', 'sleep', //
    'calm', 'lent', 'tranquil', 'pace', 'rilass', 'dolc', 'morbid', 'sonno',
    'ruhig', 'langsam', 'sanft', 'entspann', 'schlaf', 'friedlich',
    'calme', 'doux', 'douce', 'paisib', 'repos', 'dorm',
    'tranquil', 'despacio', 'suave', 'relaj', 'pacif', 'dormi',
    'rustig', 'langzaam', 'zacht', 'ontspan', 'slaap',
    'calm', 'devagar', 'suave', 'relax', 'dorm',
    'ゆっくり', 'しずか', '静か', 'おだやか', 'リラックス', 'ねむ', '眠',
  ],
  SceneMotion.lively: [
    'lively', 'fast', 'dance', 'danc', 'energ', 'wild', 'fun', //
    'vivac', 'veloc', 'ballo', 'balla', 'danza', 'energ', 'allegr',
    'schnell', 'tanz', 'lebhaft', 'energ', 'wild',
    'rapide', 'vite', 'dans', 'energ', 'vif', 'vive',
    'rapid', 'baile', 'bail', 'energ', 'alegr',
    'snel', 'dans', 'energ', 'vrolijk', 'levendig',
    'rapid', 'danc', 'energ', 'anima',
    'はや', '速', 'おど', '踊', 'ダンス', 'にぎやか',
  ],
  SceneMotion.flicker: [
    'flicker', 'twinkl', 'sparkl', //
    'tremol', 'scintill', 'sfavill',
    'flacker', 'funkel', 'glitzer',
    'vacill', 'scintill', 'petill',
    'parpade', 'centell', 'chispe',
    'flikker', 'fonkel', 'schitter',
    'cintil', 'tremeluz', 'faisc',
    'ゆらゆら', 'きらきら', 'キラキラ', 'ちらちら',
  ],
};

const _concepts = <_Concept>[
  _Concept([
    '#FF6A00',
    '#FF2D55',
    '#9B30FF',
    '#FFB347'
  ], words: [
    'sunset', 'dusk', 'evening', //
    'tramont', 'crepuscol', 'sera',
    'sonnenuntergang', 'abenddammer', 'abend',
    'coucher', 'crepuscul', 'soir',
    'atardecer', 'ocaso', 'crepuscul', 'tarde',
    'zonsondergang', 'schemer', 'avond',
    'por do sol', 'entardecer', 'crepuscul', 'anoitecer',
    '夕焼け', '夕やけ', 'ゆうやけ', '夕日', '夕方', 'たそがれ',
  ]),
  _Concept([
    '#FFB7C5',
    '#FFD7A8',
    '#FF9A2E',
    '#CFE8FF'
  ], words: [
    'sunrise', 'dawn', 'morning', //
    'alba', 'aurora del', 'mattin', 'sorgere',
    'sonnenaufgang', 'morgen', 'dammerung',
    'aube', 'aurore', 'lever', 'matin',
    'amanecer', 'alba', 'manana', 'madrugada',
    'zonsopgang', 'dageraad', 'ochtend',
    'nascer', 'amanhecer', 'aurora do', 'manha', 'madrugada',
    '朝焼け', '日の出', '夜明け', 'あさやけ', '朝',
  ]),
  _Concept([
    '#1E7F3A',
    '#3DDC84',
    '#B5E550',
    '#6B8E23'
  ], words: [
    'forest', 'wood', 'tree', 'garden', 'grass', 'leaf', 'leaves', 'green', //
    'bosco', 'foresta', 'albero', 'alberi', 'giardin', 'prato', 'erba',
    'foglie', 'verde',
    'wald', 'baum', 'baume', 'garten', 'wiese', 'gras', 'blatt', 'blatter',
    'grun',
    'foret', 'bois', 'arbre', 'jardin', 'herbe', 'feuill', 'vert',
    'bosque', 'selva', 'arbol', 'jardin', 'hierba', 'cesped', 'hoja', 'verde',
    'bos', 'boom', 'bomen', 'tuin', 'gras', 'blad', 'groen',
    'floresta', 'mata', 'arvore', 'jardim', 'grama', 'folha', 'verde',
    '森', '林', '木', '庭', '草', '葉', 'みどり', '緑',
  ]),
  _Concept(['#00B3FF', '#1A4BFF', '#00C2A8', '#CFE8FF'],
      motion: SceneMotion.drift,
      words: [
        'sea', 'ocean', 'wave', 'beach', 'underwater', 'blue', //
        'mare', 'ocean', 'onda', 'onde', 'spiaggia', 'blu', 'azzurr',
        'meer', 'ozean', 'welle', 'strand', 'blau',
        'mer', 'ocean', 'vague', 'plage', 'bleu',
        'mar', 'ocean', 'ola', 'olas', 'playa', 'azul',
        'zee', 'ocean', 'golf', 'strand', 'blauw',
        'mar', 'ocean', 'onda', 'praia', 'azul',
        '海', 'うみ', '波', 'なみ', '浜', 'ビーチ', '青',
      ]),
  _Concept(['#0B2AA8', '#1A1A6E', '#5B2EFF', '#CFE8FF'],
      motion: SceneMotion.calm,
      words: [
        'night', 'star', 'midnight', //
        'notte', 'stell', 'mezzanotte',
        'nacht', 'stern', 'mitternacht',
        'nuit', 'etoil', 'minuit',
        'noche', 'estrell', 'medianoche',
        'nacht', 'ster', 'middernacht',
        'noite', 'estrel', 'meia-noite',
        '夜', 'よる', '星', 'ほし',
      ]),
  _Concept(['#CFE8FF', '#8FD3FF', '#FFF4E5'],
      motion: SceneMotion.calm,
      words: [
        'moon', 'luna', 'mond', 'lune', 'maan', 'lua', '月', 'つき', //
      ]),
  _Concept(['#FF6A00', '#FF2D2D', '#FFC300'],
      motion: SceneMotion.flicker,
      words: [
        'fire', 'flame', 'candle', 'campfire', 'fireplace', //
        'fuoco', 'fiamm', 'candel', 'falo', 'camino',
        'feuer', 'flamm', 'kerze', 'lagerfeuer', 'kamin',
        'feu', 'flamm', 'bougie', 'chandelle', 'cheminee',
        'fuego', 'llama', 'vela', 'hoguera', 'chimenea',
        'vuur', 'vlam', 'kaars', 'kampvuur', 'openhaard',
        'fogo', 'chama', 'vela', 'fogueira', 'lareira',
        '火', 'ほのお', '炎', 'ろうそく', 'キャンドル', 'たき火', '暖炉',
      ]),
  _Concept(['#FFFFFF', '#CFE8FF', '#8FD3FF'],
      motion: SceneMotion.calm,
      words: [
        'snow', 'winter', 'ice', 'frost', 'white', //
        'neve', 'invern', 'ghiacci', 'gelo', 'bianc',
        'schnee', 'winter', 'eis', 'frost', 'weiss',
        'neige', 'hiver', 'glace', 'givre', 'blanc',
        'nieve', 'invierno', 'hielo', 'escarcha', 'blanc',
        'sneeuw', 'winter', 'ijs', 'vorst', 'wit',
        'neve', 'inverno', 'gelo', 'geada', 'branc',
        '雪', 'ゆき', '冬', 'ふゆ', '氷', 'こおり', '白',
      ]),
  _Concept([
    '#FFC300',
    '#FF9A2E',
    '#FFD7A8',
    '#C2733D'
  ], words: [
    'desert', 'sand', 'dune', 'savanna', //
    'desert', 'sabbia', 'duna', 'dune', 'savana',
    'wuste', 'sand', 'dune', 'savanne',
    'desert', 'sable', 'dune', 'savane',
    'desiert', 'arena', 'duna', 'sabana',
    'woestijn', 'zand', 'duin', 'savanne',
    'desert', 'areia', 'duna', 'savana',
    '砂漠', 'さばく', '砂', 'すな',
  ]),
  _Concept([
    '#FF6F91',
    '#FFB7C5',
    '#B5E550',
    '#F9E04B'
  ], words: [
    'spring', 'flower', 'blossom', 'cherry', 'meadow', //
    'primaver', 'fior', 'ciliegi', 'sakura',
    'fruhling', 'blume', 'blute', 'kirsch',
    'printemps', 'fleur', 'cerisier',
    'primaver', 'flor', 'cerez',
    'lente', 'bloem', 'bloesem', 'kers',
    'primaver', 'flor', 'cerej',
    '春', 'はる', '花', 'はな', '桜', 'さくら',
  ]),
  _Concept([
    '#FF6A00',
    '#C2410C',
    '#FFC300',
    '#8B4513'
  ], words: [
    'autumn', 'fall', 'harvest', //
    'autunn', 'vendemmi',
    'herbst', 'ernte',
    'automne', 'recolte',
    'otono', 'cosecha',
    'herfst', 'oogst',
    'outono', 'colheita',
    '秋', 'あき', '紅葉', 'もみじ',
  ]),
  _Concept([
    '#FFC300',
    '#F9E04B',
    '#FF9A2E',
    '#00B3FF'
  ], words: [
    'summer', 'sun', 'sunny', 'yellow', //
    'estate', 'sole', 'solegg', 'giall',
    'sommer', 'sonne', 'sonnig', 'gelb',
    'ete', 'soleil', 'ensoleill', 'jaune',
    'verano', 'sol', 'soleado', 'amarill',
    'zomer', 'zon', 'zonnig', 'geel',
    'verao', 'sol', 'ensolarad', 'amarel',
    '夏', 'なつ', '太陽', 'たいよう', '黄',
  ]),
  _Concept(['#5A7DA8', '#8FD3FF', '#2E7BFF'],
      motion: SceneMotion.calm,
      words: [
        'rain', 'drizzle', 'cloud', 'grey', 'gray', //
        'pioggi', 'piove', 'nuvol', 'grigi',
        'regen', 'wolke', 'grau',
        'pluie', 'nuage', 'gris',
        'lluvia', 'llovizn', 'nube', 'gris',
        'regen', 'wolk', 'grijs',
        'chuva', 'garoa', 'nuvem', 'cinza',
        '雨', 'あめ', '雲', 'くも', '灰色',
      ]),
  _Concept(['#1A1A6E', '#5B2EFF', '#CFE8FF', '#2E7BFF'],
      motion: SceneMotion.lively,
      words: [
        'storm', 'thunder', 'lightning', //
        'tempest', 'temporal', 'tuono', 'fulmin', 'lampo',
        'sturm', 'gewitter', 'donner', 'blitz',
        'tempete', 'orage', 'tonnerre', 'eclair',
        'tormenta', 'tempestad', 'trueno', 'rayo', 'relampago',
        'storm', 'onweer', 'donder', 'bliksem',
        'tempestad', 'trovao', 'relampago', 'raio',
        '嵐', 'あらし', '雷', 'かみなり',
      ]),
  _Concept(['#FF2D2D', '#00B3FF', '#3DDC84', '#D23CFF', '#FFC300'],
      motion: SceneMotion.lively,
      words: [
        'party', 'disco', 'rainbow', 'carnival', 'festival', //
        'festa', 'discotec', 'arcobalen', 'carneval',
        'party', 'feier', 'disco', 'regenbogen', 'karneval', 'fasching',
        'fete', 'soiree', 'disco', 'arc-en-ciel', 'carnaval',
        'fiesta', 'disco', 'arcoiris', 'arco iris', 'carnaval',
        'feest', 'disco', 'regenboog', 'carnaval',
        'festa', 'balada', 'disco', 'arco-iris', 'carnaval',
        'パーティ', 'ディスコ', 'にじ', '虹', 'まつり', '祭',
      ]),
  _Concept(['#FF2D55', '#FF6F91', '#9B30FF', '#FFB7C5'],
      motion: SceneMotion.calm,
      words: [
        'love', 'romantic', 'valentine', 'pink', 'rose', //
        'amore', 'romantic', 'valentin', 'rosa',
        'liebe', 'romantisch', 'valentin', 'rosa',
        'amour', 'romantique', 'valentin', 'rose',
        'amor', 'romantic', 'valentin', 'rosa',
        'liefde', 'romantisch', 'valentijn', 'roze',
        'amor', 'romantic', 'namorad', 'rosa',
        '愛', 'こい', '恋', 'ロマンチック', 'ピンク', 'バラ',
      ]),
  _Concept([
    '#00C2A8',
    '#3DDC84',
    '#FFC300',
    '#FF4FC3'
  ], words: [
    'tropic', 'jungle', 'rainforest', 'island', 'palm', //
    'tropic', 'giungla', 'isola', 'palm',
    'tropen', 'tropisch', 'dschungel', 'regenwald', 'insel', 'palme',
    'tropic', 'jungle', 'ile', 'palmier',
    'tropic', 'jungla', 'isla', 'palmera',
    'tropisch', 'jungle', 'regenwoud', 'eiland', 'palm',
    'tropic', 'selva', 'ilha', 'palmeira',
    'ジャングル', '南国', '熱帯', '島', 'ヤシ',
  ]),
  _Concept(['#3DDC84', '#00C2A8', '#9B30FF', '#1A4BFF'],
      motion: SceneMotion.drift,
      words: [
        'aurora', 'northern', 'boreal', 'polar', 'nordlicht', //
        'noorderlicht', 'オーロラ',
      ]),
  _Concept([
    '#5B2EFF',
    '#0B2AA8',
    '#D23CFF',
    '#FF4FC3'
  ], words: [
    'space', 'galaxy', 'universe', 'cosmos', 'nebula', 'planet', //
    'spazio', 'galass', 'univers', 'cosmo', 'nebulosa', 'pianet',
    'weltall', 'weltraum', 'galaxi', 'univers', 'kosmos', 'nebel', 'planet',
    'espace', 'galaxie', 'univers', 'cosmos', 'nebuleuse', 'planete',
    'espacio', 'galaxia', 'univers', 'cosmos', 'nebulosa', 'planeta',
    'ruimte', 'heelal', 'melkweg', 'univers', 'kosmos', 'nevel', 'planeet',
    'espaco', 'galaxia', 'univers', 'cosmo', 'nebulosa', 'planeta',
    '宇宙', 'うちゅう', '銀河', 'ぎんが', '惑星',
  ]),
  _Concept([
    '#00C2A8',
    '#1A4BFF',
    '#8FD3FF',
    '#3D7A5A'
  ], words: [
    'lake', 'river', 'pond', 'waterfall', //
    'lago', 'fiume', 'stagno', 'cascat',
    'see', 'fluss', 'teich', 'wasserfall', 'bach',
    'lac', 'riviere', 'fleuve', 'etang', 'cascade',
    'lago', 'rio', 'estanque', 'cascad',
    'meer', 'rivier', 'vijver', 'waterval', 'beek',
    'lago', 'rio', 'lagoa', 'cachoeira', 'cascat',
    '湖', 'みずうみ', '川', 'かわ', '池', '滝',
  ]),
  _Concept([
    '#8FD3FF',
    '#FFFFFF',
    '#3D7A5A',
    '#6E7F96'
  ], words: [
    'mountain', 'alps', 'peak', 'hill', //
    'montagn', 'alpi', 'vetta', 'collin',
    'berg', 'alpen', 'gipfel', 'hugel',
    'montagne', 'alpes', 'sommet', 'colline',
    'montana', 'alpes', 'cumbre', 'colina',
    'berg', 'alpen', 'top', 'heuvel',
    'montanha', 'alpes', 'cume', 'colina', 'serra',
    '山', 'やま', '丘',
  ]),
  _Concept(['#FF2D2D', '#1E7F3A', '#FFD700', '#FFF4E5'],
      motion: SceneMotion.flicker,
      words: [
        'christmas', 'xmas', //
        'natal', 'natale',
        'weihnacht', 'advent',
        'noel', 'avent',
        'navidad', 'adviento',
        'kerst', 'advent',
        'natal', 'advento',
        'クリスマス',
      ]),
  _Concept(['#FF6A00', '#9B30FF', '#3DDC84'],
      motion: SceneMotion.flicker,
      words: [
        'halloween', 'spooky', 'ghost', 'witch', 'pumpkin', //
        'fantasm', 'strega', 'zucca',
        'gespenst', 'geist', 'hexe', 'kurbis',
        'fantome', 'sorciere', 'citrouille',
        'fantasma', 'bruja', 'calabaza',
        'spook', 'heks', 'pompoen',
        'fantasma', 'bruxa', 'abobora',
        'ハロウィン', 'おばけ', 'まじょ', '魔女', 'かぼちゃ',
      ]),
  _Concept(['#FF9A2E', '#FFD7A8', '#FF6A00', '#FFE9C9'],
      motion: SceneMotion.calm,
      words: [
        'cozy', 'cosy', 'warm', 'home', 'reading', 'book', //
        'accoglien', 'calda', 'caldo', 'casa', 'lettura', 'libro',
        'gemutlich', 'warm', 'zuhause', 'lesen', 'buch',
        'cosy', 'chaleur', 'chaud', 'maison', 'lecture', 'livre',
        'acogedor', 'calido', 'calida', 'hogar', 'lectura', 'libro',
        'gezellig', 'knus', 'warm', 'thuis', 'lezen', 'boek',
        'aconcheg', 'quente', 'lar', 'leitura', 'livro',
        'あたたか', '暖か', '温か', '家', '読書',
      ]),
];

/// Lower case, accents taken off (`é` → `e`, `ß` → `ss`).
String _plain(String text) {
  const from = 'àáâãäåèéêëìíîïòóôõöùúûüçñœ';
  const to = 'aaaaaaeeeeiiiiooooouuuucno';
  final buffer = StringBuffer();
  for (final char in text.toLowerCase().split('')) {
    final i = from.indexOf(char);
    buffer.write(switch (char) {
      'ß' => 'ss',
      _ when i >= 0 => to[i],
      _ => char,
    });
  }
  return buffer.toString();
}

/// Whether [word] starts with [stem]; a short stem ("mer", "sol") only
/// counts as the whole word or its plural.
bool _matches(String word, String stem) => stem.length <= 3
    ? word == stem || word == '${stem}s'
    : word.startsWith(stem);

bool _isLatin(String word) => RegExp(r'^[a-z\- ]+$').hasMatch(word);

/// A scene drawn from a sentence like "forest at sunset": the colours of
/// each thing it names, mixed, and the motion it suggests. Offline, in
/// the eight languages; null when no word is known.
({List<String> colors, SceneMotion motion})? sceneFromSentence(String text) {
  final plain = _plain(text);
  final words = [
    for (final word in plain.split(RegExp(r'[^a-z\-]+')))
      if (word.isNotEmpty) word,
  ];
  // For each word, the concept whose beginning matches it longest
  // ("sunset" is sunset, not sun); phrases and Japanese are found in the
  // whole sentence.
  final found = <(int, _Concept)>[];
  void add(int at, _Concept concept) {
    if (!found.any((f) => identical(f.$2, concept))) {
      found.add((at, concept));
    }
  }

  var at = 0;
  for (final word in words) {
    _Concept? best;
    var length = 0;
    for (final concept in _concepts) {
      for (final stem in concept.words) {
        if (_isLatin(stem) &&
            !stem.contains(' ') &&
            stem.length > length &&
            _matches(word, stem)) {
          best = concept;
          length = stem.length;
        }
      }
    }
    if (best != null) {
      add(at, best);
    }
    at++;
  }
  for (final concept in _concepts) {
    for (final stem in concept.words) {
      if (!_isLatin(stem) || stem.contains(' ')) {
        final index = plain.indexOf(stem);
        if (index >= 0) {
          // After the words: an order by position in the sentence.
          add(1000 + index, concept);
        }
      }
    }
  }
  // The motion said with the longest word ("funkelnd" twinkles, it is
  // not "fun").
  SceneMotion? said;
  var saidLength = 0;
  for (final MapEntry(key: motion, value: stems) in _motionWords.entries) {
    for (final stem in stems) {
      final hit = _isLatin(stem)
          ? words.any((w) => _matches(w, stem))
          : plain.contains(stem);
      if (hit && stem.length > saidLength) {
        said = motion;
        saidLength = stem.length;
      }
    }
  }
  if (found.isEmpty) {
    return null;
  }
  found.sort((a, b) => a.$1.compareTo(b.$1));
  final concepts = [for (final (_, c) in found) c];
  // Take the colours in turns, so two things both show.
  final colors = <String>[];
  for (var i = 0; colors.length < UserScene.maxColors; i++) {
    var any = false;
    for (final concept in concepts) {
      if (i < concept.colors.length) {
        any = true;
        if (!colors.contains(concept.colors[i]) &&
            colors.length < UserScene.maxColors) {
          colors.add(concept.colors[i]);
        }
      }
    }
    if (!any) {
      break;
    }
  }
  final motion = said ??
      concepts.map((c) => c.motion).whereType<SceneMotion>().firstOrNull ??
      SceneMotion.drift;
  return (colors: colors, motion: motion);
}
