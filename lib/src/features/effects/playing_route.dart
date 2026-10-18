import 'package:flutter/material.dart';

import '../../core/effects/effect.dart';
import '../calm/breathing.dart';
import '../calm/breathing_screen.dart';
import '../fun/advent.dart';
import '../fun/advent_screen.dart';
import '../fun/birthday.dart';
import '../fun/birthday_screen.dart';
import '../fun/countdown.dart';
import '../fun/countdowns_screen.dart';
import '../fun/game_screen.dart';
import '../fun/light_games.dart';
import '../fun/simon_screen.dart';
import '../paths/path_story.dart';
import '../paths/path_story_screen.dart';
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
  } else if (Advent.dayOf(effect) != null) {
    screen = const AdventScreen();
  } else if (Countdown.sleepsOf(effect) != null) {
    screen = const CountdownsScreen();
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
