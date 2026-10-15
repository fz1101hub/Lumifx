import '../../../core/effects/effect.dart';
import '../../../core/effects/effect_event.dart';

/// A mischievous forest sprite: dim greens, a golden spark, something
/// running from lamp to lamp, a moment of darkness, then gold everywhere.
const emeraldTrickster = LightingEffect(
  id: 'emerald_trickster',
  name: 'Emerald Trickster',
  kind: EffectKind.story,
  collection: 'Magic & Fantasy',
  description: 'Something small and green is hiding in the room. '
      'Watch for golden sparks.',
  loopDuration: Duration(seconds: 40),
  events: [
    EffectEvent(
      at: Duration.zero,
      duration: Duration(seconds: 8),
      type: EffectEventTypes.ambientPalette,
      parameters: {
        'palette': <String>['#063B20', '#0F8F45', '#56E56F'],
        'brightnessMin': 0.20,
        'brightnessMax': 0.55,
        'speed': 0.04,
      },
    ),
    EffectEvent(
      at: Duration(seconds: 8),
      duration: Duration(milliseconds: 700),
      type: EffectEventTypes.magicFlash,
      parameters: {
        'color': '#FFD84D',
        'target': 'random_light',
      },
    ),
    EffectEvent(
      at: Duration(seconds: 11),
      duration: Duration(seconds: 9),
      type: EffectEventTypes.travel,
      parameters: {
        'color': '#22D763',
        'pattern': 'random_walk',
        'stepDuration': 800,
      },
    ),
    EffectEvent(
      at: Duration(seconds: 20),
      duration: Duration(seconds: 3),
      type: EffectEventTypes.dim,
      parameters: {'level': 0.08},
    ),
    EffectEvent(
      at: Duration(seconds: 23),
      duration: Duration(seconds: 4),
      type: EffectEventTypes.surprise,
      parameters: {
        'color': '#FFCE3A',
        'count': 3,
      },
    ),
    EffectEvent(
      at: Duration(seconds: 27),
      duration: Duration(seconds: 13),
      type: EffectEventTypes.ambientPalette,
      parameters: {
        'palette': <String>['#0B7A3B', '#FFC93A', '#1FCB5C', '#FFE07A'],
        'brightnessMin': 0.45,
        'brightnessMax': 0.95,
        'speed': 0.08,
      },
    ),
  ],
);

/// A dragon asleep in the corner: slow ember breathing, the occasional
/// snort of fire travelling across the room.
const sleepingDragon = LightingEffect(
  id: 'sleeping_dragon',
  name: 'Sleeping Dragon',
  kind: EffectKind.story,
  collection: 'Magic & Fantasy',
  description: 'Do not wake it. Embers rise and fall with every breath.',
  loopDuration: Duration(seconds: 36),
  events: [
    EffectEvent(
      at: Duration.zero,
      duration: Duration(seconds: 36),
      type: EffectEventTypes.ambientPalette,
      parameters: {
        'palette': <String>['#3A0A02', '#8C1C04', '#C2410C'],
        'brightnessMin': 0.10,
        'brightnessMax': 0.50,
        'speed': 0.06,
      },
    ),
    EffectEvent(
      at: Duration(seconds: 14),
      duration: Duration(seconds: 3),
      type: EffectEventTypes.travel,
      parameters: {
        'color': '#FF7A1A',
        'pattern': 'sweep',
        'width': 1.6,
        'brightness': 1.0,
      },
    ),
    EffectEvent(
      at: Duration(seconds: 17),
      duration: Duration(seconds: 2),
      type: EffectEventTypes.dim,
      parameters: {'level': 0.25},
    ),
    EffectEvent(
      at: Duration(seconds: 29),
      duration: Duration(milliseconds: 900),
      type: EffectEventTypes.magicFlash,
      parameters: {
        'color': '#FFB000',
        'target': 'all',
        'brightness': 0.8,
      },
    ),
  ],
);

