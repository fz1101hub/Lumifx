import '../../core/effects/effect.dart';
import '../../core/effects/effect_event.dart';
import '../common/app_text.dart';
import 'light_timer.dart';

/// Rounds of focus with short breaks between them, shown by the lights:
/// warm white turning orange while you focus, calm greens while you rest,
/// three soft flashes at each change and a little party at the end.
class Pomodoro {
  Pomodoro({
    this.rounds = 4,
    this.work = const Duration(minutes: 25),
    this.rest = const Duration(minutes: 5),
  })  : assert(rounds > 0),
        phases = _phasesOf(rounds, work, rest);

  final int rounds;
  final Duration work;
  final Duration rest;

  /// Focus and break in order: (is a break, start, length). No break
  /// after the last round.
  final List<(bool, Duration, Duration)> phases;

  static const roundChoices = [2, 3, 4];
  static const _prefix = '${LightingEffect.generatedPrefix}pomodoro:';
  static const _focusFrom = '#FFF4E5';
  static const _focusTo = '#FF8A2B';
  static const _restColors = ['#7CFF6B', '#B5E550', '#3DDC84'];

  /// The end of the last round.
  Duration get length => phases.last.$2 + phases.last.$3;

  /// The pomodoro of a pomodoro effect, or null for any other effect.
  static Pomodoro? of(LightingEffect effect) {
    if (!effect.id.startsWith(_prefix)) {
      return null;
    }
    final parts = effect.id.substring(_prefix.length).split(':');
    if (parts.length != 3) {
      return null;
    }
    final [rounds, work, rest] = [for (final p in parts) int.tryParse(p)];
    if (rounds == null ||
        work == null ||
        rest == null ||
        rounds < 1 ||
        rounds > 12 ||
        work < 1 ||
        rest < 1) {
      return null;
    }
    return Pomodoro(
      rounds: rounds,
      work: Duration(seconds: work),
      rest: Duration(seconds: rest),
    );
  }

  static List<(bool, Duration, Duration)> _phasesOf(
    int rounds,
    Duration work,
    Duration rest,
  ) {
    final phases = <(bool, Duration, Duration)>[];
    var at = Duration.zero;
    for (var round = 0; round < rounds; round++) {
      phases.add((false, at, work));
      at += work;
      if (round < rounds - 1) {
        phases.add((true, at, rest));
        at += rest;
      }
    }
    return phases;
  }

  /// The phase at [position]: its index in [phases], or null once over.
  int? phaseAt(Duration position) {
    for (final (i, (_, at, length)) in phases.indexed) {
      if (position >= at && position < at + length) {
        return i;
      }
    }
    return null;
  }

  /// The focus round of phase [index], from 1.
  int roundOf(int index) => index ~/ 2 + 1;

  LightingEffect effect(String name) {
    EffectEvent flashes(Duration at, String color, int i) => EffectEvent(
          at: at + Duration(milliseconds: 1200 * i),
          duration: const Duration(milliseconds: 800),
          type: EffectEventTypes.magicFlash,
          parameters: {'color': color, 'target': 'all', 'brightness': 0.8},
        );
    final end = length;
    return LightingEffect(
      id: '$_prefix$rounds:${work.inSeconds}:${rest.inSeconds}',
      name: name,
      kind: EffectKind.interactive,
      isLooping: false,
      loopDuration: end + LightTimer.ending,
      events: [
        for (final (isBreak, at, length) in phases)
          if (isBreak) ...[
            EffectEvent(
              at: at,
              duration: length,
              type: EffectEventTypes.ambientPalette,
              parameters: const {
                'palette': _restColors,
                'brightnessMin': 0.4,
                'brightnessMax': 0.6,
                'speed': 0.05,
              },
            ),
            for (var i = 0; i < 3; i++) flashes(at, _restColors.first, i),
          ] else ...[
            EffectEvent(
              at: at,
              duration: length,
              type: EffectEventTypes.countdown,
              parameters: const {
                'from': _focusFrom,
                'to': _focusTo,
                'brightness': 0.8,
              },
            ),
            if (at > Duration.zero)
              for (var i = 0; i < 3; i++) flashes(at, _focusFrom, i),
          ],
        // The end: a little party, as the children's timers have.
        EffectEvent(
          at: end,
          duration: LightTimer.ending,
          type: EffectEventTypes.ambientPalette,
          parameters: const {
            'palette': <String>[_focusTo, '#7CFF6B'],
            'brightnessMin': 0.3,
            'brightnessMax': 0.6,
            'speed': 0.2,
          },
        ),
        for (final (i, color)
            in const ['#FF4F7B', '#FFD740', '#40C4FF'].indexed)
          EffectEvent(
            at: end + Duration(seconds: i),
            duration: const Duration(milliseconds: 1500),
            type: EffectEventTypes.surprise,
            parameters: {'color': color, 'count': 4},
          ),
      ],
    );
  }

  /// What each phase asks, said as it starts.
  List<(int, String)> narration(AppLocalizations l10n) => [
        for (final (i, (isBreak, at, _)) in phases.indexed)
          (
            at.inSeconds,
            isBreak
                ? l10n.pomodoroBreak
                : l10n.pomodoroFocus(roundOf(i), rounds),
          ),
        (length.inSeconds, l10n.pomodoroDone),
      ];
}
