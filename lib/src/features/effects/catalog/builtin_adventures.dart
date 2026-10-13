import '../../../core/effects/effect.dart';
import '../../../core/effects/effect_event.dart';

/// A torch-lit cave, a glint that will not stay still, darkness, and gold.
const hiddenTreasure = LightingEffect(
  id: 'hidden_treasure',
  name: 'Hidden Treasure',
  kind: EffectKind.story,
  collection: 'Adventure',
  description: 'Follow the glint. The torch will not last forever.',
  loopDuration: Duration(seconds: 42),
  events: [
    EffectEvent(
      at: Duration.zero,
      duration: Duration(seconds: 30),
      type: EffectEventTypes.ambientPalette,
      parameters: {
        'palette': <String>['#4A2A10', '#6B3D14', '#3A200C'],
        'brightnessMin': 0.15,
        'brightnessMax': 0.40,
        'speed': 0.09,
        'flicker': 0.7,
      },
    ),
    EffectEvent(
      at: Duration(seconds: 4),
      duration: Duration(seconds: 9),
      type: EffectEventTypes.travel,
      parameters: {
        'color': '#FFD86B',
        'pattern': 'random_walk',
        'stepDuration': 600,
        'brightness': 0.7,
      },
    ),
    EffectEvent(
      at: Duration(seconds: 14),
      duration: Duration(seconds: 3),
      type: EffectEventTypes.surprise,
      parameters: {'color': '#FFE9A8', 'count': 4},
    ),
    EffectEvent(
      at: Duration(seconds: 19),
      duration: Duration(seconds: 4),
      type: EffectEventTypes.dim,
      parameters: {'level': 0.05},
    ),
    EffectEvent(
      at: Duration(seconds: 23),
      duration: Duration(seconds: 4),
      type: EffectEventTypes.travel,
      parameters: {'color': '#FF9A3A', 'pattern': 'sweep', 'width': 1.3},
    ),
    EffectEvent(
      at: Duration(seconds: 28),
      duration: Duration(milliseconds: 1800),
      type: EffectEventTypes.magicFlash,
      parameters: {'color': '#FFD23A', 'target': 'random_light'},
    ),
    EffectEvent(
      at: Duration(seconds: 30),
      duration: Duration(seconds: 12),
      type: EffectEventTypes.ambientPalette,
      parameters: {
        'palette': <String>['#FFB800', '#FFD86B', '#E09000', '#FFF0B8'],
        'brightnessMin': 0.50,
        'brightnessMax': 0.95,
        'speed': 0.08,
      },
    ),
  ],
);

/// A pirate ship at night: lanterns on deck, cannon fire, and something
/// enormous passing beneath.
const krakensCove = LightingEffect(
  id: 'krakens_cove',
  name: "Kraken's Cove",
  kind: EffectKind.story,
  collection: 'Pirates',
  description: 'Lanterns on deck, cannons in the dark, and something below.',
  prefersStreaming: true,
  loopDuration: Duration(seconds: 44),
  events: [
    EffectEvent(
      at: Duration.zero,
      duration: Duration(seconds: 44),
      type: EffectEventTypes.ambientPalette,
      parameters: {
        'palette': <String>['#06243A', '#0B3D4F', '#123247', '#3A2A12'],
        'brightnessMin': 0.10,
        'brightnessMax': 0.35,
        'speed': 0.04,
        'flicker': 0.3,
      },
    ),
    EffectEvent(
      at: Duration(seconds: 6),
      duration: Duration(milliseconds: 700),
      type: EffectEventTypes.lightning,
      parameters: {'color': '#FF8A2A', 'strikes': 1, 'target': 'random_light'},
    ),
    EffectEvent(
      at: Duration(seconds: 8),
      duration: Duration(milliseconds: 700),
      type: EffectEventTypes.lightning,
      parameters: {
        'color': '#FF8A2A',
        'strikes': 2,
        'target': 'random_light',
        'chance': 0.8,
      },
    ),
    EffectEvent(
      at: Duration(seconds: 16),
      duration: Duration(seconds: 9),
      type: EffectEventTypes.travel,
      parameters: {
        'color': '#2A0B3A',
        'pattern': 'sweep',
        'width': 2.0,
        'brightness': 0.02,
      },
    ),
    EffectEvent(
      at: Duration(seconds: 19),
      duration: Duration(seconds: 4),
      type: EffectEventTypes.footsteps,
      parameters: {
        'color': '#3AFFD0',
        'steps': 4,
        'interval': 1000,
        'thump': 500,
        'brightness': 0.25,
        'shake': 0.4,
      },
    ),
    EffectEvent(
      at: Duration(seconds: 30),
      duration: Duration(milliseconds: 1600),
      type: EffectEventTypes.lightning,
      parameters: {'strikes': 4, 'target': 'all'},
    ),
    EffectEvent(
      at: Duration(seconds: 33),
      duration: Duration(milliseconds: 800),
      type: EffectEventTypes.lightning,
      parameters: {
        'color': '#FF8A2A',
        'strikes': 3,
        'target': 'random_lights',
        'count': 2,
      },
    ),
  ],
);

