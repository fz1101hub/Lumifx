import '../../../core/effects/effect.dart';
import '../../../core/effects/effect_event.dart';

// Holiday stories: New Year, Valentine's Day, Carnival, Easter, Diwali,
// Hanukkah and Lunar New Year. No lightning or beats, so they suit
// children and need no warning.

/// The night sky before midnight, a countdown of golden ticks, a burst of
/// light on the stroke of the year, then fireworks in every colour.
final newYearCountdown = LightingEffect(
  id: 'new_year_countdown',
  name: "New Year's Countdown",
  kind: EffectKind.story,
  collection: 'New Year',
  description: 'Ten golden ticks to midnight, then fireworks.',
  loopDuration: const Duration(seconds: 44),
  events: [
    const EffectEvent(
      at: Duration.zero,
      duration: Duration(seconds: 20),
      type: EffectEventTypes.ambientPalette,
      parameters: {
        'palette': <String>['#0B1033', '#1C1A5E', '#3A2F7A', '#C9D1FF'],
        'brightnessMin': 0.10,
        'brightnessMax': 0.35,
        'speed': 0.03,
      },
    ),
    // Ten… nine… eight…: one tick a second, a little brighter each time.
    for (var tick = 0; tick < 10; tick++)
      EffectEvent(
        at: Duration(seconds: 9 + tick),
        duration: const Duration(milliseconds: 600),
        type: EffectEventTypes.magicFlash,
        parameters: {
          'color': '#FFD36B',
          'target': 'random_light',
          'brightness': 0.45 + tick * 0.05,
        },
      ),
    const EffectEvent(
      at: Duration(seconds: 20),
      duration: Duration(milliseconds: 1600),
      type: EffectEventTypes.magicFlash,
      parameters: {'color': '#FFF4D6', 'target': 'all', 'brightness': 1.0},
    ),
    const EffectEvent(
      at: Duration(seconds: 21),
      duration: Duration(seconds: 23),
      type: EffectEventTypes.ambientPalette,
      parameters: {
        'palette': <String>['#2A1B5C', '#FFB23F', '#3A2F7A', '#FFD36B'],
        'brightnessMin': 0.30,
        'brightnessMax': 0.70,
        'speed': 0.06,
      },
    ),
    for (final (at, color) in const [
      (22, '#FF3B5C'),
      (25, '#3BD1FF'),
      (28, '#7CFF6B'),
      (31, '#FFD36B'),
      (34, '#C86BFF'),
    ])
      EffectEvent(
        at: Duration(seconds: at),
        duration: const Duration(seconds: 3),
        type: EffectEventTypes.surprise,
        parameters: {'color': color, 'count': 4, 'brightness': 0.95},
      ),
  ],
);

/// A rosy glow, a little heart floating from lamp to lamp leaving
/// sparkles, then the whole room blushes.
const valentinesGlow = LightingEffect(
  id: 'valentines_glow',
  name: "Valentine's Glow",
  kind: EffectKind.story,
  collection: 'Valentine',
  description:
      'A little heart floats from lamp to lamp. Then the room blushes.',
  loopDuration: Duration(seconds: 40),
  events: [
    EffectEvent(
      at: Duration.zero,
      duration: Duration(seconds: 40),
      type: EffectEventTypes.ambientPalette,
      parameters: {
        'palette': <String>['#FF4F7B', '#FF8FAB', '#C2185B', '#FFC2D1'],
        'brightnessMin': 0.25,
        'brightnessMax': 0.60,
        'speed': 0.04,
      },
    ),
    EffectEvent(
      at: Duration(seconds: 6),
      duration: Duration(seconds: 8),
      type: EffectEventTypes.travel,
      parameters: {
        'color': '#FF1744',
        'pattern': 'random_walk',
        'stepDuration': 1100,
        'brightness': 1.0,
      },
    ),
    EffectEvent(
      at: Duration(seconds: 15),
      duration: Duration(seconds: 6),
      type: EffectEventTypes.surprise,
      parameters: {'color': '#FFE0EA', 'count': 5, 'brightness': 0.8},
    ),
    EffectEvent(
      at: Duration(seconds: 24),
      duration: Duration(seconds: 2),
      type: EffectEventTypes.magicFlash,
      parameters: {'color': '#FF2D55', 'target': 'all', 'brightness': 0.9},
    ),
  ],
);

