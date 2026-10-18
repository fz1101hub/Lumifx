import 'package:flutter/widgets.dart';

import '../bedtime/monster_spray_screen.dart';
import '../bedtime/ritual_screen.dart';
import '../cinema/cinema_screen.dart';
import '../fun/fun_screen.dart';
import '../music_box/light_piano_screen.dart';
import '../music_box/music_box_screen.dart';
import '../routines/routines_screen.dart';
import '../routines/star_shop_screen.dart';
import '../tales/tale_maker_screen.dart';
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
    };

/// The route name of [screen], to tell when it is on top already.
String screenRouteName(AppScreen screen) => '/go/${screen.slug}';
