import 'package:flutter/material.dart';

import '../../core/effects/effect.dart';
import '../../core/effects/effect_event.dart';
import '../common/app_text.dart';

/// A choice at the end of a part: two ways on, each to another part.
class PathChoice {
  const PathChoice(
      {required this.label, required this.next, required this.icon});

  final String Function(AppLocalizations) label;
  final String next;

  /// Shown on the choice's button.
  final IconData icon;
}

/// One part of a choose-your-path story: lights and words for [seconds],
/// then either two choices or the end.
class PathPart {
  const PathPart({
    required this.id,
    required this.seconds,
    required this.lines,
    required this.events,
    this.choices,
  });

  final String id;
  final int seconds;
  final List<(int, String Function(AppLocalizations))> lines;
  final List<EffectEvent> events;

  /// Null for an ending.
  final (PathChoice, PathChoice)? choices;

  bool get isEnding => choices == null;
}

/// A story where the listener chooses the way at its turns.
class PathStory {
  const PathStory({
    required this.id,
    required this.title,
    required this.description,
    required this.parts,
  });

  final String id;
  final String Function(AppLocalizations) title;
  final String Function(AppLocalizations) description;

  /// The first part is where the story starts.
  final List<PathPart> parts;

  static const _prefix = '${LightingEffect.generatedPrefix}path:';

  /// How long a part waits for a choice before it gives up.
  static const waitForChoice = Duration(minutes: 10);

  /// How long the light lingers after an ending.
  static const endingTail = Duration(seconds: 4);

  PathPart get start => parts.first;

  PathPart part(String id) => parts.firstWhere((p) => p.id == id);

  /// The lights of [part]. A part with choices then keeps its last
  /// background while the listener decides; an ending plays once.
  LightingEffect effectOf(PathPart part, AppLocalizations l10n) =>
      LightingEffect(
        id: '$_prefix$id:${part.id}',
        name: title(l10n),
        kind: EffectKind.story,
        isLooping: false,
        loopDuration: Duration(seconds: part.seconds) +
            (part.isEnding ? endingTail : waitForChoice),
        events: part.events,
      );

  /// The story and part of a path effect, or null for any other effect.
  static (PathStory, PathPart)? of(LightingEffect effect) {
    if (!effect.id.startsWith(_prefix)) {
      return null;
    }
    final [storyId, partId, ...] = [
      ...effect.id.substring(_prefix.length).split(':'),
      '',
      '',
    ];
    for (final story in pathStories) {
      if (story.id == storyId) {
        for (final part in story.parts) {
          if (part.id == partId) {
            return (story, part);
          }
        }
      }
    }
    return null;
  }

  /// The words of [part], read along and read aloud.
  static List<(int, String)> narrationOf(
          PathPart part, AppLocalizations l10n) =>
      [for (final (at, text) in part.lines) (at, text(l10n))];
}

