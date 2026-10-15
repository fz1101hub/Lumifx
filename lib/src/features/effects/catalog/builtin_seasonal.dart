import '../../../core/effects/effect.dart';
import '../../../core/effects/effect_event.dart';

// Seasonal stories: Halloween and Christmas. Same vocabulary as the other
// stories (ambient palettes with overlays); nothing here needs streaming
// except where a story leans on lightning.

/// Lanterns glowing in a misty field. The mist rolls through, eyes blink
/// open in the dark, and one pumpkin grins with all its light.
const pumpkinPatch = LightingEffect(
  id: 'pumpkin_patch',
  name: 'Pumpkin Patch',
  kind: EffectKind.story,
  collection: 'Halloween',
  description: 'Orange lanterns in a misty field. One of them grins back.',
  loopDuration: Duration(seconds: 44),
  events: [
    EffectEvent(
      at: Duration.zero,
      duration: Duration(seconds: 44),
      type: EffectEventTypes.ambientPalette,
      parameters: {
        'palette': <String>['#FF6A00', '#C2440A', '#FF9A2E', '#7A2E0A'],
        'brightnessMin': 0.18,
        'brightnessMax': 0.50,
        'speed': 0.05,
        'flicker': 0.8,
      },
    ),
    EffectEvent(
      at: Duration(seconds: 6),
      duration: Duration(seconds: 9),
      type: EffectEventTypes.travel,
      parameters: {
        'color': '#8FA3B8',
        'pattern': 'sweep',
        'width': 2.0,
        'brightness': 0.30,
      },
    ),
    EffectEvent(
      at: Duration(seconds: 17),
      duration: Duration(seconds: 6),
      type: EffectEventTypes.surprise,
      parameters: {'color': '#FFE14A', 'count': 4, 'brightness': 0.9},
    ),
    EffectEvent(
      at: Duration(seconds: 25),
      duration: Duration(seconds: 7),
      type: EffectEventTypes.footsteps,
      parameters: {
        'color': '#FFB15C',
        'pattern': 'random_walk',
        'steps': 7,
        'interval': 900,
        'thump': 400,
        'brightness': 0.55,
      },
    ),
    EffectEvent(
      at: Duration(seconds: 33),
      duration: Duration(seconds: 3),
      type: EffectEventTypes.dim,
      parameters: {'level': 0.05},
    ),
    EffectEvent(
      at: Duration(seconds: 36),
      duration: Duration(seconds: 3),
      type: EffectEventTypes.magicFlash,
      parameters: {'color': '#FF7A00', 'target': 'all', 'brightness': 1.0},
    ),
  ],
);

/// Green bubbles, purple smoke, a spell that crackles and goes wrong, and
/// the whole room turns the colour of the potion.
const witchesCauldron = LightingEffect(
  id: 'witches_cauldron',
  name: "Witch's Cauldron",
  kind: EffectKind.story,
  collection: 'Halloween',
  description: 'Green bubbles, purple smoke and a spell that goes wrong.',
  loopDuration: Duration(seconds: 42),
  events: [
    EffectEvent(
      at: Duration.zero,
      duration: Duration(seconds: 30),
      type: EffectEventTypes.ambientPalette,
      parameters: {
        'palette': <String>['#0F4A1A', '#2E7D32', '#3B1A5C', '#145C2A'],
        'brightnessMin': 0.15,
        'brightnessMax': 0.45,
        'speed': 0.07,
        'flicker': 0.5,
      },
    ),
    EffectEvent(
      at: Duration(seconds: 3),
      duration: Duration(seconds: 8),
      type: EffectEventTypes.surprise,
      parameters: {'color': '#7CFF5A', 'count': 8, 'brightness': 0.8},
    ),
    EffectEvent(
      at: Duration(seconds: 12),
      duration: Duration(seconds: 8),
      type: EffectEventTypes.travel,
      parameters: {
        'color': '#B55CFF',
        'pattern': 'random_walk',
        'stepDuration': 1100,
        'brightness': 0.6,
      },
    ),
    EffectEvent(
      at: Duration(seconds: 21),
      duration: Duration(milliseconds: 1400),
      type: EffectEventTypes.lightning,
      parameters: {'color': '#9CFF4A', 'strikes': 4, 'target': 'random_light'},
    ),
    EffectEvent(
      at: Duration(seconds: 24),
      duration: Duration(seconds: 3),
      type: EffectEventTypes.dim,
      parameters: {'level': 0.0},
    ),
    EffectEvent(
      at: Duration(seconds: 27),
      duration: Duration(seconds: 2),
      type: EffectEventTypes.magicFlash,
      parameters: {'color': '#C84BFF', 'target': 'all', 'brightness': 1.0},
    ),
    EffectEvent(
      at: Duration(seconds: 30),
      duration: Duration(seconds: 12),
      type: EffectEventTypes.ambientPalette,
      parameters: {
        'palette': <String>['#5CFF3A', '#B44BFF', '#2EFF9A', '#8A2BE2'],
        'brightnessMin': 0.40,
        'brightnessMax': 0.85,
        'speed': 0.10,
      },
    ),
  ],
);

