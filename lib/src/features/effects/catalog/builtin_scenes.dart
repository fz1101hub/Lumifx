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

final builtinScenes = <LightingEffect>[
  fireplace,
  ocean,
  aurora,
  sunset,
];
