import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/effects/effect.dart';
import '../../core/effects/effect_event.dart';
import '../common/app_text.dart';
import '../library/user_scene.dart';
import '../library/user_story.dart';

/// Who a made-up story is about.
enum TaleHero {
  fox('Pip', '#FF7A1A', Icons.pets),
  robot('Bip', '#3FA9F5', Icons.smart_toy_outlined),
  dragon('Zuzu', '#5CFF7A', Icons.local_fire_department_outlined),
  unicorn('Luma', '#FF8AD8', Icons.auto_awesome_outlined),
  owl('Momo', '#FFC94D', Icons.visibility_outlined),
  kitten('Kiki', '#F4F1E8', Icons.cruelty_free_outlined),
  penguin('Ollie', '#9FD8FF', Icons.ac_unit),
  turtle('Toto', '#7CFF6B', Icons.eco_outlined);

  const TaleHero(this.defaultName, this.color, this.icon);

  /// A name that reads well in every language, until the child picks one.
  final String defaultName;

  /// The hero's own light.
  final String color;
  final IconData icon;

  String label(AppLocalizations l10n) => switch (this) {
        fox => l10n.taleFox,
        robot => l10n.taleRobot,
        dragon => l10n.taleDragon,
        unicorn => l10n.taleUnicorn,
        owl => l10n.taleOwl,
        kitten => l10n.taleKitten,
        penguin => l10n.talePenguin,
        turtle => l10n.taleTurtle,
      };

  /// "a little fox with a fluffy red tail", after the hero's name.
  String intro(AppLocalizations l10n) => switch (this) {
        fox => l10n.taleFoxIntro,
        robot => l10n.taleRobotIntro,
        dragon => l10n.taleDragonIntro,
        unicorn => l10n.taleUnicornIntro,
        owl => l10n.taleOwlIntro,
        kitten => l10n.taleKittenIntro,
        penguin => l10n.talePenguinIntro,
        turtle => l10n.taleTurtleIntro,
      };
}

/// Where a made-up story goes.
enum TalePlace {
  forest(['#0E3B1E', '#1F6B3A', '#3A8F4F'], Icons.park_outlined),
  sea(['#04223A', '#0B3C5D', '#1E6F9F'], Icons.water_outlined),
  space(['#05081F', '#14195A', '#3B2C7A'], Icons.rocket_launch_outlined),
  castle(['#F6C6EA', '#C9B6F2', '#FFE7F5'], Icons.castle_outlined),
  mountain(['#7FA7D1', '#BFD9F2', '#E8F1FA'], Icons.landscape_outlined),
  jungle(['#0E3B1E', '#2E7D32', '#7CB342'], Icons.forest_outlined),
  island(['#0B3C5D', '#1E6F9F', '#F4D58D'], Icons.beach_access_outlined);

  const TalePlace(this.palette, this.icon);

  final List<String> palette;
  final IconData icon;

  String label(AppLocalizations l10n) => switch (this) {
        forest => l10n.taleForest,
        sea => l10n.taleSea,
        space => l10n.taleSpace,
        castle => l10n.taleCastle,
        mountain => l10n.taleMountain,
        jungle => l10n.taleJungle,
        island => l10n.taleIsland,
      };

  String line(AppLocalizations l10n, String name) => switch (this) {
        forest => l10n.taleForestLine(name),
        sea => l10n.taleSeaLine(name),
        space => l10n.taleSpaceLine(name),
        castle => l10n.taleCastleLine(name),
        mountain => l10n.taleMountainLine(name),
        jungle => l10n.taleJungleLine(name),
        island => l10n.taleIslandLine(name),
      };
}

/// What happens in a made-up story: a problem, then the hero mends it.
enum TaleQuest {
  star(Icons.star_outline),
  rainbow(Icons.looks_outlined),
  treasure(Icons.map_outlined),
  firefly(Icons.flare),
  dark(Icons.nightlight_outlined),
  teddy(Icons.toys_outlined),
  moon(Icons.nightlight_round);

  const TaleQuest(this.icon);

  final IconData icon;

  String label(AppLocalizations l10n) => switch (this) {
        star => l10n.taleStar,
        rainbow => l10n.taleRainbow,
        treasure => l10n.taleTreasure,
        firefly => l10n.taleFirefly,
        dark => l10n.taleDark,
        teddy => l10n.taleTeddy,
        moon => l10n.taleMoon,
      };

