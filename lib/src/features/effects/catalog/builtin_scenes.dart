import '../../../core/effects/effect.dart';
import '../../../core/effects/effect_event.dart';

LightingEffect _ambientScene({
  required String id,
  required String name,
  required String collection,
  required String description,
  required Map<String, Object> parameters,
}) {
  return LightingEffect(
    id: id,
    name: name,
    kind: EffectKind.scene,
    collection: collection,
    description: description,
    loopDuration: const Duration(minutes: 5),
    events: [
      EffectEvent(
        at: Duration.zero,
        duration: const Duration(minutes: 5),
        type: EffectEventTypes.ambientPalette,
        parameters: parameters,
      ),
    ],
  );
}

final fireplace = _ambientScene(
  id: 'fireplace',
  name: 'Fireplace',
  collection: 'Relax',
  description: 'Warm, restless flames.',
  parameters: {
    'palette': <String>['#FF6A00', '#FF9A2E', '#D93A00', '#FFB766'],
    'brightnessMin': 0.30,
    'brightnessMax': 0.85,
    'speed': 0.12,
    'flicker': 0.9,
  },
);

final ocean = _ambientScene(
  id: 'ocean',
  name: 'Ocean',
  collection: 'Nature',
  description: 'Slow waves of deep blue and teal.',
  parameters: {
    'palette': <String>['#003F7D', '#0077B6', '#00B4D8', '#48CAE4'],
    'brightnessMin': 0.35,
    'brightnessMax': 0.80,
    'speed': 0.035,
  },
);

final aurora = _ambientScene(
  id: 'aurora',
  name: 'Aurora',
  collection: 'Nature',
  description: 'Green and violet curtains drifting across the sky.',
  parameters: {
    'palette': <String>['#00FF9C', '#0FA3B1', '#7B2FF7', '#2EC4B6'],
    'brightnessMin': 0.25,
    'brightnessMax': 0.75,
    'speed': 0.025,
  },
);

final sunset = _ambientScene(
  id: 'sunset',
  name: 'Sunset',
  collection: 'Relax',
  description: 'Golden hour that never ends.',
  parameters: {
    'palette': <String>['#FF7B39', '#FF4E50', '#FC913A', '#F9D423'],
    'brightnessMin': 0.40,
    'brightnessMax': 0.75,
    'speed': 0.02,
  },
);

/// Rain-dark sky with lightning that never strikes the same way twice.
const thunderstorm = LightingEffect(
  id: 'thunderstorm',
  name: 'Thunderstorm',
  kind: EffectKind.scene,
  collection: 'Nature',
  description: 'Heavy clouds, restless rain and lightning across the room.',
  prefersStreaming: true,
  loopDuration: Duration(seconds: 45),
  events: [
    EffectEvent(
      at: Duration.zero,
      duration: Duration(seconds: 45),
      type: EffectEventTypes.ambientPalette,
      parameters: {
        'palette': <String>['#0B1426', '#1C2B45', '#2A3550', '#121A2E'],
        'brightnessMin': 0.08,
        'brightnessMax': 0.30,
        'speed': 0.05,
        'flicker': 0.5,
      },
    ),
    EffectEvent(
      at: Duration(seconds: 6),
      duration: Duration(milliseconds: 900),
      type: EffectEventTypes.lightning,
      parameters: {'strikes': 2, 'target': 'random_light'},
    ),
    EffectEvent(
      at: Duration(seconds: 15),
      duration: Duration(milliseconds: 1400),
      type: EffectEventTypes.lightning,
      parameters: {'strikes': 4, 'target': 'all', 'chance': 0.8},
    ),
    EffectEvent(
      at: Duration(seconds: 26),
      duration: Duration(milliseconds: 1000),
      type: EffectEventTypes.lightning,
      parameters: {
        'strikes': 3,
        'target': 'random_lights',
        'count': 2,
        'chance': 0.7,
      },
    ),
    EffectEvent(
      at: Duration(seconds: 37),
      duration: Duration(milliseconds: 800),
      type: EffectEventTypes.lightning,
      parameters: {'strikes': 2, 'target': 'random_light', 'chance': 0.6},
    ),
  ],
);

/// Saturated colors on the beat: everything, then a chase, then halves.
const disco = LightingEffect(
  id: 'disco',
  name: 'Disco',
  kind: EffectKind.scene,
  collection: 'Party',
  description: 'Four on the floor at 124 BPM.',
  prefersStreaming: true,
  loopDuration: Duration(seconds: 32),
  events: [
    EffectEvent(
      at: Duration.zero,
      duration: Duration(seconds: 32),
      type: EffectEventTypes.ambientPalette,
      parameters: {
        'palette': <String>['#2B0A3D', '#0A1A3D'],
        'brightnessMin': 0.05,
        'brightnessMax': 0.15,
      },
    ),
    EffectEvent(
      at: Duration.zero,
      duration: Duration(seconds: 16),
      type: EffectEventTypes.beat,
      parameters: {
        'bpm': 124,
        'palette': <String>['#FF0080', '#00E5FF', '#FFE600', '#7CFF00'],
        'pattern': 'all',
      },
    ),
    EffectEvent(
      at: Duration(seconds: 16),
      duration: Duration(seconds: 8),
      type: EffectEventTypes.beat,
      parameters: {
        'bpm': 248,
        'palette': <String>['#FF0080', '#8A2BE2', '#00E5FF'],
        'pattern': 'chase',
        'decay': 0.9,
      },
    ),
    EffectEvent(
      at: Duration(seconds: 24),
      duration: Duration(seconds: 8),
      type: EffectEventTypes.beat,
      parameters: {
        'bpm': 124,
        'palette': <String>['#FF3D00', '#00E5FF', '#FF0080', '#FFE600'],
        'pattern': 'alternate',
        'decay': 0.7,
      },
    ),
  ],
);

final builtinScenes = <LightingEffect>[
  fireplace,
  ocean,
  aurora,
  sunset,
  thunderstorm,
  disco,
];
