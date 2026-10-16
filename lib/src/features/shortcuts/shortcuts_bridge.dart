import 'package:flutter/material.dart';

import '../common/app_text.dart';
import '../effects/player_route.dart';
import '../library/effect_library.dart';
import '../library/preferences_controller.dart';
import 'app_shortcuts.dart';

/// Keeps the home-screen shortcuts in sync with the user's favourites (or,
/// without any, the recently played effects) and opens the player when
/// one is tapped. Lives inside the MaterialApp so the titles follow the
/// app's language.
class ShortcutsBridge extends StatefulWidget {
  const ShortcutsBridge({
    required this.shortcuts,
    required this.preferences,
    required this.library,
    required this.navigatorKey,
    required this.child,
    super.key,
  });

  final AppShortcuts shortcuts;
  final PreferencesController preferences;
  final EffectLibrary library;
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  /// At most this many shortcuts; both platforms show about four.
  static const maxShortcuts = 4;
  static const _prefix = 'effect:';

  @override
  State<ShortcutsBridge> createState() => _ShortcutsBridgeState();
}

class _ShortcutsBridgeState extends State<ShortcutsBridge> {
  List<String> _published = const [];
  String? _pendingLaunch;

  @override
  void initState() {
    super.initState();
    widget.preferences.addListener(_publish);
    widget.shortcuts.initialize(_onLaunch);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Also runs when the locale changes: titles are republished.
    _published = const [];
    _publish();
  }

  @override
  void dispose() {
    widget.preferences.removeListener(_publish);
    super.dispose();
  }

  void _publish() {
    if (!mounted) {
      return;
    }
    final preferences = widget.preferences;
    final ids = (preferences.favorites.isNotEmpty
            ? preferences.favorites
            : preferences.recents)
        .where((id) => widget.library.byId(id) != null)
        .take(ShortcutsBridge.maxShortcuts)
        .toList();
    final l10n = context.l10n;
    final specs = [
      for (final id in ids)
        ShortcutSpec(
          id: '${ShortcutsBridge._prefix}$id',
          title: l10n.effectName(widget.library.byId(id)!),
        ),
    ];
    final key = [for (final s in specs) '${s.id}=${s.title}'];
    if (key.toString() == _published.toString()) {
      return;
    }
    _published = key;
    widget.shortcuts.setShortcuts(specs);
  }

  void _onLaunch(String id) {
    if (!id.startsWith(ShortcutsBridge._prefix)) {
      return;
    }
    final effect =
        widget.library.byId(id.substring(ShortcutsBridge._prefix.length));
    if (effect == null) {
      return;
    }
    final navigator = widget.navigatorKey.currentState;
    if (navigator == null) {
      // Launched from the shortcut: the navigator is not built yet.
      _pendingLaunch = id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final pending = _pendingLaunch;
        _pendingLaunch = null;
        if (pending != null) {
          _onLaunch(pending);
        }
      });
      return;
    }
    navigator.push(playerRoute(effect));
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
