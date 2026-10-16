import '../../../core/effects/effect.dart';
import '../../../core/effects/effect_event.dart';

/// A Music Sync effect: a dim background with one `music` event on top.
LightingEffect _musicEffect({
  required String id,
  required String name,
  required String description,
  required Map<String, Object> parameters,
  List<String> background = const ['#120A24', '#0A1424'],
  bool prefersStreaming = true,
}) {
  return LightingEffect(
    id: id,
    name: name,
    kind: EffectKind.interactive,
    collection: 'Music Sync',
    description: description,
    prefersStreaming: prefersStreaming,
    loopDuration: const Duration(minutes: 10),
    events: [
      EffectEvent(
        at: Duration.zero,
        duration: const Duration(minutes: 10),
        type: EffectEventTypes.ambientPalette,
        parameters: {
          'palette': background,
          'brightnessMin': 0.02,
          'brightnessMax': 0.08,
          'speed': 0.02,
        },
      ),
      EffectEvent(
        at: Duration.zero,
        duration: const Duration(minutes: 10),
        type: EffectEventTypes.music,
        parameters: parameters,
      ),
    ],
  );
}

final beatPulse = _musicEffect(
  id: 'beat_pulse',
  name: 'Beat Pulse',
  description: 'Every light flashes on the beat, in a new color each time.',
  parameters: {
    'mode': 'pulse',
    'palette': <String>['#FF0055', '#00D5FF', '#FFC400', '#8C3CFF', '#00FF85'],
    'decay': 0.22,
  },
);

final partyChase = _musicEffect(
  id: 'party_chase',
  name: 'Party Chase',
  description: 'Each beat throws the light to the next lamp.',
  parameters: {
    'mode': 'chase',
    'palette': <String>['#FF2BD6', '#2BF5FF', '#FFF02B'],
    'decay': 0.35,
  },
);

final spectrum = _musicEffect(
  id: 'spectrum',
  name: 'Spectrum',
  description: 'Bass on the left, treble on the right, like an equalizer.',
  parameters: {
    'mode': 'spectrum',
    'palette': <String>['#FF1E1E', '#FF9A00', '#E8FF00', '#00FF7B', '#009DFF'],
    'decay': 0.2,
  },
);

final moodGlow = _musicEffect(
  id: 'mood_glow',
  name: 'Mood Glow',
  description: 'A soft glow that breathes with the music. Gentle enough for '
      'any light.',
  prefersStreaming: false,
  background: const ['#1A0F08', '#100A14'],
  parameters: {
    'mode': 'energy',
    'palette': <String>['#FF6A2B', '#FF3D7F', '#9B5CFF', '#3DA8FF'],
    'decay': 0.6,
    'brightnessMin': 0.1,
  },
);

/// TV Sync: the phone's camera watches the TV and the lights take its
/// colours, left to right. A dim warm glow shows until the first frame.
final tvSync = LightingEffect(
  id: 'tv_sync',
  name: 'TV Sync',
  kind: EffectKind.interactive,
  description: 'Point the camera at the TV: the lights take the colours on '
      'screen, left to right.',
  prefersStreaming: true,
  loopDuration: const Duration(minutes: 10),
  events: [
    EffectEvent(
      at: Duration.zero,
      duration: const Duration(minutes: 10),
      type: EffectEventTypes.ambientPalette,
      parameters: {
        'palette': const <String>['#2A1A10', '#1A1420'],
        'brightnessMin': 0.04,
        'brightnessMax': 0.1,
        'speed': 0.02,
      },
    ),
    EffectEvent(
      at: Duration.zero,
      duration: const Duration(minutes: 10),
      type: EffectEventTypes.screen,
      parameters: const {'minBrightness': 0.02},
    ),
  ],
);

final builtinInteractive = <LightingEffect>[
  beatPulse,
  partyChase,
  spectrum,
  moodGlow,
  tvSync,
];
