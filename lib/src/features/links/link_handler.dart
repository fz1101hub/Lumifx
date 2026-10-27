import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/effects/effect.dart';
import '../bridge/bridge_controller.dart';
import '../effects/effect_player_screen.dart';
import '../family/family_sync_screen.dart';
import '../fun/goal.dart';
import '../fun/goal_screen.dart';
import '../fun/treasure_hunt.dart';
import '../music_box/my_tune.dart';
import '../effects/playback_controller.dart';
import '../effects/player_route.dart';
import '../kids/kids_mode.dart';
import '../library/effect_library.dart';
import '../library/preferences_controller.dart';
import '../library/sharing.dart';
import '../common/app_text.dart';
import '../search/effect_search.dart';
import 'app_link.dart';
import 'screen_links.dart';

/// Carries out [AppLink]s.
class LinkHandler {
  LinkHandler({
    required this.playback,
    required this.library,
    required this.preferences,
    required this.bridge,
    required this.navigatorKey,
    this.bridgeWait = const Duration(seconds: 10),
  });

  final PlaybackController playback;
  final EffectLibrary library;
  final PreferencesController preferences;
  final BridgeController bridge;
  final GlobalKey<NavigatorState> navigatorKey;

  /// How long a link waits for the bridge on a cold start.
  final Duration bridgeWait;

  /// Handles [link]; false when it names nothing that exists.
  Future<bool> handle(AppLink link) async {
    switch (link) {
      case StopLink():
        await playback.stop();
        return true;
      case EffectLink():
        return _effect(link);
      case PlaylistLink(:final nameOrId):
        return _playlist(nameOrId);
      case BedtimeLink():
        return _bedtime();
      case GoalLink(:final team):
        return _goal(team);
      case SyncLink(:final host, :final port, :final code):
        return _sync(host, port, code);
      case TuneLink(:final name, :final data):
        return _tune(name, data);
      case VoiceLink(:final words):
        return _voice(words);
      case ScreenLink(:final screen):
        return _screen(screen);
      case ImportLink(:final data):
        await _ready();
        if (preferences.kidsLocked) {
          return false;
        }
        final bundle = SharedBundle.decode(data);
        final context = navigatorKey.currentContext;
        if (bundle == null || context == null || !context.mounted) {
          return false;
        }
        return importBundle(context, bundle);
    }
  }

  Future<bool> _effect(EffectLink link) async {
    await _ready();
    final effect = library.byId(link.effectId) ??
        // A name works too, e.g. "Ocean" (built-in names are English).
        [
          for (final kind in EffectKind.values) ...library.ofKind(kind),
        ].where((e) => _same(e.name, link.effectId)).firstOrNull;
    if (effect == null || !kidsModeAllows(preferences, library, effect)) {
      return false;
    }
    if (link.room != null || link.area != null) {
      final key = _target(room: link.room, area: link.area);
      if (key != null) {
        await playback.changeTarget(key);
      }
    }
    _showPlayer(effect.id, () => playerRoute(effect));
    // A first flashing effect waits for the user to see the warning.
    final mayStart = !effect.hasRapidFlashes || preferences.flashWarningShown;
    if (link.start && mayStart) {
      await playback.switchEffect(effect);
      if (playback.status == PlaybackStatus.idle) {
        await playback.start();
      } else if (playback.status == PlaybackStatus.paused) {
        await playback.resume();
      }
    }
    return true;
  }

  Future<bool> _playlist(String nameOrId) async {
    await _ready();
    // A playlist may hold anything: not in kids mode.
    if (preferences.kidsLocked) {
      return false;
    }
    final playlist = preferences.playlists
        .where((p) => p.id == nameOrId || _same(p.name, nameOrId))
        .firstOrNull;
    if (playlist == null) {
      return false;
    }
    final effects = [
      for (final id in playlist.effectIds)
        if (library.byId(id) case final effect?) effect,
    ];
    if (effects.isEmpty) {
      return false;
    }
    if (effects.any((e) => e.hasRapidFlashes) &&
        !preferences.flashWarningShown) {
      // Warned here, for the whole playlist, before any of it plays: the
      // player of its first effect would only warn for that one.
      final context = navigatorKey.currentContext;
      if (context == null ||
          !context.mounted ||
          !await confirmFlashingLights(context)) {
        return false;
      }
    }
    await playback.playPlaylist(playlist);
    _showPlayer(playback.effect.id, () => playerRoute(playback.effect));
    return true;
  }

