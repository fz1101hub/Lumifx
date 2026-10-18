import 'dart:async';

import 'package:flutter/material.dart';

import 'app_scope.dart';
import 'core/audio/audio_input.dart';
import 'core/background_playback.dart';
import 'core/hue/hue_discovery.dart';
import 'core/screen_wake.dart';
import 'core/sound/sound_player.dart';
import 'features/tv/camera_input.dart';
import 'features/buttons/hue_button_listener.dart';
import 'features/effects/read_aloud.dart';
import 'core/photos/photo_picker.dart';
import 'core/nfc/nfc_writer.dart';
import 'core/notification_lights_platform.dart';
import 'core/speech/speaker.dart';
import 'core/speech/voice_recordings.dart';
import 'core/weather/weather.dart';
import 'features/bridge/bridge_controller.dart';
import 'features/common/app_text.dart';
import 'features/effects/catalog/effect_catalog.dart';
import 'features/effects/mini_player.dart';
import 'features/effects/playback_controller.dart';
import 'features/effects/player_route.dart';
import 'features/effects/playing_route.dart';
import 'features/home/home_screen.dart';
import 'features/kids/kids_mode.dart';
import 'features/library/effect_library.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/links/app_link.dart';
import 'features/notifications/notification_lights_sync.dart';
import 'features/links/link_handler.dart';
import 'features/library/preferences_controller.dart';
import 'features/shortcuts/app_shortcuts.dart';
import 'features/shortcuts/home_widgets.dart';
import 'features/shortcuts/shortcuts_bridge.dart';