/// Candles in a great hall. Someone comes up the stairs; moonlight sweeps
/// the room; lightning shows the cloak; a crimson flash, then candles again.
const vampiresCastle = LightingEffect(
  id: 'vampires_castle',
  name: "Vampire's Castle",
  kind: EffectKind.story,
  collection: 'Halloween',
  description: 'Candles, footsteps on the stairs and a cloak across the hall.',
  prefersStreaming: true,
  loopDuration: Duration(seconds: 46),
  events: [
    EffectEvent(
      at: Duration.zero,
      duration: Duration(seconds: 46),
      type: EffectEventTypes.ambientPalette,
      parameters: {
        'palette': <String>['#4A0A0A', '#8C1A1A', '#2A0606', '#B8321E'],
        'brightnessMin': 0.10,
        'brightnessMax': 0.38,
        'speed': 0.06,
        'flicker': 0.9,
      },
    ),
    EffectEvent(
      at: Duration(seconds: 5),
      duration: Duration(seconds: 9),
      type: EffectEventTypes.footsteps,
      parameters: {
        'color': '#FF3A3A',
        'pattern': 'approach',
        'steps': 7,
        'interval': 1200,
        'thump': 380,
        'brightness': 0.5,
        'crescendo': 0.8,
        'shake': 0.3,
      },
    ),
    EffectEvent(
      at: Duration(seconds: 16),
      duration: Duration(seconds: 6),
      type: EffectEventTypes.travel,
      parameters: {
        'color': '#CFD8FF',
        'pattern': 'sweep',
        'width': 1.3,
        'brightness': 0.55,
      },
    ),
    EffectEvent(
      at: Duration(seconds: 24),
      duration: Duration(milliseconds: 1200),
      type: EffectEventTypes.lightning,
      parameters: {'strikes': 3, 'target': 'all'},
    ),
    EffectEvent(
      at: Duration(seconds: 26),
      duration: Duration(seconds: 3),
      type: EffectEventTypes.dim,
      parameters: {'level': 0.0},
    ),
    EffectEvent(
      at: Duration(seconds: 29),
      duration: Duration(milliseconds: 1800),
      type: EffectEventTypes.magicFlash,
      parameters: {'color': '#FF1E2E', 'target': 'all', 'brightness': 1.0},
    ),
    EffectEvent(
      at: Duration(seconds: 36),
      duration: Duration(seconds: 6),
      type: EffectEventTypes.travel,
      parameters: {
        'color': '#FF5A5A',
        'pattern': 'ping_pong',
        'passes': 3,
        'brightness': 0.5,
      },
    ),
  ],
);