  /// Adds a shared tune and opens the piano, unless in kids mode.
  Future<bool> _tune(String name, String data) async {
    await _ready();
    final tune = MyTune.decode(name, data);
    if (tune == null || preferences.kidsLocked) {
      return false;
    }
    await preferences.saveTune(tune);
    final context = navigatorKey.currentContext;
    if (context != null && context.mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text(context.l10n.tuneAdded(tune.name))));
    }
    await _screen(AppScreen.piano);
    return true;
  }

  /// Another family phone's sync code: asks, then syncs both ways.
  Future<bool> _sync(String host, int port, String code) async {
    await _ready();
    if (preferences.kidsLocked) {
      return false;
    }
    final context = navigatorKey.currentContext;
    if (context == null || !context.mounted) {
      return false;
    }
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.familySyncQuestion),
        content: Text('$host:$port'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.familySyncJoin),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return false;
    }
    return joinFamily(context, host, port, code);
  }

  Future<bool> _goal(String? team) async {
    await _ready();
    // A party: not in kids mode.
    if (preferences.kidsLocked) {
      return false;
    }
    final known = GoalTeam.values.asNameMap()[team]?.name;
    if (known != null) {
      await preferences.setGoalTeam(known);
    }
    final context = navigatorKey.currentContext;
    final name =
        context != null && context.mounted ? context.l10n.goal : 'Goal!';
    await GoalScreen.celebrate(playback, name, preferences.goalTeam);
    return true;
  }

  Future<bool> _bedtime() async {
    await _ready();
    final story = library.byId(preferences.bedtimeStory);
    if (story == null ||
        story.hasRapidFlashes ||
        !kidsModeAllowsBedtime(preferences, library, story)) {
      return false;
    }
    await playback.startBedtime(
      story,
      storyFor: Duration(minutes: preferences.bedtimeStoryMinutes),
      glowFor: Duration(minutes: preferences.bedtimeGlowMinutes),
      brightness: preferences.bedtimeBrightness,
    );
    _showPlayer(story.id, () => playerRoute(story));
    return playback.inBedtime;
  }

  /// What a voice assistant heard ("camino", "stop", "nanna"...): an
  /// effect or playlist by its name in any of the app's languages, or
  /// stop or bedtime.
  Future<bool> _voice(String words) async {
    await _ready();
    final said = foldForSearch(words).trim();
    final languages = [
      for (final locale in AppLocalizations.supportedLocales)
        lookupAppLocalizations(locale),
    ];
    final stops = {
      for (final l10n in languages) foldForSearch(l10n.stop),
      ..._stopWords,
    };
    final bedtimes = {
      for (final l10n in languages) foldForSearch(l10n.bedtime),
      ..._bedtimeWords,
    };
    if (stops.contains(said)) {
      await playback.stop();
      return true;
    }
    if (bedtimes.contains(said)) {
      return _bedtime();
    }
    final names = <(String, LightingEffect)>[
      for (final kind in EffectKind.values)
        for (final effect in library.ofKind(kind)) ...[
          (foldForSearch(effect.id.replaceAll('_', ' ')), effect),
          (foldForSearch(effect.name), effect),
          for (final l10n in languages)
            (foldForSearch(l10n.effectName(effect)), effect),
        ],
    ];
    final effect = names.where((n) => n.$1 == said).firstOrNull?.$2 ??
        names
            .where((n) => n.$1.length > 3 && said.contains(n.$1))
            .firstOrNull
            ?.$2;
    if (effect != null) {
      return _effect(EffectLink(effectId: effect.id));
    }
    final playlist = preferences.playlists
            .where((p) => foldForSearch(p.name) == said)
            .firstOrNull ??
        preferences.playlists
            .where((p) =>
                p.name.length > 3 && said.contains(foldForSearch(p.name)))
            .firstOrNull;
    if (playlist != null) {
      return _playlist(playlist.id);
    }
    return false;
  }

  /// Besides each language's own word for stop and bedtime.
  static const _stopWords = {
    'stop', 'ferma', 'basta', 'spegni', 'stopp', 'halt', 'arrete', //
    'arreter', 'detener', 'parar', 'ストップ', '止めて', '停止',
  };
  static const _bedtimeWords = {
    'bedtime', 'nanna', 'la nanna', 'schlafenszeit', 'dodo', //
    'hora de dormir', 'bedtijd', 'おやすみ',
  };

  /// Opens [screen] unless it is on top already; not in kids mode.
  Future<bool> _screen(AppScreen screen) async {
    await _ready();
    final navigator = navigatorKey.currentState;
    if (navigator == null || preferences.kidsLocked) {
      return false;
    }
    var onTop = false;
    navigator.popUntil((r) {
      onTop = r.settings.name == screenRouteName(screen);
      return true;
    });
    if (onTop && screen == AppScreen.treasureHunt) {
      // A treasure hunt sticker tapped during the hunt: found.
      TreasureHunt.stickerTapped();
    } else if (!onTop) {
      unawaited(navigator.push(MaterialPageRoute<void>(
        settings: RouteSettings(name: screenRouteName(screen)),
        builder: (_) => screenOf(screen),
      )));
    }
    return true;
  }

  /// Opens the player unless it is already on top.
  void _showPlayer(String effectId, Route<void> Function() route) {
    final navigator = navigatorKey.currentState;
    // In kids mode the effect plays, but the screen stays where it is.
    if (navigator == null || preferences.kidsLocked) {
      return;
    }
    var onTop = false;
    navigator.popUntil((r) {
      onTop = r.settings.name == playerRouteName(effectId);
      return true;
    });
    if (!onTop) {
      unawaited(navigator.push(route()));
    }
  }

  String? _target({String? room, String? area}) {
    if (area != null) {
      final match =
          playback.areas.where((a) => _same(a.name, area)).firstOrNull;
      if (match != null) {
        return 'area:${match.id}';
      }
    }
    if (room != null) {
      final match =
          playback.groups.where((g) => _same(g.name, room)).firstOrNull;
      if (match != null) {
        return 'group:${match.id}';
      }
    }
    return null;
  }

  /// On a cold start (a widget tile, a shortcut) the link arrives while
  /// the preferences are loading and the bridge is still connecting: wait
  /// for both, or the effect would play on the preview instead of the
  /// lights and the user's scenes and playlists would not be found yet.
  Future<void> _ready() async {
    bool ready() =>
        preferences.isLoaded &&
        bridge.status != BridgeStatus.initializing &&
        (bridge.credentials == null || bridge.home != null);
    if (ready()) {
      return;
    }
    final done = Completer<void>();
    void check() {
      if (ready() && !done.isCompleted) {
        done.complete();
      }
    }

    bridge.addListener(check);
    preferences.addListener(check);
    try {
      await done.future.timeout(bridgeWait, onTimeout: () {});
    } finally {
      bridge.removeListener(check);
      preferences.removeListener(check);
    }
  }

  static bool _same(String a, String b) =>
      a.trim().toLowerCase() == b.trim().toLowerCase();
}