/// Music and masks: a marching parade, streamers flying back and forth,
/// confetti in every colour, and a grand finale.
const carnivalParade = LightingEffect(
  id: 'carnival_parade',
  name: 'Carnival Parade',
  kind: EffectKind.story,
  collection: 'Carnival',
  description: 'Masks, a marching parade and confetti in every colour.',
  loopDuration: Duration(seconds: 40),
  events: [
    EffectEvent(
      at: Duration.zero,
      duration: Duration(seconds: 40),
      type: EffectEventTypes.ambientPalette,
      parameters: {
        'palette': <String>['#FF3D7F', '#FFC400', '#00C2FF', '#7C4DFF'],
        'brightnessMin': 0.35,
        'brightnessMax': 0.75,
        'speed': 0.10,
      },
    ),
    EffectEvent(
      at: Duration(seconds: 4),
      duration: Duration(seconds: 7),
      type: EffectEventTypes.footsteps,
      parameters: {
        'color': '#FFF176',
        'pattern': 'approach',
        'steps': 10,
        'interval': 600,
        'brightness': 0.9,
      },
    ),
    EffectEvent(
      at: Duration(seconds: 12),
      duration: Duration(seconds: 5),
      type: EffectEventTypes.travel,
      parameters: {
        'color': '#FF4081',
        'pattern': 'ping_pong',
        'passes': 3,
        'width': 1.4,
        'brightness': 1.0,
      },
    ),
    EffectEvent(
      at: Duration(seconds: 18),
      duration: Duration(seconds: 3),
      type: EffectEventTypes.surprise,
      parameters: {'color': '#69F0AE', 'count': 4},
    ),
    EffectEvent(
      at: Duration(seconds: 21),
      duration: Duration(seconds: 3),
      type: EffectEventTypes.surprise,
      parameters: {'color': '#FFD740', 'count': 4},
    ),
    EffectEvent(
      at: Duration(seconds: 24),
      duration: Duration(seconds: 3),
      type: EffectEventTypes.surprise,
      parameters: {'color': '#40C4FF', 'count': 4},
    ),
    EffectEvent(
      at: Duration(seconds: 32),
      duration: Duration(seconds: 2),
      type: EffectEventTypes.magicFlash,
      parameters: {'color': '#FFFFFF', 'target': 'all', 'brightness': 0.9},
    ),
  ],
);

/// Spring sunshine over a garden, a bunny hopping between the bushes,
/// painted eggs glinting here and there, and a golden "found them all".
const easterEggHunt = LightingEffect(
  id: 'easter_egg_hunt',
  name: 'Easter Egg Hunt',
  kind: EffectKind.story,
  collection: 'Easter',
  description: 'A bunny hops through the garden. Can you spot the eggs?',
  loopDuration: Duration(seconds: 44),
  events: [
    EffectEvent(
      at: Duration.zero,
      duration: Duration(seconds: 44),
      type: EffectEventTypes.ambientPalette,
      parameters: {
        'palette': <String>['#9BE564', '#FFF59D', '#B3E5FC', '#C5E1A5'],
        'brightnessMin': 0.35,
        'brightnessMax': 0.70,
        'speed': 0.04,
      },
    ),
    EffectEvent(
      at: Duration(seconds: 5),
      duration: Duration(seconds: 8),
      type: EffectEventTypes.travel,
      parameters: {
        'color': '#FFFFFF',
        'pattern': 'random_walk',
        'stepDuration': 600,
        'brightness': 0.9,
      },
    ),
    EffectEvent(
      at: Duration(seconds: 14),
      duration: Duration(milliseconds: 1500),
      type: EffectEventTypes.magicFlash,
      parameters: {'color': '#FF80AB', 'target': 'random_light'},
    ),
    EffectEvent(
      at: Duration(seconds: 19),
      duration: Duration(milliseconds: 1500),
      type: EffectEventTypes.magicFlash,
      parameters: {'color': '#82B1FF', 'target': 'random_light'},
    ),
    EffectEvent(
      at: Duration(seconds: 26),
      duration: Duration(seconds: 5),
      type: EffectEventTypes.surprise,
      parameters: {'color': '#FFD180', 'count': 5, 'brightness': 0.85},
    ),
    EffectEvent(
      at: Duration(seconds: 34),
      duration: Duration(seconds: 2),
      type: EffectEventTypes.magicFlash,
      parameters: {'color': '#FFE57F', 'target': 'all', 'brightness': 0.95},
    ),
  ],
);

