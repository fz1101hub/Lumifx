import 'dart:math' as math;

import '../../core/effects/effect.dart';
import '../../core/effects/effect_event.dart';
import '../../core/sound/melody.dart';
import '../../core/sound/soundscape.dart';

/// [melody] on the lights, note by note: each note lights the lamp where
/// its pitch falls (low on the left, high on the right), over a calm
/// background for a lullaby or a festive one for a carol. The tune itself
/// plays with it (see [Soundscape.melody]); plays once.
LightingEffect melodyEffect(
  Melody melody, {
  required int times,
  required String name,
}) {
  final festive = melody.instrument == Instrument.bells;
  final background = festive
      ? const ['#8B0000', '#0B5D1E', '#B8860B']
      : const ['#141A4A', '#2B2466', '#1C2A6B'];
  final notes = festive
      ? const ['#FF2D2D', '#2DFF6B', '#FFD740', '#FFFFFF']
      : const ['#FFD9A0', '#FFB7C5', '#B9D7FF', '#E6D3FF'];
  final (low, high) = melody.range;
  final length = melody.length * times + const Duration(seconds: 2);
  return LightingEffect(
    id: '$melodyEffectPrefix${melody.id}:$times',
    name: name,
    kind: EffectKind.interactive,
    isLooping: false,
    loopDuration: length,
    events: [
      EffectEvent(
        at: Duration.zero,
        duration: length,
        type: EffectEventTypes.ambientPalette,
        parameters: {
          'palette': background,
          'brightnessMin': festive ? 0.25 : 0.08,
          'brightnessMax': festive ? 0.45 : 0.18,
          'speed': 0.03,
        },
      ),
      for (final (i, (at, noteLength, midi))
          in melody.timeline(times: times).indexed)
        EffectEvent(
          at: at,
          duration:
              Duration(milliseconds: math.max(350, noteLength.inMilliseconds)),
          type: EffectEventTypes.magicFlash,
          parameters: {
            'color': notes[i % notes.length],
            'target': 'position',
            'position': high == low ? 0.5 : (midi - low) / (high - low),
            'brightness': festive ? 0.95 : 0.5,
          },
        ),
    ],
  );
}