/// A friendly Halloween: three knocks, the door opens in a flood of warm
/// light, kids in candy colours run down the street, and the door closes.
const trickOrTreat = LightingEffect(
  id: 'trick_or_treat',
  name: 'Trick or Treat',
  kind: EffectKind.story,
  collection: 'Halloween',
  description: 'Knock knock. Sweets, a giggle and a run down the street.',
  loopDuration: Duration(seconds: 40),
  events: [
    EffectEvent(
      at: Duration.zero,
      duration: Duration(seconds: 40),
      type: EffectEventTypes.ambientPalette,
      parameters: {
        'palette': <String>['#5A2A8A', '#FF8C1A', '#3A1A6A', '#D9611A'],
        'brightnessMin': 0.22,
        'brightnessMax': 0.50,
        'speed': 0.05,
      },
    ),
    EffectEvent(
      at: Duration(seconds: 4),
      duration: Duration(seconds: 3),
      type: EffectEventTypes.footsteps,
      parameters: {
        'color': '#FFE0B0',
        'pattern': 'random_walk',
        'steps': 3,
        'interval': 650,
        'thump': 200,
        'brightness': 0.9,
      },
    ),
    EffectEvent(
      at: Duration(seconds: 8),
      duration: Duration(seconds: 3),
      type: EffectEventTypes.magicFlash,
      parameters: {'color': '#FFD38A', 'target': 'all', 'brightness': 0.95},
    ),
    EffectEvent(
      at: Duration(seconds: 12),
      duration: Duration(seconds: 5),
      type: EffectEventTypes.surprise,
      parameters: {'color': '#FF4FD8', 'count': 6, 'brightness': 0.9},
    ),
    EffectEvent(
      at: Duration(seconds: 18),
      duration: Duration(seconds: 8),
      type: EffectEventTypes.beat,
      parameters: {
        'bpm': 112,
        'palette': <String>['#FF4FD8', '#4FFFB0', '#FFD84F', '#4FB8FF'],
        'pattern': 'alternate',
        'decay': 0.6,
        'brightnessMin': 0.25,
        'brightness': 0.9,
      },
    ),
    EffectEvent(
      at: Duration(seconds: 27),
      duration: Duration(seconds: 6),
      type: EffectEventTypes.travel,
      parameters: {
        'color': '#FFF1C2',
        'pattern': 'ping_pong',
        'passes': 3,
        'brightness': 0.8,
      },
    ),
    EffectEvent(
      at: Duration(seconds: 34),
      duration: Duration(seconds: 4),
      type: EffectEventTypes.dim,
      parameters: {'level': 0.15},
    ),
  ],
);

/// Warm wood and tinsel, elves hammering here and there, gold sparks, a
/// quick tune, and the sack lighting up.
const santasWorkshop = LightingEffect(
  id: 'santas_workshop',
  name: "Santa's Workshop",
  kind: EffectKind.story,
  collection: 'Christmas Stories',
  description: 'Hammers, tinsel and a sack that fills up with light.',
  loopDuration: Duration(seconds: 44),
  events: [
    EffectEvent(
      at: Duration.zero,
      duration: Duration(seconds: 36),
      type: EffectEventTypes.ambientPalette,
      parameters: {
        'palette': <String>['#8A4A1A', '#C21E2A', '#E0A030', '#1E6B2E'],
        'brightnessMin': 0.25,
        'brightnessMax': 0.55,
        'speed': 0.05,
        'flicker': 0.3,
      },
    ),
    EffectEvent(
      at: Duration(seconds: 3),
      duration: Duration(seconds: 8),
      type: EffectEventTypes.footsteps,
      parameters: {
        'color': '#FFE08A',
        'pattern': 'random_walk',
        'steps': 20,
        'interval': 380,
        'thump': 150,
        'brightness': 0.85,
      },
    ),
    EffectEvent(
      at: Duration(seconds: 12),
      duration: Duration(seconds: 5),
      type: EffectEventTypes.surprise,
      parameters: {'color': '#FFD54A', 'count': 7, 'brightness': 0.9},
    ),
    EffectEvent(
      at: Duration(seconds: 18),
      duration: Duration(seconds: 10),
      type: EffectEventTypes.beat,
      parameters: {
        'bpm': 100,
        'palette': <String>['#FF2A2A', '#2AFF6A', '#FFD54A', '#FFFFFF'],
        'pattern': 'chase',
        'decay': 0.7,
        'brightnessMin': 0.25,
        'brightness': 0.9,
      },
    ),
    EffectEvent(
      at: Duration(seconds: 30),
      duration: Duration(seconds: 4),
      type: EffectEventTypes.travel,
      parameters: {
        'color': '#FFF4C2',
        'pattern': 'sweep',
        'width': 1.8,
        'brightness': 1.0,
      },
    ),
    EffectEvent(
      at: Duration(seconds: 36),
      duration: Duration(seconds: 8),
      type: EffectEventTypes.ambientPalette,
      parameters: {
        'palette': <String>['#FFD54A', '#FF2A2A', '#FFF1B8', '#2AFF6A'],
        'brightnessMin': 0.50,
        'brightnessMax': 0.95,
        'speed': 0.08,
      },
    ),
  ],
);