/// Diwali: dusk, little clay lamps lit one by one, the house glowing
/// warm and golden, rangoli colours blooming, then sparklers.
final festivalOfLights = LightingEffect(
  id: 'festival_of_lights',
  name: 'Festival of Lights',
  kind: EffectKind.story,
  collection: 'Diwali',
  description: 'Little lamps lit one by one, rangoli colours and sparklers.',
  loopDuration: const Duration(seconds: 44),
  events: [
    const EffectEvent(
      at: Duration.zero,
      duration: Duration(seconds: 14),
      type: EffectEventTypes.ambientPalette,
      parameters: {
        'palette': <String>['#2B0F3A', '#5A1846', '#8A2B5E', '#3A1450'],
        'brightnessMin': 0.10,
        'brightnessMax': 0.30,
        'speed': 0.03,
      },
    ),
    // The diyas, one by one.
    for (final at in [6, 8, 10, 12])
      EffectEvent(
        at: Duration(seconds: at),
        duration: Duration(seconds: 2),
        type: EffectEventTypes.magicFlash,
        parameters: {
          'color': '#FFB23F',
          'target': 'random_light',
          'brightness': 0.7,
        },
      ),
    const EffectEvent(
      at: Duration(seconds: 14),
      duration: Duration(seconds: 30),
      type: EffectEventTypes.ambientPalette,
      parameters: {
        'palette': <String>['#FF9F1C', '#FFB23F', '#FF6B1A', '#FFD36B'],
        'brightnessMin': 0.35,
        'brightnessMax': 0.70,
        'speed': 0.08,
      },
    ),
    // Rangoli colours.
    for (final (at, color) in [
      (20, '#FF3D9A'),
      (23, '#1FD1C1'),
      (26, '#C86BFF'),
    ])
      EffectEvent(
        at: Duration(seconds: at),
        duration: Duration(seconds: 3),
        type: EffectEventTypes.surprise,
        parameters: {'color': color, 'count': 3, 'brightness': 0.85},
      ),
    // Sparklers.
    const EffectEvent(
      at: Duration(seconds: 30),
      duration: Duration(seconds: 6),
      type: EffectEventTypes.surprise,
      parameters: {'color': '#FFF4D6', 'count': 6, 'brightness': 0.95},
    ),
  ],
);

