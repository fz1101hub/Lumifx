import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/audio/audio_input.dart';
import '../../core/effects/effect.dart';
import '../../core/effects/engine/effect_player.dart';
import '../../core/effects/engine/effect_renderer.dart';
import '../../core/effects/engine/light_output.dart';
import '../../core/hue/entertainment/dtls/dtls_client.dart';
import '../../core/hue/entertainment/entertainment_session.dart';
import '../../core/hue/hue_bridge_client.dart';
import '../../core/hue/hue_exceptions.dart';
import '../../core/hue/hue_models.dart';
import '../../core/screen_wake.dart';
import '../bridge/bridge_controller.dart';
import '../library/preferences_controller.dart';
import '../music/music_sync_controller.dart';

/// Lamps shown when playing without a bridge.
const previewLightCount = 5;

enum PlaybackStatus { idle, starting, playing, paused }

/// Everything about playing one effect: where it plays, starting and
/// stopping the right output, the microphone for Music Sync, keeping the
/// screen on, and putting the lights back afterwards.
class PlaybackController extends ChangeNotifier {
  PlaybackController({
    required this.effect,
    required BridgeController bridge,
    required PreferencesController preferences,
    required AudioInput audioInput,
    ScreenWake screenWake = const NoScreenWake(),
  })  : _bridge = bridge,
        _preferences = preferences,
        _audioInput = audioInput,
        _screenWake = screenWake,
        _targetKey = preferences.lastTarget,
        _controls = preferences.defaultControls {
    _bridge.addListener(_onBridgeChanged);
  }

  final LightingEffect effect;
  final BridgeController _bridge;
  final PreferencesController _preferences;
  final AudioInput _audioInput;
  final ScreenWake _screenWake;

  final _messages = StreamController<String>.broadcast();
  PlaybackStatus _status = PlaybackStatus.idle;
  EffectPlayer? _player;
  MusicSyncController? _music;
  String? _targetKey;
  EffectControls _controls;
  double _sensitivity = 1;
  List<String>? _slotNames;
  Map<String, HueLightCommand> _restore = const {};
  bool _disposed = false;

  /// Bumped by every stop, so a start that completes afterwards knows it
  /// has been cancelled.
  int _generation = 0;

  /// Things worth telling the user, e.g. why playback could not start.
  Stream<String> get messages => _messages.stream;

  PlaybackStatus get status => _status;
  bool get isPlaying => _status == PlaybackStatus.playing;
  bool get isBusy => _status == PlaybackStatus.starting;
  EffectPlayer? get player => _player;
  MusicSyncController? get music => _music;
  EffectControls get controls => _controls;
  double get sensitivity => _sensitivity;

  /// The latest bridge snapshot, kept while the bridge is temporarily
  /// unreachable so the chosen target does not vanish from the screen.
  HueHome? get home => _bridge.credentials == null ? null : _bridge.home;

  /// Paired, but the last contact with the bridge failed.
  bool get bridgeUnreachable =>
      _bridge.credentials != null && !_bridge.isConnected;

  /// Paired before streaming support: no Entertainment client key.
  bool get streamingUnavailable =>
      _bridge.credentials != null && _bridge.credentials?.clientKey == null;

  /// Rooms and zones that have lights.
  List<HueGroup> get groups =>
      home?.groups.where((g) => g.lightIds.isNotEmpty).toList() ?? const [];

  /// Entertainment areas that have channels; none without a client key,
  /// since streaming to them could only fail.
  List<HueEntertainmentArea> get areas => streamingUnavailable
      ? const []
      : home?.entertainmentAreas.where((a) => a.channels.isNotEmpty).toList() ??
          const [];

  /// The selected room or zone, looked up fresh because the bridge
  /// snapshot is replaced on every refresh.
  HueGroup? get group =>
      groups.where((g) => _targetKey == 'group:${g.id}').firstOrNull;

  HueEntertainmentArea? get area =>
      areas.where((a) => _targetKey == 'area:${a.id}').firstOrNull;

  /// The selected target if it still exists; null means the preview.
  String? get selectedTarget =>
      group != null || area != null ? _targetKey : null;

  /// One label per slot of the lamp preview.
  List<String> get lightNames {
    final playing = _slotNames;
    if (playing != null && _player != null) {
      return playing;
    }
    final home = this.home;
    final group = this.group;
    final area = this.area;
    if (home != null && group != null) {
      return [
        for (final id in _effectLights(home, group.lightIds))
          home.lights[id]?.name ?? id,
      ];
    }
    if (home != null && area != null) {
      return _channelNames(home, area);
    }
    return [for (var i = 1; i <= previewLightCount; i++) 'Lamp $i'];
  }