/// Lying under the stars: meteors streak across the room, then a ship
/// jumps to light speed.
final meteorShower = LightingEffect(
  id: 'meteor_shower',
  name: 'Meteor Shower',
  kind: EffectKind.story,
  collection: 'Space Adventures',
  description: 'Make a wish on every streak, then hold on tight.',
  prefersStreaming: true,
  loopDuration: Duration(seconds: 40),
  events: [
    EffectEvent(
      at: Duration.zero,
      duration: Duration(seconds: 40),
      type: EffectEventTypes.ambientPalette,
      parameters: {
        'palette': <String>['#05051A', '#0B0B2E', '#1A0B3D'],
        'brightnessMin': 0.04,
        'brightnessMax': 0.15,
        'speed': 0.02,
      },
    ),
    EffectEvent(
      at: Duration(seconds: 2),
      duration: Duration(seconds: 6),
      type: EffectEventTypes.surprise,
      parameters: {'color': '#CFE0FF', 'count': 6, 'brightness': 0.4},
    ),
    for (final (second, chance) in [(5, 1.0), (9, 0.8), (12, 0.8), (14, 0.6)])
      EffectEvent(
        at: Duration(seconds: second),
        duration: const Duration(milliseconds: 1100),
        type: EffectEventTypes.travel,
        parameters: {
          'color': '#E8F0FF',
          'pattern': 'sweep',
          'width': 0.8,
          'brightness': 1.0,
          'chance': chance,
        },
      ),
    EffectEvent(
      at: Duration(seconds: 22),
      duration: Duration(seconds: 4),
      type: EffectEventTypes.beat,
      parameters: {
        'bpm': 300,
        'palette': <String>['#3AE0FF', '#8A6BFF'],
        'pattern': 'chase',
        'decay': 0.9,
        'brightnessMin': 0.02,
      },
    ),
    EffectEvent(
      at: Duration(seconds: 26),
      duration: Duration(seconds: 3),
      type: EffectEventTypes.beat,
      parameters: {
        'bpm': 600,
        'palette': <String>['#FFFFFF', '#9BE7FF'],
        'pattern': 'chase',
        'decay': 0.9,
        'brightnessMin': 0.1,
      },
    ),
    EffectEvent(
      at: Duration(seconds: 29),
      duration: Duration(milliseconds: 1500),
      type: EffectEventTypes.magicFlash,
      parameters: {'color': '#FFFFFF', 'target': 'all'},
    ),
  ],
);

