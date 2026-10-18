import '../../core/effects/effect.dart';
import '../../core/effects/effect_event.dart';
import '../../core/sound/soundscape.dart';

/// Timers shown by the lights: they change colour as time passes, then
/// end with a little party of light (for children) or a gentle signal.
enum LightTimer {
  teeth(minutes: 2, from: '#3DDCFF', to: '#B388FF', celebrate: true),
  tidyUp(minutes: 10, from: '#7CFF6B', to: '#FFB23F', celebrate: true),
  homework(minutes: 20, from: '#9BE564', to: '#FFD36B', celebrate: true),
  focus(minutes: 25, from: '#FFF4E5', to: '#FF8A2B', celebrate: false),
  cooking(minutes: 10, from: '#FFD36B', to: '#FF4F4F', celebrate: false);

  const LightTimer({
    required this.minutes,
    required this.from,
    required this.to,
    required this.celebrate,
  });

  /// The usual length; cooking lets the user choose.
  final int minutes;
  final String from;
  final String to;
  final bool celebrate;

  /// How long the ending lasts after the time is up.
  static const ending = Duration(seconds: 6);

  /// The effect that counts [length] down under [name]; it plays once and
  /// the player stops it at its end. With [tune], a music box plays
  /// through the time (see `soundscapeOf`).
  LightingEffect effect({
    required String name,
    Duration? length,
    bool tune = false,
  }) {
    final time = length ?? Duration(minutes: minutes);
    return LightingEffect(
      id: '${LightingEffect.generatedPrefix}timer:${this.name}'
          '${tune ? timerTuneSuffix : ''}',
      name: name,
      kind: EffectKind.interactive,
      isLooping: false,
      loopDuration: time + ending,
      events: [
        EffectEvent(
          at: Duration.zero,
          duration: time,
          type: EffectEventTypes.countdown,
          parameters: {'from': from, 'to': to, 'brightness': 0.8},
        ),
        EffectEvent(
          at: time,
          duration: ending,
          type: EffectEventTypes.ambientPalette,
          parameters: {
            'palette': <String>[to, from],
            'brightnessMin': 0.3,
            'brightnessMax': 0.6,
            'speed': 0.2,
          },
        ),
        if (celebrate) ...[
          for (final (i, color)
              in const ['#FF4F7B', '#FFD740', '#40C4FF'].indexed)
            EffectEvent(
              at: time + Duration(seconds: i),
              duration: const Duration(milliseconds: 1500),
              type: EffectEventTypes.surprise,
              parameters: {'color': color, 'count': 4},
            ),
          EffectEvent(
            at: time + const Duration(milliseconds: 3500),
            duration: const Duration(milliseconds: 1500),
            type: EffectEventTypes.magicFlash,
            parameters: {
              'color': '#FFFFFF',
              'target': 'all',
              'brightness': 0.9
            },
          ),
        ] else
          for (var i = 0; i < 3; i++)
            EffectEvent(
              at: time + Duration(milliseconds: 1200 * i),
              duration: const Duration(milliseconds: 800),
              type: EffectEventTypes.magicFlash,
              parameters: {'color': to, 'target': 'all', 'brightness': 0.8},
            ),
      ],
    );
  }
}
