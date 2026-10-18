import 'package:flutter/material.dart';

import '../../core/effects/effect.dart';
import '../../core/sound/melody.dart';
import '../../core/sound/soundscape.dart';
import '../bedtime/monster_spray.dart';
import '../bedtime/monster_spray_screen.dart';
import '../calm/breathing.dart';
import '../calm/breathing_screen.dart';
import '../cinema/cinema.dart';
import '../cinema/cinema_screen.dart';
import '../fun/advent.dart';
import '../fun/advent_screen.dart';
import '../fun/birthday.dart';
import '../fun/birthday_screen.dart';
import '../fun/countdown.dart';
import '../fun/countdowns_screen.dart';
import '../fun/game_screen.dart';
import '../fun/haunted_party.dart';
import '../fun/haunted_party_screen.dart';
import '../fun/hot_cold.dart';
import '../fun/hot_cold_screen.dart';
import '../fun/light_games.dart';
import '../fun/simon_screen.dart';
import '../learn/colour_mixing.dart';
import '../learn/colour_mixing_screen.dart';
import '../learn/colour_words.dart';
import '../learn/colour_words_screen.dart';
import '../learn/counting.dart';
import '../learn/counting_screen.dart';
import '../learn/morse.dart';
import '../learn/morse_screen.dart';
import '../music_box/light_piano.dart';
import '../music_box/light_piano_screen.dart';
import '../music_box/music_box_screen.dart';
import '../paths/path_story.dart';
import '../paths/path_story_screen.dart';
import '../routines/kid_routine.dart';
import '../routines/routines_screen.dart';
import '../routines/star_shop.dart';
import '../routines/star_shop_screen.dart';
import '../tales/tale.dart';
import '../tales/tale_maker_screen.dart';
import '../timers/light_timer.dart';
import '../timers/pomodoro.dart';
import '../timers/pomodoro_screen.dart';
import '../timers/timers_screen.dart';
import '../weather/weather_screen.dart';
import 'player_route.dart';

/// Where the mini-player leads for [effect]: an effect made for one use
/// (a timer, a game, a party…) opens its own screen, everything else the
/// player.
Route<void> routeForPlaying(LightingEffect effect) {
  if (!effect.isGenerated) {
    return playerRoute(effect);
  }
  final id = effect.id;
  Widget? screen;
  if (id.startsWith('${LightingEffect.generatedPrefix}timer:')) {
    screen = TimerRunningScreen(
      effect: effect,
      length: effect.cycleLength - LightTimer.ending,
    );
  } else if (Pomodoro.of(effect) case final pomodoro?) {
    screen = PomodoroRunningScreen(pomodoro: pomodoro, effect: effect);
  } else if (GamePlan.of(effect) case final plan?) {
    screen = GameScreen(game: plan.game, playing: effect);
  } else if (BreathingPattern.of(effect) != null) {
    screen = BreathingScreen(playing: effect);
  } else if (Birthday.of(effect) != null) {
    screen = BirthdayScreen(playing: effect);
  } else if (PathStory.of(effect) case (final story, _)) {
    screen = PathStoryScreen(story: story, playing: effect);
  } else if (Tale.of(effect) != null) {
    screen = TaleMakerScreen(playing: effect);
  } else if (Advent.dayOf(effect) != null) {
    screen = const AdventScreen();
  } else if (Countdown.sleepsOf(effect) != null) {
    screen = const CountdownsScreen();
  } else if (soundscapeOf(effect).melody case final melody?) {
    screen = MusicBoxScreen(festive: melody.instrument == Instrument.bells);
  } else if (MonsterHunt.isHunting(effect) || MonsterHunt.isGuardian(effect)) {
    screen = MonsterSprayScreen(playing: effect);
  } else if (Cinema.phaseOf(effect) != null) {
    screen = const CinemaScreen();
  } else if (isPianoEffect(effect)) {
    screen = const LightPianoScreen();
  } else if (HauntedParty.isParty(effect)) {
    screen = const HauntedPartyScreen();
  } else if (HotCold.isHotCold(effect)) {
    screen = const HotColdScreen();
  } else if (CountingGame.isCounting(effect)) {
    screen = const CountingScreen();
  } else if (MorseMessage.of(effect) != null) {
    screen = MorseScreen(playing: effect);
  } else if (ColourMix.of(effect) != null) {
    screen = ColourMixingScreen(playing: effect);
  } else if (LearnColour.of(effect) != null) {
    screen = ColourWordsScreen(playing: effect);
  } else if (isRewardParty(effect)) {
    screen = const StarShopScreen();
  } else if (KidRoutine.of(effect) != null) {
    screen = const RoutinesScreen();
  } else if (id.startsWith('${LightingEffect.generatedPrefix}simon')) {
    screen = const SimonScreen();
  } else if (id.startsWith('${LightingEffect.generatedPrefix}weather:')) {
    screen = const WeatherScreen();
  }
  if (screen == null) {
    return playerRoute(effect);
  }
  final page = screen;
  return MaterialPageRoute<void>(builder: (_) => page);
}
