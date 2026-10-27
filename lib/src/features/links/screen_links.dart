import 'package:flutter/widgets.dart';

import '../bedtime/monster_spray_screen.dart';
import '../bedtime/moon_screen.dart';
import '../bedtime/nap_light_screen.dart';
import '../timers/interval_training_screen.dart';
import '../timers/light_clock_screen.dart';
import '../bedtime/ritual_screen.dart';
import '../calm/breathing_screen.dart';
import '../calm/feelings_screen.dart';
import '../cinema/cinema_screen.dart';
import '../fun/fun_screen.dart';
import '../fun/haunted_party_screen.dart';
import '../fun/hot_cold_screen.dart';
import '../fun/noise_light_screen.dart';
import '../fun/simon_screen.dart';
import '../learn/colour_mixing_screen.dart';
import '../learn/colour_words_screen.dart';
import '../learn/counting_screen.dart';
import '../learn/morse_screen.dart';
import '../music_box/light_piano_screen.dart';
import '../music_box/music_box_screen.dart';
import '../routines/routines_screen.dart';
import '../routines/star_shop_screen.dart';
import '../tales/tale_maker_screen.dart';
import '../timers/timers_screen.dart';
import 'app_link.dart';

/// The screen a [ScreenLink] opens.
Widget screenOf(AppScreen screen) => switch (screen) {
      AppScreen.ritual => const BedtimeRitualScreen(),
      AppScreen.routines => const RoutinesScreen(),
      AppScreen.starShop => const StarShopScreen(),
      AppScreen.storyMaker => const TaleMakerScreen(),
      AppScreen.lullabies => const MusicBoxScreen(festive: false),
      AppScreen.monsterSpray => const MonsterSprayScreen(),
      AppScreen.piano => const LightPianoScreen(),
      AppScreen.games => const FunScreen(),
      AppScreen.cinema => const CinemaScreen(),
      AppScreen.timers => const TimersScreen(),
      AppScreen.breathing => const BreathingScreen(),
      AppScreen.simon => const SimonScreen(),
      AppScreen.counting => const CountingScreen(),
      AppScreen.colourWords => const ColourWordsScreen(),
      AppScreen.colourMixing => const ColourMixingScreen(),
      AppScreen.morse => const MorseScreen(),
      AppScreen.hotCold => const HotColdScreen(),
      AppScreen.halloween => const HauntedPartyScreen(),
      AppScreen.nap => const NapLightScreen(),
      AppScreen.lightClock => const LightClockScreen(),
      AppScreen.feelings => const FeelingsScreen(),
      AppScreen.moon => const MoonScreen(),
      AppScreen.intervals => const IntervalTrainingScreen(),
      AppScreen.noise => const NoiseLightScreen(),
    };

/// The route name of [screen], to tell when it is on top already.
String screenRouteName(AppScreen screen) => '/go/${screen.slug}';