  Future<void> toggle() async {
    switch (_status) {
      case PlaybackStatus.idle:
        await start();
      case PlaybackStatus.playing:
        await pause();
      case PlaybackStatus.paused:
        await resume();
      case PlaybackStatus.starting:
        break;
    }
  }

  Future<void> start() async {
    if (_status != PlaybackStatus.idle || _disposed) {
      return;
    }
    final generation = ++_generation;
    bool cancelled() => _disposed || generation != _generation;
    _setStatus(PlaybackStatus.starting);

    EntertainmentLightOutput? streaming;
    try {
      if (!await _startListening()) {
        if (!cancelled()) {
          _setStatus(PlaybackStatus.idle);
        }
        return;
      }

      var lightIds = [for (var i = 0; i < previewLightCount; i++) 'p$i'];
      List<String>? names;
      LightOutput output = const NullLightOutput();
      var tick = const Duration(milliseconds: 100);
      var restore = <String, HueLightCommand>{};

      if (selectedTarget != null) {
        // Fresh state, both to find the lights and to restore them later.
        await _bridge.refresh();
        if (cancelled()) {
          return await _cleanUpCancelled(null);
        }
        final home = this.home;
        final client = _bridge.client;
        if (!_bridge.isConnected || home == null || client == null) {
          return _abortStart(
              _bridge.error ?? 'The bridge could not be reached.');
        }
        final area = this.area;
        final group = this.group;
        if (area != null) {
          restore = _snapshot(home, {
            for (final channel in area.channels) ...channel.lightIds,
          });
          streaming = await _bridge.openEntertainment(area);
          if (cancelled()) {
            return await _cleanUpCancelled(streaming);
          }
          output = streaming;
          lightIds = entertainmentSlotIds(area);
          names = _channelNames(home, area);
          // Hue recommends 50-60 messages per second; the bridge forwards
          // them to the lights at 25 Hz.
          tick = const Duration(milliseconds: 20);
          final opened = streaming;
          unawaited(opened.session.done
              .catchError((Object _) {})
              .whenComplete(() => _onStreamEnded(opened)));
        } else if (group != null) {
          final usable = _effectLights(home, group.lightIds);
          if (usable.isEmpty) {
            return _abortStart('The lights in ${group.name} can only switch '
                'on and off, so they cannot play effects.');
          }
          restore = _snapshot(home, usable);
          output = hueRestOutput(client, home.lights);
          lightIds = usable;
          names = [for (final id in usable) home.lights[id]?.name ?? id];
        } else {
          return _abortStart('That room or area is no longer on the bridge.');
        }
      }

      final music = _music;
      _restore = _preferences.restoreLights ? restore : const {};
      _slotNames = names;
      _player = EffectPlayer(
        effect: effect,
        lightIds: lightIds,
        output: output,
        seed: DateTime.now().millisecondsSinceEpoch & 0x7FFFFFFF,
        controls: _controls,
        tick: tick,
        audio: music == null
            ? null
            : () => music.isListening ? music.features : null,
      )..play();
      unawaited(_screenWake.keepOn(true));
      unawaited(_preferences.recordPlayed(effect.id));
      _setStatus(PlaybackStatus.playing);
    } on Object catch (error) {
      if (cancelled()) {
        return _cleanUpCancelled(streaming);
      }
      await streaming?.close();
      return _abortStart('Could not start: ${describeError(error)}');
    }
  }

  Future<void> pause() async {
    final player = _player;
    if (_status != PlaybackStatus.playing || player == null) {
      return;
    }
    player.pause();
    _setStatus(PlaybackStatus.paused);
    // No reason to keep the microphone open or the screen on while paused.
    unawaited(_screenWake.keepOn(false));
    await _music?.stop();
  }

  Future<void> resume() async {
    final player = _player;
    if (_status != PlaybackStatus.paused || player == null) {
      return;
    }
    if (!await _startListening() || _player != player) {
      return;
    }
    player.play();
    unawaited(_screenWake.keepOn(true));
    _setStatus(PlaybackStatus.playing);
  }

  /// Stops playback and, unless [restore] is false, puts the lights back.
  Future<void> stop({bool restore = true}) async {
    _generation++;
    final player = _player;
    final commands = _restore;
    _player = null;
    _slotNames = null;
    _restore = const {};
    _setStatus(PlaybackStatus.idle);
    await player?.stop();
    await _music?.stop();
    unawaited(_screenWake.keepOn(false));
    final client = _bridge.client;
    if (restore && commands.isNotEmpty && client != null) {
      unawaited(restoreLights(client, commands));
    }
  }

  /// The app went to the background: it cannot keep driving the lights, so
  /// stop cleanly instead of leaving them frozen mid-effect.
  Future<void> handleAppPaused() async {
    if (_status != PlaybackStatus.idle) {
      await stop();
    }
  }