/// A jungle morning, until the ground starts to shake. Something huge walks
/// up to the house, roars, and wanders off.
const dinosaurValley = LightingEffect(
  id: 'dinosaur_valley',
  name: 'Dinosaur Valley',
  kind: EffectKind.story,
  collection: 'Dinosaurs',
  description: 'Birdsong, ferns, and footsteps that keep getting closer.',
  loopDuration: Duration(seconds: 44),
  events: [
    EffectEvent(
      at: Duration.zero,
      duration: Duration(seconds: 44),
      type: EffectEventTypes.ambientPalette,
      parameters: {
        'palette': <String>['#1F5C1A', '#3D7A1F', '#6B8F1A', '#145218'],
        'brightnessMin': 0.30,
        'brightnessMax': 0.60,
        'speed': 0.04,
      },
    ),
    EffectEvent(
      at: Duration(seconds: 2),
      duration: Duration(seconds: 5),
      type: EffectEventTypes.surprise,
      parameters: {'color': '#FFE24A', 'count': 4, 'brightness': 0.6},
    ),
    EffectEvent(
      at: Duration(seconds: 9),
      duration: Duration(seconds: 10),
      type: EffectEventTypes.footsteps,
      parameters: {
        'color': '#8A6A3A',
        'pattern': 'approach',
        'steps': 8,
        'interval': 1200,
        'thump': 350,
        'brightness': 0.5,
        'crescendo': 1.0,
        'shake': 0.7,
      },
    ),
    EffectEvent(
      at: Duration(seconds: 20),
      duration: Duration(milliseconds: 2200),
      type: EffectEventTypes.magicFlash,
      parameters: {'color': '#FF3A1A', 'target': 'all'},
    ),
    EffectEvent(
      at: Duration(milliseconds: 22200),
      duration: Duration(seconds: 2),
      type: EffectEventTypes.dim,
      parameters: {'level': 0.2},
    ),
    EffectEvent(
      at: Duration(seconds: 26),
      duration: Duration(seconds: 10),
      type: EffectEventTypes.footsteps,
      parameters: {
        'color': '#8A6A3A',
        'pattern': 'approach',
        'steps': 7,
        'interval': 1400,
        'thump': 350,
        'brightness': 0.5,
        'crescendo': -1.0,
        'shake': 0.5,
      },
    ),
  ],
);

/// The deep ocean at night: jellyfish pulse, an anglerfish's lure blinks,
/// and a whale glides past.
const deepSeaGlow = LightingEffect(
  id: 'deep_sea_glow',
  name: 'Deep Sea Glow',
  kind: EffectKind.story,
  collection: 'Underwater',
  description: 'Bioluminescent life in the dark, and a whale passing by.',
  loopDuration: Duration(seconds: 48),
  events: [
    EffectEvent(
      at: Duration.zero,
      duration: Duration(seconds: 48),
      type: EffectEventTypes.ambientPalette,
      parameters: {
        'palette': <String>['#020B24', '#04163A', '#061F4A'],
        'brightnessMin': 0.06,
        'brightnessMax': 0.18,
        'speed': 0.02,
      },
    ),
    EffectEvent(
      at: Duration(seconds: 2),
      duration: Duration(seconds: 12),
      type: EffectEventTypes.surprise,
      parameters: {'color': '#3AF0FF', 'count': 5, 'brightness': 0.55},
    ),
    EffectEvent(
      at: Duration(seconds: 10),
      duration: Duration(seconds: 10),
      type: EffectEventTypes.surprise,
      parameters: {'color': '#C46BFF', 'count': 4, 'brightness': 0.5},
    ),
    EffectEvent(
      at: Duration(seconds: 21),
      duration: Duration(seconds: 3),
      type: EffectEventTypes.beat,
      parameters: {
        'bpm': 70,
        'palette': <String>['#E8FF4A'],
        'pattern': 'chase',
        'decay': 0.4,
        'brightnessMin': 0.0,
        'brightness': 0.7,
        'chance': 0.8,
      },
    ),
    EffectEvent(
      at: Duration(seconds: 28),
      duration: Duration(seconds: 14),
      type: EffectEventTypes.travel,
      parameters: {
        'color': '#2A7FBF',
        'pattern': 'sweep',
        'width': 2.2,
        'brightness': 0.45,
      },
    ),
  ],
);

final builtinAdventures = <LightingEffect>[
  hiddenTreasure,
  krakensCove,
  meteorShower,
  dinosaurValley,
  deepSeaGlow,
];