/// A calm one: a deep blue night, flakes drifting from lamp to lamp, a
/// faint sparkle, and a warm window somewhere in the dark.
const silentSnowfall = LightingEffect(
  id: 'silent_snowfall',
  name: 'Silent Snowfall',
  kind: EffectKind.story,
  collection: 'Christmas Stories',
  description: 'Soft flakes drifting down, and the night sky behind them.',
  loopDuration: Duration(seconds: 50),
  events: [
    EffectEvent(
      at: Duration.zero,
      duration: Duration(seconds: 50),
      type: EffectEventTypes.ambientPalette,
      parameters: {
        'palette': <String>['#0B1E4A', '#1E3A7A', '#C9DBFF', '#122A5C'],
        'brightnessMin': 0.12,
        'brightnessMax': 0.35,
        'speed': 0.025,
      },
    ),
    EffectEvent(
      at: Duration(seconds: 2),
      duration: Duration(seconds: 20),
      type: EffectEventTypes.travel,
      parameters: {
        'color': '#F4F8FF',
        'pattern': 'random_walk',
        'stepDuration': 1600,
        'brightness': 0.5,
      },
    ),
    EffectEvent(
      at: Duration(seconds: 10),
      duration: Duration(seconds: 14),
      type: EffectEventTypes.surprise,
      parameters: {'color': '#FFFFFF', 'count': 10, 'brightness': 0.45},
    ),
    EffectEvent(
      at: Duration(seconds: 26),
      duration: Duration(seconds: 16),
      type: EffectEventTypes.travel,
      parameters: {
        'color': '#E8F0FF',
        'pattern': 'random_walk',
        'stepDuration': 2000,
        'brightness': 0.4,
      },
    ),
    EffectEvent(
      at: Duration(seconds: 40),
      duration: Duration(seconds: 6),
      type: EffectEventTypes.magicFlash,
      parameters: {
        'color': '#FFC46B',
        'target': 'random_light',
        'brightness': 0.5,
      },
    ),
  ],
);

/// One candle is lit and passed along the room, the glow grows, and the
/// carol swells in gold and red until the whole room sings.
const candlelightCarol = LightingEffect(
  id: 'candlelight_carol',
  name: 'Candlelight Carol',
  kind: EffectKind.story,
  collection: 'Christmas Stories',
  description: 'One candle lights the next until the whole room sings.',
  loopDuration: Duration(seconds: 48),
  events: [
    EffectEvent(
      at: Duration.zero,
      duration: Duration(seconds: 14),
      type: EffectEventTypes.ambientPalette,
      parameters: {
        'palette': <String>['#1A0E06', '#2A1608'],
        'brightnessMin': 0.02,
        'brightnessMax': 0.08,
        'speed': 0.03,
      },
    ),
    EffectEvent(
      at: Duration(seconds: 2),
      duration: Duration(seconds: 12),
      type: EffectEventTypes.travel,
      parameters: {
        'color': '#FFC46B',
        'pattern': 'sweep',
        'width': 1.2,
        'brightness': 0.75,
      },
    ),
    EffectEvent(
      at: Duration(seconds: 14),
      duration: Duration(seconds: 12),
      type: EffectEventTypes.ambientPalette,
      parameters: {
        'palette': <String>['#FF9A3A', '#FFC46B', '#E06A10'],
        'brightnessMin': 0.25,
        'brightnessMax': 0.55,
        'speed': 0.05,
        'flicker': 1.0,
      },
    ),
    EffectEvent(
      at: Duration(seconds: 26),
      duration: Duration(seconds: 14),
      type: EffectEventTypes.beat,
      parameters: {
        'bpm': 72,
        'palette': <String>['#FFD54A', '#FF3A3A', '#FFF1B8', '#2AFF6A'],
        'pattern': 'alternate',
        'decay': 0.9,
        'brightnessMin': 0.35,
        'brightness': 0.9,
      },
    ),
    EffectEvent(
      at: Duration(seconds: 40),
      duration: Duration(seconds: 8),
      type: EffectEventTypes.ambientPalette,
      parameters: {
        'palette': <String>['#FFD54A', '#FF6A3A', '#FFF1B8', '#FF3A3A'],
        'brightnessMin': 0.55,
        'brightnessMax': 0.95,
        'speed': 0.07,
      },
    ),
    EffectEvent(
      at: Duration(seconds: 44),
      duration: Duration(seconds: 3),
      type: EffectEventTypes.magicFlash,
      parameters: {'color': '#FFFFFF', 'target': 'all', 'brightness': 0.6},
    ),
  ],
);

final builtinSeasonal = <LightingEffect>[
  pumpkinPatch,
  witchesCauldron,
  vampiresCastle,
  trickOrTreat,
  santasWorkshop,
  silentSnowfall,
  candlelightCarol,
];
