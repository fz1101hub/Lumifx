import 'dart:math' as math;

import '../../core/effects/effect.dart';
import '../../core/effects/effect_event.dart';
import '../common/app_text.dart';

/// Something to wait for: a birthday, a holiday, a trip.
class Countdown {
  Countdown({required this.id, required String name, required this.date})
      : name = name.trim().length > maxName
            ? String.fromCharCodes(name.trim().runes.take(maxName)).trim()
            : name.trim();

  final String id;
  final String name;

  /// The day, at midnight (only the date counts).
  final DateTime date;

  static const maxName = 40;
  static const maxCountdowns = 20;
  static const _prefix = '${LightingEffect.generatedPrefix}countdown:';

  static String newId() => 'c${DateTime.now().microsecondsSinceEpoch}';

  /// Sleeps from [today] to the day: 0 on the day, negative after it.
  int sleepsFrom(DateTime today) =>
      DateTime.utc(date.year, date.month, date.day)
          .difference(DateTime.utc(today.year, today.month, today.day))
          .inDays;

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'date': '${date.year.toString().padLeft(4, '0')}-'
            '${date.month.toString().padLeft(2, '0')}-'
            '${date.day.toString().padLeft(2, '0')}',
      };

  /// Null when [json] is not a usable countdown.
  static Countdown? fromJson(Object? json) {
    if (json is! Map) {
      return null;
    }
    final id = json['id'];
    final name = json['name'];
    final date = json['date'];
    if (id is! String ||
        id.isEmpty ||
        id.length > 40 ||
        name is! String ||
        name.trim().isEmpty ||
        date is! String) {
      return null;
    }
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(date);
    if (match == null) {
      return null;
    }
    final [year, month, day] = [
      for (var g = 1; g <= 3; g++) int.parse(match.group(g)!),
    ];
    if (month < 1 || month > 12 || day < 1 || day > 31) {
      return null;
    }
    return Countdown(id: id, name: name, date: DateTime(year, month, day));
  }

  /// The sleeps left of a countdown effect, or null for another effect.
  static int? sleepsOf(LightingEffect effect) {
    if (!effect.id.startsWith(_prefix)) {
      return null;
    }
    return int.tryParse(effect.id.substring(_prefix.length).split(':').first);
  }

  /// [sleeps] on the lights: one golden spark per sleep (ten at most),
  /// then a sparkle; on the day, a party. Plays once.
  LightingEffect effect(int sleeps, String title) {
    final sparks = math.min(math.max(sleeps, 0), 10);
    final sparksEnd = 2 + sparks;
    final length = Duration(seconds: sleeps <= 0 ? 16 : sparksEnd + 6);
    return LightingEffect(
      id: '$_prefix$sleeps:$id',
      name: title,
      kind: EffectKind.interactive,
      isLooping: false,
      loopDuration: length,
      events: [
        EffectEvent(
          at: Duration.zero,
          duration: length,
          type: EffectEventTypes.ambientPalette,
          parameters: sleeps <= 0
              ? const {
                  'palette': <String>[
                    '#FF3B5C',
                    '#FFD740',
                    '#40C4FF',
                    '#C86BFF'
                  ],
                  'brightnessMin': 0.35,
                  'brightnessMax': 0.8,
                  'speed': 0.12,
                }
              : const {
                  'palette': <String>['#1C1A5E', '#3A2F7A'],
                  'brightnessMin': 0.12,
                  'brightnessMax': 0.25,
                  'speed': 0.03,
                },
        ),
        if (sleeps <= 0)
          for (final (i, color)
              in const ['#FF4F7B', '#FFD740', '#40C4FF', '#7CFF6B'].indexed)
            EffectEvent(
              at: Duration(seconds: 2 + 3 * i),
              duration: const Duration(milliseconds: 1800),
              type: EffectEventTypes.surprise,
              parameters: {'color': color, 'count': 4},
            )
        else ...[
          for (var i = 0; i < sparks; i++)
            EffectEvent(
              at: Duration(seconds: 2 + i),
              duration: const Duration(milliseconds: 800),
              type: EffectEventTypes.magicFlash,
              parameters: const {
                'color': '#FFD36B',
                'target': 'random_light',
                'brightness': 0.9,
              },
            ),
          EffectEvent(
            at: Duration(seconds: sparksEnd),
            duration: const Duration(seconds: 4),
            type: EffectEventTypes.surprise,
            parameters: const {'color': '#FFF4D6', 'count': 5},
          ),
        ],
      ],
    );
  }

  /// "5 sleeps to Anna's birthday!", or "Anna's birthday is today!".
  String sleepsText(int sleeps, AppLocalizations l10n) => sleeps <= 0
      ? l10n.countdownToday(name)
      : l10n.countdownSleeps(sleeps, name);
}
