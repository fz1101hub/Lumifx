import 'dart:async';

import 'package:flutter/material.dart';

import 'app_scope.dart';
import 'core/audio/audio_input.dart';
import 'core/hue/hue_discovery.dart';
import 'core/screen_wake.dart';
import 'features/bridge/bridge_controller.dart';
import 'features/common/app_text.dart';
import 'features/effects/catalog/effect_catalog.dart';
import 'features/effects/mini_player.dart';
import 'features/effects/playback_controller.dart';
import 'features/effects/player_route.dart';
import 'features/home/home_screen.dart';
import 'features/library/effect_library.dart';
import 'features/links/app_link.dart';
import 'features/links/link_handler.dart';
import 'features/library/preferences_controller.dart';
import 'features/shortcuts/app_shortcuts.dart';
import 'features/shortcuts/shortcuts_bridge.dart';

class LumiFxApp extends StatefulWidget {
  const LumiFxApp({
    required this.bridge,
    required this.discovery,
    required this.preferences,
    required this.audioInput,
    this.phoneAudioInput,
    this.shortcuts = const NoShortcuts(),
    this.screenWake = const WakelockScreenWake(),
    this.locale,
    super.key,
  });

  final BridgeController bridge;
  final BridgeDiscovery discovery;
  final PreferencesController preferences;
  final AudioInput audioInput;

  /// Music Sync from the phone's own audio, where the platform allows it.
  final AudioInput? phoneAudioInput;

  /// Home-screen shortcuts to the favourite effects.
  final AppShortcuts shortcuts;

  /// Keeps the screen on while an effect plays.
  final ScreenWake screenWake;

  /// Forces a language; null follows the device (tests pass one).
  final Locale? locale;

  @override
  State<LumiFxApp> createState() => _LumiFxAppState();
}

class _LumiFxAppState extends State<LumiFxApp> with WidgetsBindingObserver {
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  final _routes = RouteTracker();
  late final EffectLibrary _library = EffectLibrary(widget.preferences);
  late final PlaybackController _playback;
  late final LinkHandler _links;
  StreamSubscription<PlaybackNotice>? _notices;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _playback = PlaybackController(
      effect: effectCatalog.first,
      bridge: widget.bridge,
      preferences: widget.preferences,
      audioInput: widget.audioInput,
      phoneAudioInput: widget.phoneAudioInput,
      screenWake: widget.screenWake,
      resolveEffect: _library.byId,
    );
    _notices = _playback.notices.listen(_showNotice);
    didChangeAccessibilityFeatures();
    _links = LinkHandler(
      playback: _playback,
      library: _library,
      preferences: widget.preferences,
      bridge: widget.bridge,
      navigatorKey: _navigatorKey,
    );
    // Opened from a link: the platform hands it over as the first route.
    final initial = AppLink.parse(
        WidgetsBinding.instance.platformDispatcher.defaultRouteName);
    if (initial != null) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => unawaited(_links.handle(initial)));
    }
  }

  /// A `lumifx://` link while the app runs.
  @override
  Future<bool> didPushRouteInformation(RouteInformation routeInformation) {
    final link = AppLink.parse(routeInformation.uri.toString());
    if (link == null) {
      return Future.value(false);
    }
    unawaited(_links.handle(link));
    return Future.value(true);
  }

  void _showNotice(PlaybackNotice notice) {
    final context = _navigatorKey.currentContext;
    final messenger = _messengerKey.currentState;
    if (context == null || messenger == null) {
      return;
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(describePlaybackNotice(context.l10n, notice)),
      ));
  }

  @override
  void didChangeAccessibilityFeatures() {
    final features =
        WidgetsBinding.instance.platformDispatcher.accessibilityFeatures;
    _playback.systemReducesMotion =
        features.disableAnimations || features.reduceMotion;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // In the background the app is suspended and cannot keep driving the
    // lights: stop cleanly instead of leaving them frozen mid-effect.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_playback.handleAppPaused());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_notices?.cancel());
    _playback.dispose();
    _routes.dispose();
    super.dispose();
  }

  void _openPlaying() {
    final navigator = _navigatorKey.currentState;
    if (navigator != null) {
      unawaited(navigator.push(playerRoute(_playback.effect)));
    }
  }

  static Route<void> _homeRoute() => MaterialPageRoute<void>(
        settings: const RouteSettings(name: Navigator.defaultRouteName),
        builder: (_) => const HomeScreen(),
      );

  @override
  Widget build(BuildContext context) {
    return AppScope(
      bridge: widget.bridge,
      discovery: widget.discovery,
      preferences: widget.preferences,
      audioInput: widget.audioInput,
      phoneAudioInput: widget.phoneAudioInput,
      playback: _playback,
      library: _library,
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        scaffoldMessengerKey: _messengerKey,
        navigatorObservers: [_routes],
        onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
        debugShowCheckedModeBanner: false,
        locale: widget.locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(
          brightness: Brightness.dark,
          colorSchemeSeed: const Color(0xFF7CFF6B),
          useMaterial3: true,
        ),
        builder: (context, child) => ShortcutsBridge(
          shortcuts: widget.shortcuts,
          preferences: widget.preferences,
          library: _library,
          navigatorKey: _navigatorKey,
          child: PlaybackShell(
            controller: _playback,
            routes: _routes,
            onOpen: _openPlaying,
            child: child ?? const SizedBox.shrink(),
          ),
        ),
        // A link at launch arrives as the initial route: the app still
        // opens on the home, and the link is handled on top of it.
        onGenerateInitialRoutes: (_) => [_homeRoute()],
        onGenerateRoute: (settings) =>
            settings.name == Navigator.defaultRouteName ? _homeRoute() : null,
      ),
    );
  }
}