class LumiFxApp extends StatefulWidget {
  const LumiFxApp({
    required this.bridge,
    required this.discovery,
    required this.preferences,
    required this.audioInput,
    this.phoneAudioInput,
    this.shortcuts = const NoShortcuts(),
    this.widgets = const NoHomeWidgets(),
    this.screenWake = const WakelockScreenWake(),
    this.background = const NoBackgroundPlayback(),
    this.clock = DateTime.now,
    this.sound = const NoSoundPlayer(),
    this.camera = const NoCameraInput(),
    this.speaker = const NoSpeaker(),
    this.photos = const NoPhotoPicker(),
    this.weather = const NoWeatherService(),
    this.voices,
    this.voiceRecorder = const NoVoiceRecorder(),
    this.voicePlayer = const NoVoicePlayer(),
    this.nfc = const NoNfcWriter(),
    this.notificationLights = const NoNotificationLights(),
    this.locale,
    @visibleForTesting this.fontFallback,
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

  /// The home-screen widget of the favourite effects.
  final HomeWidgets widgets;

  /// Keeps the screen on while an effect plays.
  final ScreenWake screenWake;

  /// Keeps effects playing with the screen off (Android).
  final BackgroundPlayback background;

  /// Today, for the seasonal stories on the home.
  final DateTime Function() clock;

  /// Plays the ambient sounds of effects.
  final SoundPlayer sound;

  /// Watches the TV for TV Sync.
  final CameraInput camera;

  /// Reads stories aloud.
  final Speaker speaker;

  /// Photos to make scenes from.
  final PhotoPicker photos;

  /// The weather for the weather lights.
  final WeatherService weather;

  /// Story lines in the user's own voice; none by default.
  final VoiceRecordings? voices;

  /// Writes links on NFC stickers (Android).
  final NfcWriter nfc;

  /// Flashes the lights for chosen apps' notifications (Android).
  final NotificationLightsPlatform notificationLights;
  final VoiceRecorder voiceRecorder;
  final VoicePlayer voicePlayer;

  /// Forces a language; null follows the device (tests pass one).
  final Locale? locale;

  /// Font families to fall back on for scripts Roboto lacks. Phones do
  /// this by themselves; the screenshot test, which has no system fonts,
  /// passes a Japanese font here.
  final List<String>? fontFallback;

  @override
  State<LumiFxApp> createState() => _LumiFxAppState();
}

class _LumiFxAppState extends State<LumiFxApp> with WidgetsBindingObserver {
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  final _routes = RouteTracker();
  late final EffectLibrary _library = EffectLibrary(widget.preferences);
  late final PlaybackController _playback;
  late final VoiceRecordings _voices = widget.voices ?? NoVoiceRecordings();
  late final LinkHandler _links;
  late final HueButtonListener _buttons;
  late final ReadAloud _readAloud;
  late final NotificationLightsSync _notificationLights;
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
      sound: widget.sound,
      camera: widget.camera,
    );
    _notices = _playback.notices.listen(_showNotice);
    unawaited(_voices.load());
    didChangeAccessibilityFeatures();
    widget.background.onStop = () => unawaited(_playback.stop());
    _playback.addListener(_syncBackground);
    widget.preferences.addListener(_syncBackground);
    widget.preferences.addListener(_maybeWelcome);
    widget.preferences.addListener(_maybeKidsMode);
    widget.bridge.addListener(_maybeWelcome);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeWelcome();
      _maybeKidsMode();
    });
    _links = LinkHandler(
      playback: _playback,
      library: _library,
      preferences: widget.preferences,
      bridge: widget.bridge,
      navigatorKey: _navigatorKey,
    );
    _buttons = HueButtonListener(
      bridge: widget.bridge,
      preferences: widget.preferences,
      playback: _playback,
      library: _library,
    )..start();
    _readAloud = ReadAloud(
      playback: _playback,
      preferences: widget.preferences,
      library: _library,
      speaker: widget.speaker,
      voices: _voices,
      voicePlayer: widget.voicePlayer,
      locale: () {
        final context = _navigatorKey.currentContext;
        return context == null
            ? WidgetsBinding.instance.platformDispatcher.locale
            : Localizations.localeOf(context);
      },
    )..start();
    _notificationLights = NotificationLightsSync(
      platform: widget.notificationLights,
      preferences: widget.preferences,
      bridge: widget.bridge,
    );
    // Opened from a link: the platform hands it over as the first route.
    final initial = AppLink.parse(
        WidgetsBinding.instance.platformDispatcher.defaultRouteName);
    if (initial != null) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => unawaited(_links.handle(initial)));
    }
  }

  String? _backgroundShown;

  /// Shows the "playing" notification (which keeps Android from
  /// suspending the app) while an effect plays on real lights, and hides
  /// it otherwise.
  void _syncBackground() {
    final background = widget.background;
    final playback = _playback;
    playback.keepPlayingInBackground =
        background.isSupported && widget.preferences.keepPlayingScreenOff;
    final context = _navigatorKey.currentContext;
    final wanted = playback.keepPlayingInBackground &&
        playback.status == PlaybackStatus.playing &&
        playback.selectedTarget != null &&
        context != null;
    if (!wanted) {
      if (_backgroundShown != null) {
        _backgroundShown = null;
        unawaited(background.hide());
      }
      return;
    }
    final l10n = context.l10n;
    final where = playback.targetName ?? '';
    final playlist = playback.playlist;
    final title = l10n.effectName(playback.effect);
    final text = playlist == null ? where : '${playlist.name} · $where';
    // Asked for up front when a playlist will reach a Music Sync effect:
    // Android refuses to add the microphone later from the background.
    final microphone = (playback.effect.usesMicrophone ||
            playback.playlistEffects.any((e) => e.usesMicrophone)) &&
        playback.musicSource == MusicSource.microphone;
    final key = '$title|$text|$microphone|${l10n.stop}';
    if (key == _backgroundShown) {
      return;
    }
    _backgroundShown = key;
    unawaited(background.show(
      title: title,
      text: text,
      stopLabel: l10n.stop,
      microphone: microphone,
    ));
  }

  bool _welcomed = false;

  /// The welcome pages, once, right after installing: only when nothing
  /// was stored before and no bridge is paired (so updates never show it).
  void _maybeWelcome() {
    final preferences = widget.preferences;
    final bridge = widget.bridge;
    if (_welcomed ||
        !preferences.isLoaded ||
        !preferences.isFirstRun ||
        preferences.onboardingDone ||
        bridge.status == BridgeStatus.initializing ||
        bridge.credentials != null) {
      return;
    }
    final navigator = _navigatorKey.currentState;
    if (navigator == null) {
      return;
    }
    _welcomed = true;
    unawaited(navigator.push(MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => const OnboardingScreen(),
    )));
  }

  bool _kidsReopened = false;

  /// Kids mode was on when LumiFX closed: it opens in it again.
  void _maybeKidsMode() {
    final preferences = widget.preferences;
    if (_kidsReopened || !preferences.isLoaded) {
      return;
    }
    _kidsReopened = true;
    final navigator = _navigatorKey.currentState;
    if (preferences.kidsLocked && navigator != null) {
      unawaited(openKidsMode(navigator));
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
      // Hue buttons keep working while an effect plays on with the screen
      // off; otherwise the app is suspended and the connection with it.
      if (_playback.status != PlaybackStatus.playing ||
          !_playback.keepPlayingInBackground) {
        _buttons.pause();
      }
    } else if (state == AppLifecycleState.resumed) {
      _buttons.resume();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.preferences.removeListener(_maybeWelcome);
    widget.preferences.removeListener(_maybeKidsMode);
    widget.preferences.removeListener(_syncBackground);
    _playback.removeListener(_syncBackground);
    widget.background.onStop = null;
    if (_backgroundShown != null) {
      unawaited(widget.background.hide());
    }
    widget.bridge.removeListener(_maybeWelcome);
    unawaited(_notices?.cancel());
    _buttons.dispose();
    _readAloud.dispose();
    _notificationLights.dispose();
    _playback.dispose();
    _routes.dispose();
    super.dispose();
  }

  void _openPlaying() {
    final navigator = _navigatorKey.currentState;
    if (navigator != null) {
      unawaited(navigator.push(routeForPlaying(_playback.effect)));
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
      background: widget.background,
      clock: widget.clock,
      photos: widget.photos,
      weather: widget.weather,
      voices: _voices,
      voiceRecorder: widget.voiceRecorder,
      voicePlayer: widget.voicePlayer,
      speaker: widget.speaker,
      nfc: widget.nfc,
      notificationLights: widget.notificationLights,
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
          fontFamilyFallback: widget.fontFallback,
        ),
        builder: (context, child) => ShortcutsBridge(
          shortcuts: widget.shortcuts,
          widgets: widget.widgets,
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
