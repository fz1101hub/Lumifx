import 'package:flutter/material.dart';

import '../../core/effects/effect.dart';
import '../../core/effects/engine/effect_player.dart';
import '../../core/effects/engine/light_frame.dart';
import '../common/app_text.dart';
import '../library/effect_library.dart';

/// One line of a story, shown from [at] (seconds into the story's cycle)
/// until the next one.
typedef NarrationLine = (int at, String Function(AppLocalizations) text);

/// The words of every built-in story, timed to its events: the spark, the
/// footsteps, the lightning arrive on screen with the line about them.
final Map<String, List<NarrationLine>> storyNarration = {
  'emerald_trickster': [
    (0, (l) => l.narrationEmeraldTrickster1),
    (8, (l) => l.narrationEmeraldTrickster2),
    (20, (l) => l.narrationEmeraldTrickster3),
    (23, (l) => l.narrationEmeraldTrickster4),
  ],
  'enchanted_fairy': [
    (0, (l) => l.narrationEnchantedFairy1),
    (3, (l) => l.narrationEnchantedFairy2),
    (12, (l) => l.narrationEnchantedFairy3),
    (23, (l) => l.narrationEnchantedFairy4),
  ],
  'goblin_mine': [
    (0, (l) => l.narrationGoblinMine1),
    (3, (l) => l.narrationGoblinMine2),
    (12, (l) => l.narrationGoblinMine3),
    (19, (l) => l.narrationGoblinMine4),
  ],
  'sleeping_dragon': [
    (0, (l) => l.narrationSleepingDragon1),
    (14, (l) => l.narrationSleepingDragon2),
    (17, (l) => l.narrationSleepingDragon3),
    (29, (l) => l.narrationSleepingDragon4),
  ],
  'mischievous_ghost': [
    (0, (l) => l.narrationMischievousGhost1),
    (6, (l) => l.narrationMischievousGhost2),
    (17, (l) => l.narrationMischievousGhost3),
    (19, (l) => l.narrationMischievousGhost4),
  ],
  'haunted_manor': [
    (0, (l) => l.narrationHauntedManor1),
    (5, (l) => l.narrationHauntedManor2),
    (10, (l) => l.narrationHauntedManor3),
    (24, (l) => l.narrationHauntedManor4),
  ],
  'christmas_elves': [
    (0, (l) => l.narrationChristmasElves1),
    (4, (l) => l.narrationChristmasElves2),
    (18, (l) => l.narrationChristmasElves3),
    (28, (l) => l.narrationChristmasElves4),
  ],
  'hidden_treasure': [
    (0, (l) => l.narrationHiddenTreasure1),
    (4, (l) => l.narrationHiddenTreasure2),
    (19, (l) => l.narrationHiddenTreasure3),
    (28, (l) => l.narrationHiddenTreasure4),
  ],
  'krakens_cove': [
    (0, (l) => l.narrationKrakensCove1),
    (6, (l) => l.narrationKrakensCove2),
    (16, (l) => l.narrationKrakensCove3),
    (30, (l) => l.narrationKrakensCove4),
  ],
  'meteor_shower': [
    (0, (l) => l.narrationMeteorShower1),
    (5, (l) => l.narrationMeteorShower2),
    (22, (l) => l.narrationMeteorShower3),
    (29, (l) => l.narrationMeteorShower4),
  ],
  'dinosaur_valley': [
    (0, (l) => l.narrationDinosaurValley1),
    (9, (l) => l.narrationDinosaurValley2),
    (22, (l) => l.narrationDinosaurValley3),
    (26, (l) => l.narrationDinosaurValley4),
  ],
  'deep_sea_glow': [
    (0, (l) => l.narrationDeepSeaGlow1),
    (2, (l) => l.narrationDeepSeaGlow2),
    (21, (l) => l.narrationDeepSeaGlow3),
    (28, (l) => l.narrationDeepSeaGlow4),
  ],
  'pumpkin_patch': [
    (0, (l) => l.narrationPumpkinPatch1),
    (6, (l) => l.narrationPumpkinPatch2),
    (17, (l) => l.narrationPumpkinPatch3),
    (33, (l) => l.narrationPumpkinPatch4),
  ],
  'witches_cauldron': [
    (0, (l) => l.narrationWitchesCauldron1),
    (12, (l) => l.narrationWitchesCauldron2),
    (21, (l) => l.narrationWitchesCauldron3),
    (27, (l) => l.narrationWitchesCauldron4),
  ],
  'vampires_castle': [
    (0, (l) => l.narrationVampiresCastle1),
    (5, (l) => l.narrationVampiresCastle2),
    (16, (l) => l.narrationVampiresCastle3),
    (24, (l) => l.narrationVampiresCastle4),
  ],
  'trick_or_treat': [
    (0, (l) => l.narrationTrickOrTreat1),
    (4, (l) => l.narrationTrickOrTreat2),
    (12, (l) => l.narrationTrickOrTreat3),
    (27, (l) => l.narrationTrickOrTreat4),
  ],
  'santas_workshop': [
    (0, (l) => l.narrationSantasWorkshop1),
    (3, (l) => l.narrationSantasWorkshop2),
    (18, (l) => l.narrationSantasWorkshop3),
    (30, (l) => l.narrationSantasWorkshop4),
  ],
  'silent_snowfall': [
    (0, (l) => l.narrationSilentSnowfall1),
    (2, (l) => l.narrationSilentSnowfall2),
    (26, (l) => l.narrationSilentSnowfall3),
    (40, (l) => l.narrationSilentSnowfall4),
  ],
  'new_year_countdown': [
    (0, (l) => l.narrationNewYearCountdown1),
    (9, (l) => l.narrationNewYearCountdown2),
    (20, (l) => l.narrationNewYearCountdown3),
    (22, (l) => l.narrationNewYearCountdown4),
  ],
  'valentines_glow': [
    (0, (l) => l.narrationValentinesGlow1),
    (6, (l) => l.narrationValentinesGlow2),
    (15, (l) => l.narrationValentinesGlow3),
    (24, (l) => l.narrationValentinesGlow4),
  ],
  'carnival_parade': [
    (0, (l) => l.narrationCarnivalParade1),
    (4, (l) => l.narrationCarnivalParade2),
    (12, (l) => l.narrationCarnivalParade3),
    (18, (l) => l.narrationCarnivalParade4),
  ],
  'easter_egg_hunt': [
    (0, (l) => l.narrationEasterEggHunt1),
    (5, (l) => l.narrationEasterEggHunt2),
    (14, (l) => l.narrationEasterEggHunt3),
    (34, (l) => l.narrationEasterEggHunt4),
  ],
  'candlelight_carol': [
    (0, (l) => l.narrationCandlelightCarol1),
    (2, (l) => l.narrationCandlelightCarol2),
    (26, (l) => l.narrationCandlelightCarol3),
    (44, (l) => l.narrationCandlelightCarol4),
  ],
};

