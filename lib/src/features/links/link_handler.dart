import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../core/effects/effect.dart';
import '../bridge/bridge_controller.dart';
import '../effects/playback_controller.dart';
import '../effects/player_route.dart';
import '../library/effect_library.dart';
import '../library/preferences_controller.dart';
import '../library/sharing.dart';
import '../common/app_text.dart';
import '../search/effect_search.dart';
import 'app_link.dart';

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
      case VoiceLink(:final words):
        return _voice(words);
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
    if (effect == null) {
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
      // Shown from the playlist's first effect, whose Play warns first.
      _showPlayer(effects.first.id, () => playerRoute(effects.first));
      return true;
    }
    await playback.playPlaylist(playlist);
    _showPlayer(playback.effect.id, () => playerRoute(playback.effect));
    return true;
  }

  Future<bool> _bedtime() async {
    await _ready();
    final story = library.byId(preferences.bedtimeStory);
    if (story == null || story.hasRapidFlashes) {
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