EffectEvent _ambient(
  int at,
  int seconds,
  List<String> palette, {
  double low = 0.25,
  double high = 0.6,
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

EffectEvent _flash(int at, String color,
        {String target = 'all', int ms = 1500}) =>
    EffectEvent(
      at: Duration(seconds: at),
      duration: Duration(milliseconds: ms),
      type: EffectEventTypes.magicFlash,
      parameters: {'color': color, 'target': target, 'brightness': 0.9},
    );

EffectEvent _surprise(int at, int seconds, String color, {int count = 4}) =>
    EffectEvent(
      at: Duration(seconds: at),
      duration: Duration(seconds: seconds),
      type: EffectEventTypes.surprise,
      parameters: {'color': color, 'count': count, 'brightness': 0.8},
    );

EffectEvent _travel(int at, int seconds, String color,
        {String pattern = 'random_walk'}) =>
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

const _night = ['#0B1033', '#1C2A6B', '#2E3F8F'];
const _starlit = ['#0B1033', '#1C2A6B', '#FFE7A3'];
const _forest = ['#0E3B1E', '#1F6B3A', '#3A8F4F'];
const _lake = ['#0B3C5D', '#1E6F9F', '#C9E4F2'];
const _cave = ['#2A1405', '#5A2A0A', '#8A4A12'];
const _fire = ['#FF7A1A', '#FFB347', '#FFD27F'];

/// A little star fell from the sky: two turns, four endings.
final lostStar = PathStory(
  id: 'lost_star',
  title: (l) => l.pathLostStar,
  description: (l) => l.pathLostStarDescription,
  parts: [
    PathPart(
      id: 'start',
      seconds: 18,
      lines: [(0, (l) => l.pathLostStar1), (9, (l) => l.pathLostStar2)],
      events: [
        _ambient(0, 18, _night, low: 0.12, high: 0.3),
        _travel(2, 5, '#FFE7A3', pattern: 'sweep'),
        _flash(7, '#FFE7A3', target: 'random_light'),
      ],
      choices: (
        PathChoice(
            label: (l) => l.pathChoiceForest,
            next: 'forest',
            icon: Icons.park_outlined),
        PathChoice(
            label: (l) => l.pathChoiceLake,
            next: 'lake',
            icon: Icons.water_outlined),
      ),
    ),
    PathPart(
      id: 'forest',
      seconds: 18,
      lines: [
        (0, (l) => l.pathLostStarForest1),
        (9, (l) => l.pathLostStarForest2)
      ],
      events: [
        _ambient(0, 18, _forest, low: 0.15, high: 0.35),
        _surprise(2, 8, '#D4FF5C', count: 6),
      ],
      choices: (
        PathChoice(
            label: (l) => l.pathChoiceGlowingPath,
            next: 'glow',
            icon: Icons.auto_awesome_outlined),
        PathChoice(
            label: (l) => l.pathChoiceDarkPath,
            next: 'owl',
            icon: Icons.dark_mode_outlined),
      ),
    ),
    PathPart(
      id: 'glow',
      seconds: 16,
      lines: [(0, (l) => l.pathLostStarGlow1), (8, (l) => l.pathLostStarGlow2)],
      events: [
        _ambient(0, 8, _forest, low: 0.2, high: 0.45),
        _surprise(0, 6, '#D4FF5C', count: 6),
        _flash(6, '#FFE7A3'),
        _ambient(8, 8, _starlit, low: 0.15, high: 0.45),
        _travel(9, 5, '#FFE7A3', pattern: 'sweep'),
      ],
    ),
    PathPart(
      id: 'owl',
      seconds: 16,
      lines: [(0, (l) => l.pathLostStarOwl1), (8, (l) => l.pathLostStarOwl2)],
      events: [
        _ambient(0, 8, const ['#06140B', '#0E3B1E'], low: 0.06, high: 0.15),
        _flash(2, '#FFD54F', target: 'random_light', ms: 800),
        _flash(3, '#FFD54F', target: 'random_light', ms: 800),
        _ambient(8, 8, _starlit, low: 0.15, high: 0.45),
        _travel(9, 5, '#FFE7A3', pattern: 'sweep'),
      ],
    ),
    PathPart(
      id: 'lake',
      seconds: 18,
      lines: [(0, (l) => l.pathLostStarLake1), (9, (l) => l.pathLostStarLake2)],
      events: [
        _ambient(0, 18, _lake, low: 0.2, high: 0.45, speed: 0.02),
        _flash(6, '#FFE7A3', target: 'random_light'),
      ],
      choices: (
        PathChoice(
            label: (l) => l.pathChoiceDive,
            next: 'dive',
            icon: Icons.pool_outlined),
        PathChoice(
            label: (l) => l.pathChoiceFrog,
            next: 'frog',
            icon: Icons.emoji_nature_outlined),
      ),
    ),
    PathPart(
      id: 'dive',
      seconds: 16,
      lines: [(0, (l) => l.pathLostStarDive1), (8, (l) => l.pathLostStarDive2)],
      events: [
        _ambient(0, 8, const ['#04223A', '#0B3C5D', '#1E6F9F'],
            low: 0.1, high: 0.3),
        _surprise(1, 5, '#C9E4F2', count: 5),
        _flash(6, '#FFE7A3'),
        _ambient(8, 8, _starlit, low: 0.15, high: 0.45),
        _surprise(9, 5, '#FFE7A3', count: 5),
      ],
    ),
    PathPart(
      id: 'frog',
      seconds: 16,
      lines: [(0, (l) => l.pathLostStarFrog1), (8, (l) => l.pathLostStarFrog2)],
      events: [
        _ambient(0, 8, _lake, low: 0.2, high: 0.45),
        _travel(1, 4, '#7CFF6B', pattern: 'ping_pong'),
        _flash(6, '#FFE7A3'),
        _ambient(8, 8, _starlit, low: 0.15, high: 0.45),
        _travel(9, 5, '#FFE7A3', pattern: 'sweep'),
      ],
    ),
  ],
);

/// A dragon's egg about to hatch: one turn, two endings.
final dragonEgg = PathStory(
  id: 'dragon_egg',
  title: (l) => l.pathDragonEgg,
  description: (l) => l.pathDragonEggDescription,
  parts: [
    PathPart(
      id: 'start',
      seconds: 18,
      lines: [(0, (l) => l.pathDragonEgg1), (9, (l) => l.pathDragonEgg2)],
      events: [
        _ambient(0, 18, _cave, low: 0.1, high: 0.3),
        _flash(4, '#FFB347', target: 'random_light'),
        _flash(8, '#FFB347', target: 'random_light'),
      ],
      choices: (
        PathChoice(
            label: (l) => l.pathChoiceWarm,
            next: 'warm',
            icon: Icons.local_fire_department_outlined),
        PathChoice(
            label: (l) => l.pathChoiceSing,
            next: 'sing',
            icon: Icons.music_note_outlined),
      ),
    ),
    PathPart(
      id: 'warm',
      seconds: 16,
      lines: [
        (0, (l) => l.pathDragonEggWarm1),
        (8, (l) => l.pathDragonEggWarm2)
      ],
      events: [
        _ambient(0, 16, _fire, low: 0.3, high: 0.7, speed: 0.06),
        _flash(6, '#FFFFFF'),
        _surprise(8, 6, '#FF7A1A', count: 6),
      ],
    ),
    PathPart(
      id: 'sing',
      seconds: 16,
      lines: [
        (0, (l) => l.pathDragonEggSing1),
        (8, (l) => l.pathDragonEggSing2)
      ],
      events: [
        _ambient(0, 8, _cave, low: 0.2, high: 0.45, speed: 0.08),
        _flash(6, '#FFD27F'),
        _ambient(8, 8, const ['#3A1D0A', '#5A2A0A'],
            low: 0.08, high: 0.15, speed: 0.01),
      ],
    ),
  ],
);

final pathStories = [lostStar, dragonEgg];
