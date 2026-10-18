import 'package:flutter/material.dart';

import '../../core/sound/melodies.dart';
import '../common/app_text.dart';
import '../routines/kid_routine.dart';
import 'monster_spray.dart';

/// A step of the bedtime ritual.
enum RitualStep {
  /// The evening picture routine, done on its own screen.
  routine(Icons.checklist),

  /// The monster spray, on its own screen.
  monsterSpray(Icons.sanitizer_outlined),

  /// A minute of calm breathing: smell the flower, blow out the candle.
  breathing(Icons.spa_outlined),

  /// A story made up for tonight, the child its hero.
  story(Icons.auto_stories_outlined),

  /// A lullaby on the music box.
  lullaby(Icons.music_note_outlined),

  /// The guardian light, which fades out by itself.
  guardian(Icons.shield_moon_outlined);

  const RitualStep(this.icon);

  final IconData icon;

  /// Done on another screen, rather than playing here.
  bool get isInteractive => this == routine || this == monsterSpray;

  String title(AppLocalizations l10n) => switch (this) {
        routine => KidRoutine.evening.title(l10n),
        monsterSpray => l10n.monsterSpray,
        breathing => l10n.breathe,
        story => l10n.ritualStory,
        lullaby => l10n.lullabies,
        guardian => l10n.guardianLight,
      };
}

/// How the family's bedtime ritual goes: which steps, which lullaby and
/// how long the guardian light stays on.
class RitualSettings {
  const RitualSettings({
    this.steps = RitualStep.values,
    this.lullaby = 'brahms',
    this.guardianMinutes = 30,
  });

  /// In the ritual's order; at least one.
  final List<RitualStep> steps;
  final String lullaby;
  final int guardianMinutes;

  RitualSettings withStep(RitualStep step, bool on) {
    final next = [
      for (final s in RitualStep.values)
        if (s == step ? on : steps.contains(s)) s,
    ];
    return next.isEmpty ? this : copyWith(steps: next);
  }

  RitualSettings copyWith({
    List<RitualStep>? steps,
    String? lullaby,
    int? guardianMinutes,
  }) =>
      RitualSettings(
        steps: steps ?? this.steps,
        lullaby: lullaby ?? this.lullaby,
        guardianMinutes: guardianMinutes ?? this.guardianMinutes,
      );

  Map<String, Object?> toJson() => {
        'steps': [for (final s in steps) s.name],
        'lullaby': lullaby,
        'guardianMinutes': guardianMinutes,
      };

  static RitualSettings fromJson(Object? json) {
    if (json is! Map) {
      return const RitualSettings();
    }
    final names = json['steps'];
    final chosen = {
      if (names is List)
        for (final name in names)
          if (name is String)
            if (RitualStep.values.asNameMap()[name] case final step?) step,
    };
    final lullaby = json['lullaby'];
    final minutes = json['guardianMinutes'];
    return RitualSettings(
      steps: chosen.isEmpty
          ? RitualStep.values
          : [
              for (final s in RitualStep.values)
                if (chosen.contains(s)) s
            ],
      lullaby:
          lullaby is String && melodyById(lullaby) != null ? lullaby : 'brahms',
      guardianMinutes:
          minutes is int && MonsterHunt.guardianMinutes.contains(minutes)
              ? minutes
              : 30,
    );
  }
}
