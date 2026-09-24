import '../../../core/effects/effect.dart';
import '../../../core/effects/effect_event.dart';

const emeraldTrickster = LightingEffect(
  id: 'emerald_trickster',
  name: 'Emerald Trickster',
  kind: EffectKind.story,
  events: [
    EffectEvent(
      at: Duration.zero,
      duration: Duration(seconds: 8),
      type: 'ambient_palette',
      parameters: {
        'palette': <String>['#063B20', '#0F8F45', '#56E56F'],
        'brightnessMin': 0.20,
        'brightnessMax': 0.55,
      },
    ),
    EffectEvent(
      at: Duration(seconds: 8),
      duration: Duration(milliseconds: 700),
      type: 'magic_flash',
      parameters: {
        'color': '#FFD84D',
        'target': 'random_light',
      },
    ),
    EffectEvent(
      at: Duration(seconds: 11),
      duration: Duration(seconds: 9),
      type: 'travel',
      parameters: {
        'color': '#22D763',
        'pattern': 'random_walk',
      },
    ),
    EffectEvent(
      at: Duration(seconds: 23),
      duration: Duration(seconds: 3),
      type: 'surprise',
      parameters: {
        'color': '#FFCE3A',
        'count': 3,
      },
    ),
  ],
);
