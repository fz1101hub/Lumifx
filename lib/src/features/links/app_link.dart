/// A `lumifx://` link, for Siri Shortcuts, Android automations (Tasker,
/// Routines), NFC tags or a bookmark:
///
///   lumifx://app/play/ocean                    open Ocean's player and play
///   lumifx://app/play/ocean?room=Living%20room play it in that room or zone
///   lumifx://app/play/ocean?area=TV%20area     stream it to that area
///   lumifx://app/open/ocean                    open the player only
///   lumifx://app/playlist/Evening              play a playlist (name or id)
///   lumifx://app/stop                          stop and put the lights back
///   lumifx://app/bedtime                       start bedtime as last set
///   lumifx://app/goal                          celebrate a goal in the
///                                              team's colours (a team
///                                              name may follow)
///   lumifx://app/voice/camino                  what someone said: an
///                                              effect, playlist, "stop"
///                                              or "bedtime", any language
///   lumifx://app/import?d=…                    add shared scenes/playlists
///   lumifx://app/go/ritual                     open a screen (see
///                                              [AppScreen]): the bedtime
///                                              ritual, the routines…
///
/// The host is ignored (Android hands the app only the path), and names
/// are matched without regard to case.
sealed class AppLink {
  const AppLink();

  static const scheme = 'lumifx';

  /// The link [location] stands for, or null when it is not one. Accepts a
  /// full URL or just the path and query, as the platforms report it.
  static AppLink? parse(String location) {
    final uri = Uri.tryParse(location);
    if (uri == null || (uri.hasScheme && uri.scheme != scheme)) {
      return null;
    }
    final segments = [
      for (final s in uri.pathSegments)
        if (s.isNotEmpty) s,
    ];
    if (segments.isEmpty) {
      return null;
    }
    final query = uri.queryParameters;
    String? param(String name) {
      final value = query[name]?.trim();
      return value == null || value.isEmpty ? null : value;
    }

    switch (segments) {
      case ['play' || 'open', final id]:
        return EffectLink(
          effectId: id,
          start: segments.first == 'play',
          room: param('room'),
          area: param('area'),
        );
      case ['playlist', final name]:
        return PlaylistLink(name);
      case ['stop']:
        return const StopLink();
      case ['bedtime']:
        return const BedtimeLink();
      case ['goal']:
        return const GoalLink();
      case ['goal', final team]:
        return GoalLink(team.toLowerCase());
      case ['voice', final words] when words.trim().isNotEmpty:
        return VoiceLink(words.trim());
      case ['go', final name]:
        final screen = AppScreen.values
            .where((s) => s.slug == name.toLowerCase())
            .firstOrNull;
        return screen == null ? null : ScreenLink(screen);
      case ['import']:
        final data = param('d');
        return data == null ? null : ImportLink(data);
    }
    return null;
  }

  /// The link that plays [effectId], for the "copy link" buttons.
  static String play(String effectId, {String? room}) => Uri(
        scheme: scheme,
        host: 'app',
        path: '/play/$effectId',
        queryParameters: room == null ? null : {'room': room},
      ).toString();

  static String playlist(String name) =>
      Uri(scheme: scheme, host: 'app', path: '/playlist/$name').toString();

  static String get stop => '$scheme://app/stop';

  static String get bedtime => '$scheme://app/bedtime';

  static String get goal => '$scheme://app/goal';

  static String import(String data) => '$scheme://app/import?d=$data';

  /// The link that opens [screen].
  static String go(AppScreen screen) => '$scheme://app/go/${screen.slug}';
}

/// The screens a link can open.
enum AppScreen {
  ritual('ritual'),
  routines('routines'),
  starShop('star-shop'),
  storyMaker('story-maker'),
  lullabies('lullabies'),
  monsterSpray('monster-spray'),
  piano('piano'),
  games('games'),
  cinema('cinema'),
  timers('timers'),
  breathing('breathing'),
  simon('simon'),
  counting('counting'),
  colourWords('colour-words'),
  colourMixing('colour-mixing'),
  morse('morse'),
  hotCold('hot-and-cold'),
  halloween('halloween'),
  nap('nap'),
  noise('noise'),
  lightClock('light-clock'),
  feelings('feelings'),
  moon('moon'),
  intervals('intervals'),
  goal('goal-party'),
  toothFairy('tooth-fairy'),
  boardGame('board-game'),
  hideSeek('hide-and-seek');

  const AppScreen(this.slug);

  /// Its name in links.
  final String slug;
}

/// Opens one of the app's screens.
class ScreenLink extends AppLink {
  const ScreenLink(this.screen);

  final AppScreen screen;
}

/// Opens an effect's player, and plays it when [start].
class EffectLink extends AppLink {
  const EffectLink({
    required this.effectId,
    this.start = true,
    this.room,
    this.area,
  });

  final String effectId;
  final bool start;

  /// Name of the room or zone to play on.
  final String? room;

  /// Name of the entertainment area to stream to.
  final String? area;
}

class PlaylistLink extends AppLink {
  const PlaylistLink(this.nameOrId);

  final String nameOrId;
}

class StopLink extends AppLink {
  const StopLink();
}

/// Bedtime with the story and times last chosen.
class BedtimeLink extends AppLink {
  const BedtimeLink();
}

/// Words a voice assistant heard, to be matched to something to play.
class VoiceLink extends AppLink {
  const VoiceLink(this.words);

  final String words;
}

/// Scenes and playlists someone shared (see `SharedBundle`).
class ImportLink extends AppLink {
  const ImportLink(this.data);

  final String data;
}

/// Celebrates a goal: the team named, else the one chosen last.
class GoalLink extends AppLink {
  const GoalLink([this.team]);

  final String? team;
}
