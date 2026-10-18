import 'package:flutter/material.dart';

import '../common/app_text.dart';
import '../common/layout.dart';
import '../learn/colour_words_screen.dart';
import '../learn/counting_screen.dart';
import '../learn/morse_screen.dart';
import 'advent_screen.dart';
import '../music_box/music_box_screen.dart';
import 'birthday_screen.dart';
import 'countdowns_screen.dart';
import 'game_screen.dart';
import 'light_games.dart';
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
          entry(Icons.hourglass_bottom, l10n.countdowns,
              l10n.countdownsSubtitle, () => const CountdownsScreen()),
          entry(Icons.calendar_month_outlined, l10n.advent, l10n.adventSubtitle,
              () => const AdventScreen()),
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
          entry(Icons.psychology_outlined, l10n.gameSimon,
              l10n.gameSimonSubtitle, () => const SimonScreen()),
          entry(Icons.filter_9_plus_outlined, l10n.countLights,
              l10n.countLightsSubtitle, () => const CountingScreen()),
          entry(Icons.translate, l10n.colourWords, l10n.colourWordsSubtitle,
              () => const ColourWordsScreen()),
          entry(Icons.more_horiz, l10n.morse, l10n.morseSubtitle,
              () => const MorseScreen()),
        ],
      ),
    );
  }
}