/// A playful ghost: cold blue-white light, sudden blackouts and a presence
/// that drifts around the room.
const mischievousGhost = LightingEffect(
  id: 'mischievous_ghost',
  name: 'Mischievous Ghost',
  kind: EffectKind.story,
  collection: 'Haunted',
  description: 'It only wants to play. Mostly.',
  loopDuration: Duration(seconds: 32),
  events: [
    EffectEvent(
      at: Duration.zero,
      duration: Duration(seconds: 32),
      type: EffectEventTypes.ambientPalette,
      parameters: {
        'palette': <String>['#1B2A4A', '#2E4C7A', '#4B3B6E'],
        'brightnessMin': 0.15,
        'brightnessMax': 0.40,
        'speed': 0.03,
        'flicker': 0.6,
      },
    ),
    EffectEvent(
      at: Duration(seconds: 6),
      duration: Duration(seconds: 10),
      type: EffectEventTypes.travel,
      parameters: {
        'color': '#CFE8FF',
        'pattern': 'random_walk',
        'stepDuration': 1400,
        'brightness': 0.7,
      },
    ),
    EffectEvent(
      at: Duration(seconds: 17),
      duration: Duration(milliseconds: 2500),
      type: EffectEventTypes.dim,
      parameters: {'level': 0.0},
    ),
    EffectEvent(
      at: Duration(milliseconds: 19500),
      duration: Duration(milliseconds: 500),
      type: EffectEventTypes.magicFlash,
      parameters: {
        'color': '#F2F7FF',
        'target': 'random_lights',
        'count': 2,
      },
    ),
    EffectEvent(
      at: Duration(seconds: 24),
      duration: Duration(seconds: 6),
      type: EffectEventTypes.travel,
      parameters: {
        'color': '#9FB8FF',
        'pattern': 'ping_pong',
        'passes': 3,
        'brightness': 0.6,
      },
    ),
  ],
);

/// Candlelight in an old house on a stormy night. Something walks the
/// corridor; the candles go out; lightning shows who is standing there.
const hauntedManor = LightingEffect(
  id: 'haunted_manor',
  name: 'Haunted Manor',
  kind: EffectKind.story,
  collection: 'Haunted',
  description: 'A storm outside, candles inside, and footsteps upstairs.',
  prefersStreaming: true,
  loopDuration: Duration(seconds: 48),
  events: [
    EffectEvent(
      at: Duration.zero,
      duration: Duration(seconds: 20),
      type: EffectEventTypes.ambientPalette,
      parameters: {
        'palette': <String>['#FF8A2A', '#E06A10', '#FFB060'],
        'brightnessMin': 0.15,
        'brightnessMax': 0.45,
        'speed': 0.1,
        'flicker': 1.0,
      },
    ),
    EffectEvent(
      at: Duration(seconds: 5),
      duration: Duration(milliseconds: 900),
      type: EffectEventTypes.lightning,
      parameters: {'strikes': 2, 'target': 'random_light', 'chance': 0.7},
    ),
    EffectEvent(
      at: Duration(seconds: 10),
      duration: Duration(seconds: 8),
      type: EffectEventTypes.travel,
      parameters: {
        'color': '#3A4A7A',
        'pattern': 'sweep',
        'width': 1.4,
        'brightness': 0.05,
      },
    ),
    EffectEvent(
      at: Duration(seconds: 20),
      duration: Duration(seconds: 28),
      type: EffectEventTypes.ambientPalette,
      parameters: {
        'palette': <String>['#120A1E', '#1B1030'],
        'brightnessMin': 0.02,
        'brightnessMax': 0.08,
        'speed': 0.02,
      },
    ),
    EffectEvent(
      at: Duration(seconds: 24),
      duration: Duration(milliseconds: 1500),
      type: EffectEventTypes.lightning,
      parameters: {'strikes': 5, 'target': 'all'},
    ),
    EffectEvent(
      at: Duration(seconds: 25),
      duration: Duration(milliseconds: 600),
      type: EffectEventTypes.magicFlash,
      parameters: {
        'color': '#B8FFE0',
        'target': 'random_light',
        'brightness': 0.7,
      },
    ),
    EffectEvent(
      at: Duration(seconds: 32),
      duration: Duration(seconds: 12),
      type: EffectEventTypes.travel,
      parameters: {
        'color': '#9FFFD6',
        'pattern': 'random_walk',
        'stepDuration': 1600,
        'brightness': 0.35,
      },
    ),
    EffectEvent(
      at: Duration(seconds: 44),
      duration: Duration(seconds: 4),
      type: EffectEventTypes.magicFlash,
      parameters: {'color': '#FF9A3A', 'target': 'all', 'brightness': 0.45},
    ),
  ],
);

