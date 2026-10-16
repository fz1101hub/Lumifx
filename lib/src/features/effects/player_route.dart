import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/effects/effect.dart';
import 'effect_player_screen.dart';

/// The route name of an effect's player, so the mini-player can tell
/// whether the player of the effect that plays is already on screen.
String playerRouteName(String effectId) => '$_playerPrefix$effectId';

const _playerPrefix = '/player/';

/// The effect id of a player route's name, or null for other routes.
String? playerEffectId(String? routeName) =>
    routeName != null && routeName.startsWith(_playerPrefix)
        ? routeName.substring(_playerPrefix.length)
        : null;

/// Opens the player of [effect].
Route<void> playerRoute(LightingEffect effect) => MaterialPageRoute<void>(
      settings: RouteSettings(name: playerRouteName(effect.id)),
      builder: (_) => EffectPlayerScreen(effect: effect),
    );

Future<void> openPlayer(BuildContext context, LightingEffect effect) =>
    Navigator.of(context).push(playerRoute(effect));

/// Remembers the name of the route on top of the app's navigator.
class RouteTracker extends NavigatorObserver with ChangeNotifier {
  String? _top;

  String? get topRouteName => _top;

  void _set(Route<dynamic>? route) {
    // Dialogs and sheets sit on top of a page without replacing it.
    if (route != null && route is! PageRoute) {
      return;
    }
    final name = route?.settings.name;
    if (name == _top) {
      return;
    }
    _top = name;
    // The navigator reports its first page while the app is being built,
    // when listeners cannot rebuild yet: tell them after the frame.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => _notify());
    } else {
      _notify();
    }
  }

  bool _disposed = false;

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _set(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute) {
      _set(previousRoute);
    }
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute && route.settings.name == _top) {
      _set(previousRoute);
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _set(newRoute);
}