  Future<void> changeTarget(String? targetKey) async {
    if (targetKey == _targetKey) {
      return;
    }
    final wasPlaying = _status == PlaybackStatus.playing;
    await stop();
    _targetKey = targetKey;
    unawaited(_preferences.setLastTarget(targetKey));
    _notify();
    if (wasPlaying) {
      await start();
    }
  }

  void setControls(EffectControls controls) {
    _controls = controls;
    _player?.controls = controls;
    _notify();
  }

  void setSensitivity(double value) {
    _sensitivity = value;
    _music?.sensitivity = value;
    _notify();
  }

  /// Starts the microphone for Music Sync effects. Returns false (after
  /// telling the user why) when it cannot listen.
  Future<bool> _startListening() async {
    if (!effect.usesMicrophone) {
      return true;
    }
    final music =
        _music ??= MusicSyncController(_audioInput)..sensitivity = _sensitivity;
    await music.start();
    switch (music.status) {
      case MusicSyncStatus.listening:
        return true;
      case MusicSyncStatus.denied:
        _message('Music Sync needs microphone access. You can allow it in '
            'your phone settings.');
      default:
        _message('The microphone could not be started.');
    }
    return false;
  }

  void _abortStart(String message) {
    unawaited(_music?.stop());
    _setStatus(PlaybackStatus.idle);
    _message(message);
  }

  /// A stop or dispose happened while starting: undo what was set up.
  Future<void> _cleanUpCancelled(EntertainmentLightOutput? streaming) async {
    await streaming?.close();
    if (_status == PlaybackStatus.idle || _disposed) {
      await _music?.stop();
    }
  }

  void _onStreamEnded(LightOutput output) {
    if (_disposed || _player?.output != output) {
      return;
    }
    unawaited(stop());
    _message('Streaming stopped by the bridge (another app may have taken '
        'over the area).');
  }

  void _onBridgeChanged() => _notify();

  void _setStatus(PlaybackStatus status) {
    _status = status;
    _notify();
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  void _message(String message) {
    if (!_disposed) {
      _messages.add(message);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _bridge.removeListener(_onBridgeChanged);
    final music = _music;
    unawaited(stop().whenComplete(() => music?.dispose()));
    unawaited(_messages.close());
    super.dispose();
  }

  /// Lights that can show an effect; on/off-only lights (plugs, relays)
  /// are skipped, since switching them several times a second is useless
  /// and can wear them out.
  static List<String> _effectLights(HueHome home, List<String> lightIds) => [
        for (final id in lightIds)
          if (home.lights[id]?.isDimmable ?? false) id,
      ];

  static List<String> _channelNames(HueHome home, HueEntertainmentArea area) =>
      [
        for (final channel in area.spatialChannels)
          channel.lightIds.isEmpty
              ? 'Channel ${channel.id}'
              : channel.lightIds
                  .map((id) => home.lights[id]?.name ?? id)
                  .join(' / '),
      ];

  static Map<String, HueLightCommand> _snapshot(
    HueHome home,
    Iterable<String> lightIds,
  ) =>
      {
        for (final id in lightIds)
          if (home.lights[id] case final light?) id: light.restoreCommand,
      };
}

/// Sends frames to Hue lights through the REST API, adapting each command
/// to what the light supports.
LightOutput hueRestOutput(
  HueBridgeClient client,
  Map<String, HueLight> lights,
) {
  return RateLimitedLightOutput(
    send: (lightId, frame, transition) {
      final light = lights[lightId];
      return client.setLight(
        lightId,
        light == null
            ? HueLightCommand.fromColor(frame.color, frame.brightness,
                transition: transition)
            : HueLightCommand.forLight(light, frame.color, frame.brightness,
                transition: transition),
      );
    },
  );
}

/// Puts lights back, one command at a time to stay within the bridge's
/// rate limit. Waits briefly first so effect commands still in flight do
/// not land after the restore.
Future<void> restoreLights(
  HueBridgeClient client,
  Map<String, HueLightCommand> commands, {
  Duration settle = const Duration(milliseconds: 350),
  Duration gap = const Duration(milliseconds: 110),
}) async {
  await Future<void>.delayed(settle);
  for (final MapEntry(key: id, value: command) in commands.entries) {
    try {
      await client.setLight(id, command);
    } on Object {
      // Best effort: one unreachable light should not block the others.
    }
    await Future<void>.delayed(gap);
  }
}

String describeError(Object error) => switch (error) {
      HueException(:final message) => message,
      DtlsException(:final message) => message,
      SocketException() ||
      TimeoutException() ||
      http.ClientException() =>
        'the bridge did not respond.',
      _ => 'something went wrong.',
    };