/// A fairy flits around the room leaving pastel sparkles, then casts a
/// spell that turns every lamp pink.
const enchantedFairy = LightingEffect(
  id: 'enchanted_fairy',
  name: 'Enchanted Fairy',
  kind: EffectKind.story,
  collection: 'Magic & Fantasy',
  description: 'Tiny wings, a trail of sparkles and one big spell.',
  loopDuration: Duration(seconds: 36),
  events: [
    EffectEvent(
      at: Duration.zero,
      duration: Duration(seconds: 24),
      type: EffectEventTypes.ambientPalette,
      parameters: {
        'palette': <String>['#3B2A5C', '#5A3D7A', '#2E4A5C'],
        'brightnessMin': 0.15,
        'brightnessMax': 0.40,
        'speed': 0.05,
      },
    ),
    EffectEvent(
      at: Duration(seconds: 3),
      duration: Duration(seconds: 9),
      type: EffectEventTypes.travel,
      parameters: {
        'color': '#FFD6F5',
        'pattern': 'random_walk',
        'stepDuration': 380,
        'brightness': 0.85,
      },
    ),
    EffectEvent(
      at: Duration(seconds: 12),
      duration: Duration(seconds: 5),
      type: EffectEventTypes.surprise,
      parameters: {'color': '#D9FFF5', 'count': 7, 'brightness': 0.8},
    ),
    EffectEvent(
      at: Duration(seconds: 18),
      duration: Duration(seconds: 5),
      type: EffectEventTypes.travel,
      parameters: {
        'color': '#FFF2B3',
        'pattern': 'ping_pong',
        'passes': 4,
        'brightness': 0.9,
      },
    ),
    EffectEvent(
      at: Duration(seconds: 23),
      duration: Duration(milliseconds: 1600),
      type: EffectEventTypes.magicFlash,
      parameters: {'color': '#FF9BE0', 'target': 'all'},
    ),
    EffectEvent(
      at: Duration(seconds: 24),
      duration: Duration(seconds: 12),
      type: EffectEventTypes.ambientPalette,
      parameters: {
        'palette': <String>['#FF8AD8', '#C69BFF', '#FFC2E8', '#9BE7FF'],
        'brightnessMin': 0.45,
        'brightnessMax': 0.85,
        'speed': 0.07,
      },
    ),
  ],
);

