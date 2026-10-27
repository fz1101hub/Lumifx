import 'package:flutter/material.dart';

import '../common/app_text.dart';
import '../common/layout.dart';
import '../learn/colour_mixing_screen.dart';
import '../learn/colour_words_screen.dart';
import '../learn/counting_screen.dart';
import '../learn/farm_screen.dart';
import '../music/sing_colour_screen.dart';
import '../learn/morse_screen.dart';
import 'advent_screen.dart';
import '../music_box/light_piano_screen.dart';
import '../music_box/music_box_screen.dart';
import 'birthday_screen.dart';
import 'board_game_screen.dart';
import 'countdowns_screen.dart';
import 'game_screen.dart';
import 'goal_screen.dart';
import 'haunted_party_screen.dart';
import 'hide_and_seek_screen.dart';
import 'hot_cold_screen.dart';
import 'light_games.dart';
import 'noise_light_screen.dart';
import 'simon_screen.dart';

/// Parties and games played with the lights.
class FunScreen extends StatelessWidget {
  const FunScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    Widget entry(
      IconData icon,
      String title,
      String subtitle,
      Widget Function() screen,
    ) =>
        Card(
          child: ListTile(
            minVerticalPadding: 16,
            leading: Icon(icon),
            title: Text(title),
            subtitle: Text(subtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => screen()),
            ),
          ),
        );
    return Scaffold(
      appBar: AppBar(title: Text(l10n.fun)),
      body: ListView(
        padding: context.pageInsets(),
        children: [
          entry(Icons.cake_outlined, l10n.birthday, l10n.birthdaySubtitle,
              () => const BirthdayScreen()),
          entry(Icons.sports_soccer, l10n.goal, l10n.goalSubtitle,
              () => const GoalScreen()),
          entry(Icons.casino_outlined, l10n.boardGame, l10n.boardGameSubtitle,
              () => const BoardGameScreen()),
          entry(Icons.visibility_off_outlined, l10n.hideSeek,
              l10n.hideSeekSubtitle, () => const HideAndSeekScreen()),
          entry(Icons.hourglass_bottom, l10n.countdowns,
              l10n.countdownsSubtitle, () => const CountdownsScreen()),
          entry(Icons.calendar_month_outlined, l10n.advent, l10n.adventSubtitle,
              () => const AdventScreen()),
          entry(Icons.nightlife, l10n.haunted, l10n.hauntedSubtitle,
              () => const HauntedPartyScreen()),
          entry(
              Icons.celebration_outlined,
              l10n.christmasShow,
              l10n.christmasShowSubtitle,
              () => const MusicBoxScreen(festive: true)),
          for (final game in LightGame.values)
            entry(
              GameScreen.iconOf(game),
              GameScreen.titleOf(l10n, game),
              switch (game) {
                LightGame.redLightGreenLight => l10n.gameRedLightSubtitle,
                LightGame.statues => l10n.gameStatuesSubtitle,
                LightGame.colourHunt => l10n.gameColourHuntSubtitle,
              },
              () => GameScreen(game: game),
            ),
          entry(Icons.piano_outlined, l10n.piano, l10n.pianoSubtitle,
              () => const LightPianoScreen()),
          entry(Icons.thermostat, l10n.hotCold, l10n.hotColdSubtitle,
              () => const HotColdScreen()),
          entry(Icons.mic_external_on_outlined, l10n.sing, l10n.singSubtitle,
              () => const SingColourScreen()),
          entry(Icons.traffic_outlined, l10n.noiseLight,
              l10n.noiseLightSubtitle, () => const NoiseLightScreen()),
          entry(Icons.psychology_outlined, l10n.gameSimon,
              l10n.gameSimonSubtitle, () => const SimonScreen()),
          entry(Icons.filter_9_plus_outlined, l10n.countLights,
              l10n.countLightsSubtitle, () => const CountingScreen()),
          entry(Icons.translate, l10n.colourWords, l10n.colourWordsSubtitle,
              () => const ColourWordsScreen()),
          entry(Icons.pets, l10n.farm, l10n.farmSubtitle,
              () => const FarmScreen()),
          entry(Icons.palette_outlined, l10n.colourMixing,
              l10n.colourMixingSubtitle, () => const ColourMixingScreen()),
          entry(Icons.more_horiz, l10n.morse, l10n.morseSubtitle,
              () => const MorseScreen()),
        ],
      ),
    );
  }
}