/// The lines of [effect] to read along, with the second each appears: a
/// built-in story's, or the words of a story the user made. Empty when it
/// has none.
List<(int, String)> narrationOf(
  LightingEffect effect,
  AppLocalizations l10n,
  EffectLibrary library,
) {
  if (storyNarration[effect.id] case final lines?) {
    return [for (final (at, text) in lines) (at, text(l10n))];
  }
  return library.userStory(effect.id)?.narration ?? const [];
}

/// The index in [lines] of the line to show at [position] into [effect],
/// or null before the first line and after a story that does not loop has
/// ended.
int? narrationIndexAt(
  LightingEffect effect,
  List<(int, String)> lines,
  Duration position,
) {
  if (lines.isEmpty) {
    return null;
  }
  final cycle = effect.cycleLength;
  var at = position;
  if (cycle > Duration.zero) {
    if (effect.isLooping) {
      at = Duration(
          microseconds: position.inMicroseconds % cycle.inMicroseconds);
    } else if (position >= cycle) {
      return null;
    }
  }
  int? index;
  for (var i = 0; i < lines.length; i++) {
    if (at.inMilliseconds >= lines[i].$1 * 1000) {
      index = i;
    }
  }
  return index;
}

/// The story's words in time with its lights, big enough to read aloud
/// from across a bed. Without a player it shows the opening line.
class ReadAlongCaption extends StatelessWidget {
  const ReadAlongCaption({
    required this.effect,
    required this.lines,
    this.player,
    super.key,
  });

  final LightingEffect effect;
  final List<(int, String)> lines;
  final EffectPlayer? player;

  @override
  Widget build(BuildContext context) {
    final player = this.player;
    if (player == null) {
      return _caption(context, narrationIndexAt(effect, lines, Duration.zero));
    }
    return StreamBuilder<List<LightFrame>>(
      stream: player.frames,
      builder: (context, _) => _caption(
        context,
        narrationIndexAt(effect, lines, player.position),
      ),
    );
  }

  Widget _caption(BuildContext context, int? index) {
    if (index == null) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final text = lines[index].$2;
    return Card(
      margin: EdgeInsets.zero,
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(
              Icons.auto_stories_outlined,
              color: theme.colorScheme.onSecondaryContainer,
            ),
            const SizedBox(width: 16),
            Expanded(
              // Screen readers read each new line as it appears.
              child: Semantics(
                liveRegion: true,
                child: AnimatedSwitcher(
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 400),
                  layoutBuilder: (current, previous) => Stack(
                    alignment: Alignment.centerLeft,
                    children: [...previous, if (current != null) current],
                  ),
                  child: Text(
                    text,
                    key: ValueKey(index),
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: theme.colorScheme.onSecondaryContainer,
                      height: 1.3,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