/// Deep in a mine a goblin runs with its lantern, strikes sparks off the
/// rock, finds gems, and blows the lantern out.
const goblinMine = LightingEffect(
  id: 'goblin_mine',
  name: 'Goblin Mine',
  kind: EffectKind.story,
  collection: 'Magic & Fantasy',
  description: 'Pickaxes, lantern light and something that glitters.',
  prefersStreaming: true,
  loopDuration: Duration(seconds: 40),
  events: [
    EffectEvent(
      at: Duration.zero,
      duration: Duration(seconds: 40),
      type: EffectEventTypes.ambientPalette,
      parameters: {
        'palette': <String>['#3A2410', '#5A3816', '#24180E'],
        'brightnessMin': 0.08,
        'brightnessMax': 0.30,
        'speed': 0.08,
        'flicker': 0.9,
      },
    ),
    EffectEvent(
      at: Duration(seconds: 3),
      duration: Duration(seconds: 7),
      type: EffectEventTypes.footsteps,
      parameters: {
        'color': '#FFA040',
        'pattern': 'random_walk',
        'steps': 14,
        'interval': 480,
        'brightness': 0.6,
      },
    ),
    EffectEvent(
      at: Duration(seconds: 12),
      duration: Duration(milliseconds: 1500),
      type: EffectEventTypes.lightning,
      parameters: {'color': '#FFC46B', 'strikes': 4, 'target': 'random_light'},
    ),
    EffectEvent(
      at: Duration(seconds: 15),
      duration: Duration(milliseconds: 1200),
      type: EffectEventTypes.lightning,
      parameters: {
        'color': '#FFC46B',
        'strikes': 3,
        'target': 'random_light',
        'chance': 0.7,
      },
    ),
    EffectEvent(
      at: Duration(seconds: 19),
      duration: Duration(seconds: 2),
      type: EffectEventTypes.magicFlash,
      parameters: {'color': '#5CFF8A', 'target': 'random_light'},
    ),
    EffectEvent(
      at: Duration(seconds: 21),
      duration: Duration(seconds: 2),
      type: EffectEventTypes.magicFlash,
      parameters: {'color': '#B45CFF', 'target': 'random_light'},
    ),
    EffectEvent(
      at: Duration(seconds: 28),
      duration: Duration(seconds: 5),
      type: EffectEventTypes.dim,
      parameters: {'level': 0.0},
    ),
    EffectEvent(
      at: Duration(seconds: 30),
      duration: Duration(milliseconds: 1500),
      type: EffectEventTypes.magicFlash,
      parameters: {
        'color': '#9CFF3A',
        'target': 'random_lights',
        'count': 2,
        'brightness': 0.25,
      },
    ),
  ],
);

/// The night before Christmas: elves dash about, the tree lights twinkle
/// and a sleigh crosses the room.
const christmasElves = LightingEffect(
  id: 'christmas_elves',
  name: 'Christmas Elves',
  kind: EffectKind.story,
  collection: 'Christmas Stories',
  description: 'Busy little helpers, twinkling lights and a sleigh overhead.',
  loopDuration: Duration(seconds: 42),
  events: [
    EffectEvent(
      at: Duration.zero,
      duration: Duration(seconds: 42),
      type: EffectEventTypes.ambientPalette,
      parameters: {
        'palette': <String>['#B3121F', '#0F6B2F', '#E0A030', '#7A0F18'],
        'brightnessMin': 0.25,
        'brightnessMax': 0.55,
        'speed': 0.05,
      },
    ),
    EffectEvent(
      at: Duration(seconds: 4),
      duration: Duration(seconds: 8),
      type: EffectEventTypes.travel,
      parameters: {
        'color': '#FFE7A0',
        'pattern': 'random_walk',
        'stepDuration': 420,
      },
    ),
    EffectEvent(
      at: Duration(seconds: 13),
      duration: Duration(seconds: 4),
      type: EffectEventTypes.surprise,
      parameters: {'color': '#FFD54A', 'count': 5},
    ),
    EffectEvent(
      at: Duration(seconds: 18),
      duration: Duration(seconds: 8),
      type: EffectEventTypes.beat,
      parameters: {
        'bpm': 90,
        'palette': <String>['#FF2A2A', '#2AFF6A', '#FFD54A'],
        'pattern': 'alternate',
        'decay': 0.9,
        'brightnessMin': 0.25,
        'brightness': 0.8,
      },
    ),
    EffectEvent(
      at: Duration(seconds: 28),
      duration: Duration(seconds: 3),
      type: EffectEventTypes.travel,
      parameters: {
        'color': '#FFF6DE',
        'pattern': 'sweep',
        'width': 1.5,
        'brightness': 1.0,
      },
    ),
    EffectEvent(
      at: Duration(seconds: 32),
      duration: Duration(seconds: 3),
      type: EffectEventTypes.magicFlash,
      parameters: {'color': '#FFFFFF', 'target': 'all', 'brightness': 0.7},
    ),
  ],
);

const builtinStories = <LightingEffect>[
  emeraldTrickster,
  enchantedFairy,
  goblinMine,
  sleepingDragon,
  mischievousGhost,
  hauntedManor,
  christmasElves,
];
