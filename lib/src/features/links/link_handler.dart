import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../core/effects/effect.dart';
import '../bridge/bridge_controller.dart';
import '../effects/playback_controller.dart';
import '../effects/player_route.dart';
import '../library/effect_library.dart';
import '../library/preferences_controller.dart';
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
    }
  }

  Future<bool> _effect(EffectLink link) async {
    final effect = library.byId(link.effectId) ??
        // A name works too, e.g. "Ocean" (built-in names are English).
        [
          for (final kind in EffectKind.values) ...library.ofKind(kind),
        ].where((e) => _same(e.name, link.effectId)).firstOrNull;
    if (effect == null) {
      return false;
    }
    if (link.room != null || link.area != null) {
      await _waitForBridge();
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

  /// Opens the player unless it is already on top.
  void _showPlayer(String effectId, Route<void> Function() route) {
    final navigator = navigatorKey.currentState;
    if (navigator == null) {
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

  /// On a cold start the bridge is still connecting when the link arrives.
  Future<void> _waitForBridge() async {
    if (bridge.status != BridgeStatus.initializing &&
        (bridge.credentials == null || bridge.home != null)) {
      return;
    }
    final ready = Completer<void>();
    void check() {
      if (bridge.status != BridgeStatus.initializing &&
          (bridge.credentials == null || bridge.home != null) &&
          !ready.isCompleted) {
        ready.complete();
      }
    }

    bridge.addListener(check);
    try {
      await ready.future.timeout(bridgeWait, onTimeout: () {});
    } finally {
      bridge.removeListener(check);
    }
  }

  static bool _same(String a, String b) =>
      a.trim().toLowerCase() == b.trim().toLowerCase();
}
