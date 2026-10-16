import 'dart:async';
import 'dart:math' as math;

import '../../core/hue/hue_bridge_client.dart';
import '../../core/hue/hue_buttons.dart';
import '../bridge/bridge_controller.dart';
import '../effects/playback_controller.dart';
import '../library/effect_library.dart';
import '../library/preferences_controller.dart';

/// Listens to the bridge's event stream while LumiFX runs and a Hue
/// button has an action: a short press plays its effect (pressed again,
/// stops it), stops whatever plays, or starts bedtime.
class HueButtonListener {
  HueButtonListener({
    required this.bridge,
    required this.preferences,
    required this.playback,
    required this.library,
    Stream<HueButtonEvent> Function(HueBridgeClient client)? events,
    this.retry = const Duration(seconds: 5),
  }) : _events = events ?? ((client) => client.buttonEvents());

  final BridgeController bridge;
  final PreferencesController preferences;
  final PlaybackController playback;
  final EffectLibrary library;
  final Stream<HueButtonEvent> Function(HueBridgeClient client) _events;

  /// The first wait before reconnecting; it grows with each failure.
  final Duration retry;

  StreamSubscription<HueButtonEvent>? _subscription;
  HueBridgeClient? _listeningTo;
  Timer? _retryTimer;
  int _failures = 0;
  bool _paused = false;
  bool _started = false;

  /// Presses are carried out one after the other.
  Future<void> _queue = Future.value();

  /// Whether the event stream is open now.
  bool get isListening => _subscription != null;

  void start() {
    if (_started) {
      return;
    }
    _started = true;
    bridge.addListener(_update);
    preferences.addListener(_update);
    _update();
  }

  /// The app went to the background: the connection would be cut anyway.
  void pause() {
    _paused = true;
    _update();
  }

  void resume() {
    _paused = false;
    _update();
  }

  void dispose() {
    bridge.removeListener(_update);
    preferences.removeListener(_update);
    _close();
  }

  void _update() {
    final client = bridge.client;
    final wanted = _started &&
        !_paused &&
        client != null &&
        bridge.isConnected &&
        preferences.buttonActions.isNotEmpty;
    if (!wanted) {
      _close();
      return;
    }
    if (identical(client, _listeningTo) &&
        (_subscription != null || _retryTimer != null)) {
      return;
    }
    _close();
    _listen(client);
  }

  void _listen(HueBridgeClient client) {
    _listeningTo = client;
    _subscription = _events(client).listen(
      _onEvent,
      onError: (Object _) => _retryLater(client),
      onDone: () => _retryLater(client),
      cancelOnError: true,
    );
  }

  /// The stream ended or failed: reconnect after a while, longer each
  /// time it fails in a row.
  void _retryLater(HueBridgeClient client) {
    _subscription = null;
    if (!identical(client, _listeningTo)) {
      return;
    }
    _failures++;
    _retryTimer?.cancel();
    _retryTimer = Timer(retry * math.min(_failures, 12), () {
      _retryTimer = null;
      if (identical(client, _listeningTo)) {
        _listen(client);
      }
    });
  }

  void _close() {
    _retryTimer?.cancel();
    _retryTimer = null;
    unawaited(_subscription?.cancel());
    _subscription = null;
    _listeningTo = null;
  }

  void _onEvent(HueButtonEvent event) {
    _failures = 0;
    if (!event.isShortPress) {
      return;
    }
    final action = preferences.buttonActions[event.buttonId];
    if (action == null) {
      return;
    }
    _queue = _queue.then((_) => perform(action)).catchError((Object _) {});
  }

  /// Carries out [action] (an effect id, or one of the special actions).
  Future<void> perform(String action) async {
    switch (action) {
      case PreferencesController.buttonStop:
        await playback.stop();
      case PreferencesController.buttonBedtime:
        if (playback.inBedtime) {
          await playback.stop();
          return;
        }
        final story = library.byId(preferences.bedtimeStory);
        if (story == null || story.hasRapidFlashes) {
          return;
        }
        await playback.startBedtime(
          story,
          storyFor: Duration(minutes: preferences.bedtimeStoryMinutes),
          glowFor: Duration(minutes: preferences.bedtimeGlowMinutes),
          brightness: preferences.bedtimeBrightness,
        );
      default:
        final effect = library.byId(action);
        // A flashing effect waits until the warning was seen in the app.
        if (effect == null ||
            (effect.hasRapidFlashes && !preferences.flashWarningShown)) {
          return;
        }
        if (playback.effect.id == effect.id &&
            playback.status == PlaybackStatus.playing) {
          await playback.stop();
          return;
        }
        await playback.switchEffect(effect);
        if (playback.status == PlaybackStatus.idle) {
          await playback.start();
        } else if (playback.status == PlaybackStatus.paused) {
          await playback.resume();
        }
    }
  }
}