  String problem(AppLocalizations l10n, String name) => switch (this) {
        star => l10n.taleStar1(name),
        rainbow => l10n.taleRainbow1(name),
        treasure => l10n.taleTreasure1(name),
        firefly => l10n.taleFirefly1(name),
        dark => l10n.taleDark1(name),
        teddy => l10n.taleTeddy1(name),
        moon => l10n.taleMoon1(name),
      };

  String solution(AppLocalizations l10n, String name) => switch (this) {
        star => l10n.taleStar2(name),
        rainbow => l10n.taleRainbow2(name),
        treasure => l10n.taleTreasure2(name),
        firefly => l10n.taleFirefly2(name),
        dark => l10n.taleDark2(name),
        teddy => l10n.taleTeddy2(name),
        moon => l10n.taleMoon2(name),
      };
}

/// A bedtime story made up from a hero, a place and an adventure: five
/// lines, each with its own lights, ending in a warm glow that fades.
class Tale {
  const Tale({
    required this.hero,
    required this.place,
    required this.quest,
    required this.name,
  });

  /// Any hero, place and adventure, with the hero's own name unless
  /// [name] is given.
  factory Tale.random(math.Random random, {String? name}) {
    final hero = TaleHero.values[random.nextInt(TaleHero.values.length)];
    return Tale(
      hero: hero,
      place: TalePlace.values[random.nextInt(TalePlace.values.length)],
      quest: TaleQuest.values[random.nextInt(TaleQuest.values.length)],
      name: name ?? hero.defaultName,
    );
  }

  final TaleHero hero;
  final TalePlace place;
  final TaleQuest quest;

  /// The hero's name, as the child typed it.
  final String name;

  static const _prefix = '${LightingEffect.generatedPrefix}tale:';

  /// The longest name kept: it is read aloud five times.
  static const maxName = 24;

  /// When each line starts, in seconds, and how long the story lasts.
  static const _intro = 0, _place = 9, _problem = 19, _solution = 30;
  static const _ending = 42, _length = 56;

  String get id => '$_prefix${hero.name}:${place.name}:${quest.name}:'
      '${Uri.encodeComponent(name)}';

  /// The tale an effect tells, or null for any other effect.
  static Tale? of(LightingEffect effect) {
    if (!effect.id.startsWith(_prefix)) {
      return null;
    }
    final parts = effect.id.substring(_prefix.length).split(':');
    if (parts.length != 4) {
      return null;
    }
    final hero = TaleHero.values.asNameMap()[parts[0]];
    final place = TalePlace.values.asNameMap()[parts[1]];
    final quest = TaleQuest.values.asNameMap()[parts[2]];
    final String name;
    try {
      name = Uri.decodeComponent(parts[3]);
    } on ArgumentError {
      return null;
    }
    if (hero == null || place == null || quest == null || name.isEmpty) {
      return null;
    }
    return Tale(hero: hero, place: place, quest: quest, name: name);
  }

  String title(AppLocalizations l10n) => l10n.taleTitle(name);

  /// The tale kept among the user's own stories, to play again: the
  /// place's colours, the same words, a light for each line.
  UserStory toUserStory(AppLocalizations l10n) {
    final lines = narration(l10n);
    final kinds = [
      (StoryMomentKind.wander, hero.color),
      (StoryMomentKind.sparkles, place.palette.last),
      (StoryMomentKind.darkness, null),
      (StoryMomentKind.spell, '#FFE7A3'),
      (StoryMomentKind.wordsOnly, null),
    ];
    return UserStory(
      id: UserStory.newId(),
      name: UserStory.clip(title(l10n), UserStory.maxName),
      colors: place.palette,
      motion: SceneMotion.calm,
      length: UserStory.defaultLength,
      moments: [
        for (final ((at, words), (kind, color)) in [
          for (var i = 0; i < lines.length; i++) (lines[i], kinds[i]),
        ])
          StoryMoment(
            at: at,
            kind: kind,
            color: color,
            words: UserStory.clip(words, UserStory.maxWords),
          ),
      ],
    );
  }

