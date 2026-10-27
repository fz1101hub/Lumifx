import '../../../core/effects/effect.dart';
import '../../../core/effects/effect_event.dart';

/// Around the world in light: short stories of places, each ending with a
/// fact read aloud.

/// The northern lights over Norway.
const auroraNorway = LightingEffect(
  id: 'world_aurora',
  name: 'Northern lights in Norway',
  kind: EffectKind.story,
  collection: 'Around the world',
  description: 'Green and purple ribbons dance across a long winter night.',
  loopDuration: Duration(seconds: 46),
  events: [
    EffectEvent(
      at: Duration.zero,
      duration: Duration(seconds: 6),
      type: EffectEventTypes.ambientPalette,
      parameters: {
        'palette': <String>['#061233', '#0B1D4D'],
        'brightnessMin': 0.08,
        'brightnessMax': 0.15,
        'speed': 0.01,
      },
    ),
    EffectEvent(
      at: Duration(seconds: 6),
      duration: Duration(seconds: 6),
      type: EffectEventTypes.travel,
      parameters: {'color': '#3DFF9A', 'brightness': 0.8},
    ),
    EffectEvent(
      at: Duration(seconds: 12),
      duration: Duration(seconds: 34),
      type: EffectEventTypes.ambientPalette,
      parameters: {
        'palette': <String>['#1BE38A', '#7A3DFF', '#18B4A0', '#B266FF'],
        'brightnessMin': 0.3,
        'brightnessMax': 0.75,
        'speed': 0.05,
      },
    ),
  ],
);

/// Cherry blossom in Japan.
const cherryBlossomJapan = LightingEffect(
  id: 'world_cherry',
  name: 'Cherry blossom in Japan',
  kind: EffectKind.story,
  collection: 'Around the world',
  description: 'Pink petals float down on a spring morning.',
  loopDuration: Duration(seconds: 40),
  events: [
    EffectEvent(
      at: Duration.zero,
      duration: Duration(seconds: 40),
      type: EffectEventTypes.ambientPalette,
      parameters: {
        'palette': <String>['#FFC1DC', '#FFE3EE', '#FF9EC8'],
        'brightnessMin': 0.4,
        'brightnessMax': 0.7,
        'speed': 0.03,
      },
    ),
    EffectEvent(
      at: Duration(seconds: 8),
      duration: Duration(seconds: 6),
      type: EffectEventTypes.surprise,
      parameters: {'color': '#FFFFFF', 'count': 6, 'brightness': 0.8},
    ),
    EffectEvent(
      at: Duration(seconds: 16),
      duration: Duration(seconds: 5),
      type: EffectEventTypes.travel,
      parameters: {'color': '#FFF0F6', 'brightness': 0.9},
    ),
  ],
);

/// The Sahara desert, from noon to the first stars.
const saharaDesert = LightingEffect(
  id: 'world_sahara',
  name: 'The Sahara desert',
  kind: EffectKind.story,
  collection: 'Around the world',
  description: 'Golden sand, a warm wind and a red sunset over the dunes.',
  loopDuration: Duration(seconds: 44),
  events: [
    EffectEvent(
      at: Duration.zero,
      duration: Duration(seconds: 20),
      type: EffectEventTypes.ambientPalette,
      parameters: {
        'palette': <String>['#FFC44D', '#FFB02E', '#FFD98A'],
        'brightnessMin': 0.6,
        'brightnessMax': 0.85,
        'speed': 0.04,
      },
    ),
    EffectEvent(
      at: Duration(seconds: 10),
      duration: Duration(seconds: 6),
      type: EffectEventTypes.travel,
      parameters: {'color': '#FF8C1A', 'brightness': 1},
    ),
    EffectEvent(
      at: Duration(seconds: 20),
      duration: Duration(seconds: 10),
      type: EffectEventTypes.ramp,
      parameters: {
        'color': '#FF8C1A',
        'toColor': '#C2185B',
        'from': 0.75,
        'to': 0.35,
      },
    ),
    EffectEvent(
      at: Duration(seconds: 30),
      duration: Duration(seconds: 14),
      type: EffectEventTypes.ambientPalette,
      parameters: {
        'palette': <String>['#0A1033', '#141B4D'],
        'brightnessMin': 0.08,
        'brightnessMax': 0.14,
        'speed': 0.01,
      },
    ),
    EffectEvent(
      at: Duration(seconds: 32),
      duration: Duration(seconds: 10),
      type: EffectEventTypes.surprise,
      parameters: {'color': '#FFFFFF', 'count': 5, 'brightness': 0.5},
    ),
  ],
);

/// The Amazon rainforest: rain, a macaw, then fireflies.
const amazonRainforest = LightingEffect(
  id: 'world_amazon',
  name: 'The Amazon rainforest',
  kind: EffectKind.story,
  collection: 'Around the world',
  description: 'Deep greens, warm rain, a red macaw and fireflies at dusk.',
  loopDuration: Duration(seconds: 42),
  events: [
    EffectEvent(
      at: Duration.zero,
      duration: Duration(seconds: 26),
      type: EffectEventTypes.ambientPalette,
      parameters: {
        'palette': <String>['#0B5D2A', '#1E8C3A', '#0F4D24', '#3DBA55'],
        'brightnessMin': 0.3,
        'brightnessMax': 0.6,
        'speed': 0.04,
      },
    ),
    EffectEvent(
      at: Duration(seconds: 8),
      duration: Duration(seconds: 6),
      type: EffectEventTypes.surprise,
      parameters: {'color': '#7FC8FF', 'count': 8, 'brightness': 0.6},
    ),
    EffectEvent(
      at: Duration(seconds: 16),
      duration: Duration(seconds: 4),
      type: EffectEventTypes.travel,
      parameters: {'color': '#FF2020', 'brightness': 1},
    ),
    EffectEvent(
      at: Duration(seconds: 26),
      duration: Duration(seconds: 16),
      type: EffectEventTypes.ambientPalette,
      parameters: {
        'palette': <String>['#062B14', '#0A3D1D'],
        'brightnessMin': 0.08,
        'brightnessMax': 0.15,
        'speed': 0.02,
      },
    ),
    EffectEvent(
      at: Duration(seconds: 27),
      duration: Duration(seconds: 14),
      type: EffectEventTypes.surprise,
      parameters: {'color': '#E8FF4D', 'count': 7, 'brightness': 0.6},
    ),
  ],
);

final builtinWorld = <LightingEffect>[
  auroraNorway,
  cherryBlossomJapan,
  saharaDesert,
  amazonRainforest,
];
