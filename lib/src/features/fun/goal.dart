import '../../core/effects/effect.dart';
import '../../core/effects/effect_event.dart';

/// A team's colours, for the goal celebration.
enum GoalTeam {
  italy(['#0066CC', '#FFFFFF']),
  germany(['#FFFFFF', '#000000', '#DD0000']),
  france(['#0055A4', '#FFFFFF', '#EF4135']),
  spain(['#C60B1E', '#FFC400']),
  netherlands(['#FF6C00', '#FFFFFF']),
  brazil(['#FFDF00', '#009C3B', '#002776']),
  japan(['#FFFFFF', '#BC002D', '#00205B']),
  england(['#FFFFFF', '#CE1124']);

  const GoalTeam(this.colors);

  final List<String> colors;
}

/// Goal! The room bursts into a team's colours: a white flash, colours
/// popping across the lamps and sweeping the room, then the colours a
/// while longer before the lights go back. Nothing flashes fast.
abstract final class Goal {
  static const party = Duration(seconds: 12);
  static const lasts = Duration(seconds: 40);

  /// The colours a team of your own can take.
  static const swatches = [
    '#0066CC', '#FFFFFF', '#000000', '#DD0000', '#FFC400', //
    '#009C3B', '#FF6C00', '#7B2CBF', '#87CEEB', '#8B0000',
  ];

  static const _prefix = '${LightingEffect.generatedPrefix}goal:';

  /// The celebration in [colors] (`#RRGGBB`, one to three), named [name].
  static LightingEffect effect(String name, List<String> colors) {
    final palette =
        colors.isEmpty ? const ['#FFFFFF'] : colors.take(3).toList();
    final shown =
        palette.length == 1 ? [palette.first, palette.first] : palette;
    return LightingEffect(
      id: '$_prefix${[
        for (final c in palette) c.replaceFirst('#', '')
      ].join('-')}',
      name: name,
      kind: EffectKind.interactive,
      isLooping: false,
      loopDuration: lasts,
      events: [
        EffectEvent(
          at: Duration.zero,
          duration: party,
          type: EffectEventTypes.ambientPalette,
          parameters: {
            'palette': shown,
            'brightnessMin': 0.6,
            'brightnessMax': 1,
            'speed': 0.35,
          },
        ),
        EffectEvent(
          at: party,
          duration: lasts - party,
          type: EffectEventTypes.ambientPalette,
          parameters: {
            'palette': shown,
            'brightnessMin': 0.5,
            'brightnessMax': 0.8,
            'speed': 0.08,
          },
        ),
        const EffectEvent(
          at: Duration.zero,
          duration: Duration(milliseconds: 700),
          type: EffectEventTypes.magicFlash,
          parameters: {'color': '#FFFFFF', 'target': 'all', 'brightness': 1},
        ),
        for (var i = 0; i < 4; i++)
          EffectEvent(
            at: Duration(milliseconds: 600 + 1100 * i),
            duration: const Duration(milliseconds: 900),
            type: EffectEventTypes.surprise,
            parameters: {'color': shown[i % shown.length], 'count': 4},
          ),
        for (var i = 0; i < 3; i++)
          EffectEvent(
            at: Duration(seconds: 5 + 2 * i),
            duration: const Duration(milliseconds: 1600),
            type: EffectEventTypes.travel,
            parameters: {
              'color': shown[(i + 1) % shown.length],
              'brightness': 1,
            },
          ),
      ],
    );
  }

  /// The colours of a goal celebration, or null for any other effect.
  static List<String>? colorsOf(LightingEffect effect) {
    if (!effect.id.startsWith(_prefix)) {
      return null;
    }
    final colors = [
      for (final hex in effect.id.substring(_prefix.length).split('-'))
        if (RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(hex)) '#${hex.toUpperCase()}',
    ];
    return colors.isEmpty ? null : colors;
  }

  /// The colours a saved choice stands for: a team's name, or the colours
  /// of a team of your own (`#RRGGBB,#RRGGBB`); Italy otherwise.
  static List<String> colorsOfChoice(String? choice) {
    if (choice == null) {
      return GoalTeam.italy.colors;
    }
    final team = GoalTeam.values.asNameMap()[choice];
    if (team != null) {
      return team.colors;
    }
    final own = [
      for (final c in choice.split(','))
        if (RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(c)) c.toUpperCase(),
    ];
    return own.isEmpty ? GoalTeam.italy.colors : own.take(3).toList();
  }
}