  /// The words, with the second each line starts.
  List<(int, String)> narration(AppLocalizations l10n) => [
        (_intro, l10n.taleIntro(name, hero.intro(l10n))),
        (_place, place.line(l10n, name)),
        (_problem, quest.problem(l10n, name)),
        (_solution, quest.solution(l10n, name)),
        (_ending, l10n.taleEnding(name)),
      ];

  LightingEffect effect(AppLocalizations l10n) => LightingEffect(
        id: id,
        name: title(l10n),
        kind: EffectKind.story,
        isLooping: false,
        loopDuration: const Duration(seconds: _length),
        events: [
          // The hero arrives in the night.
          _ambient(_intro, _place - _intro, _night, low: 0.12, high: 0.3),
          _travel(_intro + 1, 6, hero.color),
          _flash(_intro + 7, hero.color, target: 'random_light'),
          // The place.
          _ambient(_place, _problem - _place, place.palette),
          ..._placeAccent(),
          // The adventure.
          ..._questEvents(),
          // Home, and to sleep: a warm glow that fades.
          _ramp(_ending, _length - _ending, 0.45, 0.06,
              color: '#FFB347', toColor: '#FF8A3D'),
        ],
      );

  List<EffectEvent> _placeAccent() {
    const at = _place + 1;
    return switch (place) {
      TalePlace.forest => [_surprise(at, 8, '#D4FF5C', count: 6)],
      TalePlace.sea => [_travel(at, 7, '#7FDBFF', pattern: 'ping_pong')],
      TalePlace.space => [
          _travel(at, 4, '#C9E4F2', pattern: 'sweep'),
          _surprise(at + 4, 5, '#FFFFFF', count: 5),
        ],
      TalePlace.castle => [
          for (final (i, color) in _rainbow.indexed)
            _flash(at + i, color, position: i / (_rainbow.length - 1)),
        ],
      TalePlace.mountain => [_surprise(at, 8, '#FFFFFF', count: 6)],
      TalePlace.jungle => [_travel(at, 7, '#FF7A1A', pattern: 'ping_pong')],
      TalePlace.island => [_surprise(at, 8, '#9FE3FF', count: 5)],
    };
  }

  List<EffectEvent> _questEvents() {
    const p = _problem, s = _solution, end = _ending;
    return switch (quest) {
      TaleQuest.star => [
          _ambient(p, s - p, place.palette, low: 0.08, high: 0.2),
          for (final at in [p + 1, p + 4, p + 7])
            _flash(at, '#FFE7A3', target: 'random_light', ms: 900, bright: 0.5),
          _ambient(s, end - s, _starlit, low: 0.15, high: 0.45),
          _travel(s + 1, 4, '#FFE7A3', pattern: 'sweep'),
          _flash(s + 5, '#FFE7A3', ms: 2500),
          _surprise(s + 6, 6, '#FFE7A3', count: 6),
        ],
      TaleQuest.rainbow => [
          _ambient(p, s - p, const ['#3A3A3A', '#5A5A5A', '#7A7A7A'],
              low: 0.1, high: 0.25, speed: 0.02),
          for (final (i, color) in _rainbow.indexed)
            _flash(s + 1 + i, color,
                position: i / (_rainbow.length - 1), ms: 2000),
          _ambient(s + 7, end - s - 7, _rainbow,
              low: 0.3, high: 0.6, speed: 0.06),
        ],
      TaleQuest.treasure => [
          _ambient(p, s - p, place.palette),
          _flash(p + 2, '#C8A165', ms: 2000),
          _ambient(s, end - s, place.palette, low: 0.1, high: 0.25),
          _footsteps(s + 1, 5, hero.color),
          _flash(s + 6, '#FFC94D', ms: 3000),
          _ambient(s + 7, end - s - 7, const ['#B8860B', '#FFC94D', '#FFE7A3'],
              low: 0.35, high: 0.7),
        ],
      TaleQuest.firefly => [
          _ambient(p, s - p, place.palette, low: 0.05, high: 0.12),
          for (final at in [p + 2, p + 5])
            _flash(at, '#D4FF5C', target: 'random_light', ms: 600, bright: 0.3),
          _ambient(s, end - s, place.palette),
          _flash(s + 1, '#D4FF5C', target: 'random_light'),
          _surprise(s + 2, end - s - 2, '#D4FF5C', count: 10),
        ],
      TaleQuest.dark => [
          _ramp(p, 6, 0.3, 0.03, color: '#1C2A6B'),
          _ambient(p + 6, s - p - 6, const ['#05081F', '#0B1033'],
              low: 0.02, high: 0.06),
          _ramp(s, 10, 0.03, 0.45, color: '#0B1033', toColor: '#FFB347'),
          for (var i = 0; i < 4; i++)
            _flash(s + 1 + 2 * i, '#FFD27F', position: i / 3, ms: 2500),
          _ambient(s + 10, end - s - 10, _fire, low: 0.3, high: 0.5),
        ],
      TaleQuest.teddy => [
          _ambient(p, s - p, place.palette, low: 0.08, high: 0.2),
          for (final at in [p + 2, p + 6])
            _flash(at, '#FFB37A', target: 'random_light', ms: 900, bright: 0.4),
          _ambient(s, end - s, const ['#FF9F43', '#FFB37A', '#FFD27F'],
              low: 0.3, high: 0.55),
          _travel(s + 1, 6, '#FFD27F'),
          _flash(s + 7, '#FFB37A', ms: 2500),
        ],
      TaleQuest.moon => [
          _ramp(p, 6, 0.25, 0.03, color: '#14195A'),
          _ambient(p + 6, s - p - 6, const ['#05081F', '#0B1033'],
              low: 0.02, high: 0.06),
          _ramp(s, 8, 0.03, 0.45, color: '#0B1033', toColor: '#E8EEFF'),
          _ambient(s + 8, end - s - 8, const ['#9FB4FF', '#E8EEFF', '#14195A'],
              low: 0.25, high: 0.45),
          _surprise(s + 8, end - s - 8, '#FFFFFF', count: 5),
        ],
    };
  }
}

