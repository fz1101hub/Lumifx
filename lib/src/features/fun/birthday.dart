import 'dart:math' as math;

import '../../core/effects/effect.dart';
import '../../core/effects/effect_event.dart';
import '../common/app_text.dart';

/// A birthday party of light: candles that light up one by one and
/// flicker while a wish is made, then, once they are blown out, a moment
/// of darkness and the room bursts into colour.
///
/// The name and the age travel in the effects' ids, so that the words of
/// the party (read along, read aloud) can greet the right person.
class Birthday {
  Birthday({String name = '', int age = 0})
      : name = _clip(name.trim()),
        age = age.clamp(0, maxAge);

  /// Who is celebrating; may be empty.
  final String name;

  /// How old they turn; 0 when not said.
  final int age;

  static const maxName = 30;
  static const maxAge = 120;

  static const _candlesPrefix =
      '${LightingEffect.generatedPrefix}birthday:candles:';
  static const _partyPrefix =
      '${LightingEffect.generatedPrefix}birthday:party:';

  /// How long the party lasts once the candles are out.
  static const partyLength = Duration(seconds: 30);

  /// Candles on the cake: one per year, ten at most, five when the age is
  /// not said.
  int get candles => age == 0 ? 5 : math.min(age, 10);

  /// The birthday of a party effect, or null for any other effect.
  static Birthday? of(LightingEffect effect) {
    final id = effect.id;
    final rest = id.startsWith(_candlesPrefix)
        ? id.substring(_candlesPrefix.length)
        : id.startsWith(_partyPrefix)
            ? id.substring(_partyPrefix.length)
            : null;
    if (rest == null) {
      return null;
    }
    final colon = rest.indexOf(':');
    if (colon < 0) {
      return null;
    }
    return Birthday(
      age: int.tryParse(rest.substring(0, colon)) ?? 0,
      name: rest.substring(colon + 1),
    );
  }

  /// Whether [effect] is the candles (not the party) of a birthday.
  static bool isCandles(LightingEffect effect) =>
      effect.id.startsWith(_candlesPrefix);

  /// "Happy birthday, Anna!", or without a name "Happy birthday!".
  String title(AppLocalizations l10n) =>
      name.isEmpty ? l10n.birthdayHappy : l10n.birthdayHappyName(name);

  /// The candles, lit one by one, flickering until they are blown out (ten
  /// minutes at most).
  LightingEffect candlesEffect(AppLocalizations l10n) {
    const flame = ['#FF9A2E', '#FFB347', '#FF7A1A', '#FFC870'];
    return LightingEffect(
      id: '$_candlesPrefix$age:$name',
      name: title(l10n),
      kind: EffectKind.interactive,
      isLooping: false,
      loopDuration: const Duration(minutes: 10),
      events: [
        const EffectEvent(
          at: Duration.zero,
          duration: Duration(minutes: 10),
          type: EffectEventTypes.ambientPalette,
          parameters: {
            'palette': flame,
            'brightnessMin': 0.18,
            'brightnessMax': 0.5,
            'speed': 0.06,
            'flicker': 0.9,
          },
        ),
        // The room waits in the dark while the candles are lit.
        EffectEvent(
          at: Duration.zero,
          duration: Duration(milliseconds: 1000 + 600 * candles),
          type: EffectEventTypes.dim,
          parameters: const {'level': 0.15},
        ),
        for (var i = 0; i < candles; i++)
          EffectEvent(
            at: Duration(milliseconds: 600 + 600 * i),
            duration: const Duration(milliseconds: 700),
            type: EffectEventTypes.magicFlash,
            parameters: const {
              'color': '#FFD27F',
              'target': 'random_light',
              'brightness': 0.8,
            },
          ),
      ],
    );
  }

  /// Darkness for a breath, a white flash, confetti in every colour and a
  /// rainbow; it plays once.
  LightingEffect partyEffect(AppLocalizations l10n) {
    const confetti = [
      '#FF3B5C', '#FFD740', '#40C4FF', '#7CFF6B', '#C86BFF', //
      '#FF8A2B', '#FF4FC3', '#00E5D4', '#FFF176', '#536DFE',
    ];
    return LightingEffect(
      id: '$_partyPrefix$age:$name',
      name: title(l10n),
      kind: EffectKind.interactive,
      isLooping: false,
      loopDuration: partyLength,
      events: [
        const EffectEvent(
          at: Duration.zero,
          duration: Duration(seconds: 2),
          type: EffectEventTypes.ambientPalette,
          parameters: {
            'palette': <String>['#FF9A2E', '#FF7A1A'],
            'brightnessMin': 0.2,
            'brightnessMax': 0.3,
            'speed': 0.05,
          },
        ),
        // Whoosh: the candles go out.
        const EffectEvent(
          at: Duration.zero,
          duration: Duration(milliseconds: 2200),
          type: EffectEventTypes.dim,
          parameters: {'level': 0.0},
        ),
        const EffectEvent(
          at: Duration(seconds: 2),
          duration: Duration(seconds: 28),
          type: EffectEventTypes.ambientPalette,
          parameters: {
            'palette': <String>['#FF3B5C', '#FFD740', '#40C4FF', '#C86BFF'],
            'brightnessMin': 0.35,
            'brightnessMax': 0.8,
            'speed': 0.12,
          },
        ),
        const EffectEvent(
          at: Duration(seconds: 2),
          duration: Duration(milliseconds: 1500),
          type: EffectEventTypes.magicFlash,
          parameters: {'color': '#FFFFFF', 'target': 'all', 'brightness': 1.0},
        ),
        for (final (i, color) in confetti.indexed)
          EffectEvent(
            at: Duration(milliseconds: 3000 + 1100 * i),
            duration: const Duration(milliseconds: 1600),
            type: EffectEventTypes.surprise,
            parameters: {'color': color, 'count': 4, 'brightness': 0.95},
          ),
        const EffectEvent(
          at: Duration(seconds: 15),
          duration: Duration(seconds: 6),
          type: EffectEventTypes.travel,
          parameters: {
            'color': '#FF4FC3',
            'pattern': 'ping_pong',
            'passes': 3,
            'width': 1.4,
            'brightness': 1.0,
          },
        ),
        const EffectEvent(
          at: Duration(seconds: 25),
          duration: Duration(seconds: 2),
          type: EffectEventTypes.magicFlash,
          parameters: {'color': '#FFD740', 'target': 'all', 'brightness': 0.9},
        ),
      ],
    );
  }

  /// The words of [effect], one of this birthday's, with the second each
  /// is said.
  List<(int, String)> narration(LightingEffect effect, AppLocalizations l10n) {
    if (effect.id.startsWith(_candlesPrefix)) {
      return [(0, title(l10n)), (6, l10n.birthdayMakeAWish)];
    }
    return [
      (0, l10n.birthdayWhoosh),
      (2, name.isEmpty ? l10n.birthdayHooray : l10n.birthdayHoorayName(name)),
      (15, age == 0 ? l10n.birthdayWonderfulDay : l10n.birthdayYearsOld(age)),
    ];
  }

  static String _clip(String name) => name.runes.length > maxName
      ? String.fromCharCodes(name.runes.take(maxName)).trim()
      : name;
}
