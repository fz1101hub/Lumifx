import 'package:flutter/widgets.dart';

import 'core/audio/audio_input.dart';
import 'core/background_playback.dart';
import 'core/hue/hue_discovery.dart';
import 'features/bridge/bridge_controller.dart';
import 'features/effects/playback_controller.dart';
import 'features/library/effect_library.dart';
import 'features/library/preferences_controller.dart';

/// App-wide services, provided at the root of the widget tree.
class AppScope extends InheritedWidget {
  const AppScope({
    required this.bridge,
    required this.discovery,
    required this.preferences,
    required this.audioInput,
    required this.playback,
    required this.library,
    this.background = const NoBackgroundPlayback(),
    this.phoneAudioInput,
    required super.child,
    super.key,
  });

  final BridgeController bridge;
  final BridgeDiscovery discovery;
  final PreferencesController preferences;

  /// Microphone for Music Sync.
  final AudioInput audioInput;

  /// The phone's own audio for Music Sync; null where the platform cannot
  /// capture it.
  final AudioInput? phoneAudioInput;

  /// What plays on the lights, for the whole app: it keeps playing while
  /// the user moves between screens.
  final PlaybackController playback;

  /// Built-in effects and the user's own scenes.
  final EffectLibrary library;

  /// Playing on with the screen off (Android).
  final BackgroundPlayback background;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'No AppScope found in context');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      bridge != oldWidget.bridge ||
      discovery != oldWidget.discovery ||
      preferences != oldWidget.preferences ||
      audioInput != oldWidget.audioInput ||
      playback != oldWidget.playback ||
      library != oldWidget.library ||
      background != oldWidget.background ||
      phoneAudioInput != oldWidget.phoneAudioInput;
}