/// Hanukkah: a winter night, the helper candle lighting the others one by
/// one until eight shine, the room in blue, white and gold, a spinning
/// dreidel and gleaming coins.
final eightLittleLights = LightingEffect(
  id: 'eight_little_lights',
  name: 'Eight Little Lights',
  kind: EffectKind.story,
  collection: 'Hanukkah',
  description: 'One more candle each night until eight shine, and a dreidel.',
  loopDuration: const Duration(seconds: 46),
  events: [
    const EffectEvent(
      at: Duration.zero,
      duration: Duration(seconds: 25),
      type: EffectEventTypes.ambientPalette,
      parameters: {
        'palette': <String>['#0B1A4A', '#14306E', '#1E3F8A', '#C9D8FF'],
        'brightnessMin': 0.12,
        'brightnessMax': 0.32,
        'speed': 0.03,
      },
    ),
    // The helper candle, then eight little lights, each a little brighter.
    for (var candle = 0; candle <= 8; candle++)
      EffectEvent(
        at: Duration(seconds: 6 + candle * 2),
        duration: const Duration(milliseconds: 2500),
        type: EffectEventTypes.magicFlash,
        parameters: {
          'color': candle == 0 ? '#FFFFFF' : '#FFC86B',
          'target': 'random_light',
          'brightness': 0.5 + candle * 0.05,
        },
      ),
    const EffectEvent(
      at: Duration(seconds: 25),
      duration: Duration(seconds: 21),
      type: EffectEventTypes.ambientPalette,
      parameters: {
        'palette': <String>['#1E3F8A', '#FFFFFF', '#4F7BFF', '#FFD36B'],
        'brightnessMin': 0.35,
        'brightnessMax': 0.65,
        'speed': 0.05,
      },
    ),
    // The dreidel spins.
    const EffectEvent(
      at: Duration(seconds: 31),
      duration: Duration(seconds: 7),
      type: EffectEventTypes.travel,
      parameters: {
        'color': '#FFFFFF',
        'pattern': 'random_walk',
        'stepDuration': 800,
        'brightness': 0.9,
      },
    ),
    // Golden coins gleam.
    const EffectEvent(
      at: Duration(seconds: 39),
      duration: Duration(seconds: 4),
      type: EffectEventTypes.surprise,
      parameters: {'color': '#FFD36B', 'count': 4, 'brightness': 0.9},
    ),
  ],
);

/// Lunar New Year: red lanterns, a golden dragon dancing from lamp to
/// lamp, the gong, then fireworks in red and gold.
final lunarNewYear = LightingEffect(
  id: 'lunar_new_year',
  name: 'Lunar New Year',
  kind: EffectKind.story,
  collection: 'Lunar New Year',
  description: 'Red lanterns, a dancing dragon and fireworks in red and gold.',
  loopDuration: const Duration(seconds: 44),
  events: [
    const EffectEvent(
      at: Duration.zero,
      duration: Duration(seconds: 24),
      type: EffectEventTypes.ambientPalette,
      parameters: {
        'palette': <String>['#B3001B', '#E0102F', '#FF4D2E', '#FFB23F'],
        'brightnessMin': 0.30,
        'brightnessMax': 0.60,
        'speed': 0.04,
      },
    ),
    // The dragon dances.
    const EffectEvent(
      at: Duration(seconds: 8),
      duration: Duration(seconds: 10),
      type: EffectEventTypes.travel,
      parameters: {
        'color': '#FFD000',
        'pattern': 'random_walk',
        'stepDuration': 900,
        'brightness': 1.0,
      },
    ),
    // The gong.
    const EffectEvent(
      at: Duration(seconds: 20),
      duration: Duration(milliseconds: 1800),
      type: EffectEventTypes.magicFlash,
      parameters: {'color': '#FFD36B', 'target': 'all', 'brightness': 0.9},
    ),
    const EffectEvent(
      at: Duration(seconds: 24),
      duration: Duration(seconds: 20),
      type: EffectEventTypes.ambientPalette,
      parameters: {
        'palette': <String>['#FFD000', '#E0102F', '#FF8C1A', '#FFE680'],
        'brightnessMin': 0.40,
        'brightnessMax': 0.75,
        'speed': 0.06,
      },
    ),
    // Fireworks.
    for (final (at, color) in [
      (26, '#FF2D3A'),
      (29, '#FFD000'),
      (32, '#FF6FB5'),
      (35, '#FF8C1A'),
    ])
      EffectEvent(
        at: Duration(seconds: at),
        duration: Duration(seconds: 3),
        type: EffectEventTypes.surprise,
        parameters: {'color': color, 'count': 4, 'brightness': 0.95},
      ),
  ],
);

final builtinHolidays = <LightingEffect>[
  newYearCountdown,
  valentinesGlow,
  carnivalParade,
  easterEggHunt,
  festivalOfLights,
  eightLittleLights,
  lunarNewYear,
];