const _night = ['#0B1033', '#1C2A6B', '#2E3F8F'];
const _starlit = ['#0B1033', '#1C2A6B', '#FFE7A3'];
const _fire = ['#FF7A1A', '#FFB347', '#FFD27F'];
const _rainbow = [
  '#FF3B30', '#FF9500', '#FFD60A', '#34C759', '#0A84FF', '#AF52DE', //
];

EffectEvent _ambient(
  int at,
  int seconds,
  List<String> palette, {
  double low = 0.25,
  double high = 0.55,
  double speed = 0.04,
}) =>
    EffectEvent(
      at: Duration(seconds: at),
      duration: Duration(seconds: seconds),
      type: EffectEventTypes.ambientPalette,
      parameters: {
        'palette': palette,
        'brightnessMin': low,
        'brightnessMax': high,
        'speed': speed,
      },
    );

EffectEvent _flash(
  int at,
  String color, {
  String target = 'all',
  double? position,
  int ms = 1500,
  double bright = 0.9,
}) =>
    EffectEvent(
      at: Duration(seconds: at),
      duration: Duration(milliseconds: ms),
      type: EffectEventTypes.magicFlash,
      parameters: {
        'color': color,
        'target': position == null ? target : 'position',
        if (position != null) 'position': position,
        'brightness': bright,
      },
    );

EffectEvent _surprise(int at, int seconds, String color, {int count = 4}) =>
    EffectEvent(
      at: Duration(seconds: at),
      duration: Duration(seconds: seconds),
      type: EffectEventTypes.surprise,
      parameters: {'color': color, 'count': count, 'brightness': 0.8},
    );

EffectEvent _travel(int at, int seconds, String color,
        {String pattern = 'sweep'}) =>
    EffectEvent(
      at: Duration(seconds: at),
      duration: Duration(seconds: seconds),
      type: EffectEventTypes.travel,
      parameters: {
        'color': color,
        'pattern': pattern,
        'stepDuration': 900,
        'brightness': 0.9,
      },
    );

EffectEvent _footsteps(int at, int seconds, String color) => EffectEvent(
      at: Duration(seconds: at),
      duration: Duration(seconds: seconds),
      type: EffectEventTypes.footsteps,
      parameters: {'color': color, 'steps': 7, 'brightness': 0.8},
    );

EffectEvent _ramp(int at, int seconds, double from, double to,
        {required String color, String? toColor}) =>
    EffectEvent(
      at: Duration(seconds: at),
      duration: Duration(seconds: seconds),
      type: EffectEventTypes.ramp,
      parameters: {
        'from': from,
        'to': to,
        'color': color,
        if (toColor != null) 'toColor': toColor,
      },
    );
