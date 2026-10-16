import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../core/audio/audio_input.dart';
import '../../core/effects/effect.dart';
import '../../core/effects/engine/effect_player.dart';
import '../../core/effects/engine/effect_renderer.dart';
import '../../core/effects/engine/light_output.dart';
import '../../core/hue/entertainment/entertainment_session.dart';
import '../../core/hue/hue_bridge_client.dart';
import '../../core/hue/hue_models.dart';
import '../../core/screen_wake.dart';
import '../bridge/bridge_controller.dart';
import '../library/preferences_controller.dart';
import '../music/music_sync_controller.dart';
import '../playlists/playlist.dart';

/// Lamps shown when playing without a bridge.
const previewLightCount = 5;

enum PlaybackStatus { idle, starting, playing, paused }

enum PlaybackNoticeKind {
  /// Playing on the bridge was requested while it cannot be reached.
  bridgeUnreachable,

  /// Every light in the chosen room is on/off only; [PlaybackNotice.name]
  /// is the room.
  onOffOnlyLights,

  /// The chosen room or area no longer exists on the bridge.
  targetGone,

  /// Starting failed; [PlaybackNotice.error] says why.
  startFailed,
  microphoneDenied,
  microphoneFailed,

  /// The microphone died mid-effect.
  microphoneStopped,

  /// The same three, for Music Sync from the phone's own audio.
  phoneAudioDenied,
  phoneAudioFailed,
  phoneAudioStopped,

  /// The stream ended on its own; [PlaybackNotice.error] says why, when
  /// known.
  streamEnded,

  /// The sleep timer ran out: the effect faded and the lights are off.
  sleepTimerDone,
}

/// Something worth telling the user; the UI turns it into localised text.
class PlaybackNotice {
  const PlaybackNotice(this.kind, {this.name, this.error, this.problem});

  final PlaybackNoticeKind kind;
  final String? name;
  final Object? error;
  final BridgeProblem? problem;
}

/// One label of the lamp preview; the UI localises the generic ones.
sealed class SlotLabel {
  const SlotLabel();
}

/// A real light (or a gradient segment group) by name.
class NamedSlot extends SlotLabel {
  const NamedSlot(this.name);

  final String name;
}

/// A virtual lamp of the preview, numbered from 1.
class PreviewLamp extends SlotLabel {
  const PreviewLamp(this.number);

  final int number;
}

/// An entertainment channel whose lights are not known by name.
class UnnamedChannel extends SlotLabel {
  const UnnamedChannel(this.id);

  final int id;
}

/// Everything about playing one effect: where it plays, starting and
/// stopping the right output, the microphone for Music Sync, keeping the
/// screen on, and putting the lights back afterwards.
class PlaybackController extends ChangeNotifier {
  PlaybackController({
    required LightingEffect effect,
    required BridgeController bridge,
    required PreferencesController preferences,
    required AudioInput audioInput,
    AudioInput? phoneAudioInput,
    ScreenWake screenWake = const NoScreenWake(),
    this.sleepFade = const Duration(seconds: 20),
    LightingEffect? Function(String id)? resolveEffect,
    math.Random? random,
  })  : _effect = effect,
        _resolveEffect = resolveEffect ?? ((_) => null),
        _random = random ?? math.Random(),
        _bridge = bridge,
        _preferences = preferences,
        _audioInput = audioInput,
        _phoneAudioInput = phoneAudioInput,
        _screenWake = screenWake,
        _targetKey = preferences.lastTarget,
        _controls = preferences.defaultControls,
        _defaults = preferences.defaultControls {
    _bridge.addListener(_onBridgeChanged);
    _preferences.addListener(_onPreferencesChanged);
  }

  LightingEffect _effect;
  final BridgeController _bridge;
  final PreferencesController _preferences;
  final AudioInput _audioInput;
  final AudioInput? _phoneAudioInput;
  final ScreenWake _screenWake;

  /// How long the sleep timer takes to fade the lights to black.
  final Duration sleepFade;

  /// Finds a playlist's effects by id (built-in and the user's own).
  final LightingEffect? Function(String id) _resolveEffect;
  final math.Random _random;

  /// The default controls last applied, to notice when Settings change them.
  EffectControls _defaults;

  /// The user picked a target here, so a late preferences load must not
  /// replace it.
  bool _targetChosen = false;

  Playlist? _playlist;
  int _playlistIndex = 0;
  Timer? _playlistTimer;
  DateTime? _playlistNextAt;
  Duration? _playlistLeft;

  final _notices = StreamController<PlaybackNotice>.broadcast();
  PlaybackStatus _status = PlaybackStatus.idle;
  EffectPlayer? _player;
  MusicSyncController? _music;
  String? _targetKey;
  EffectControls _controls;
  double _sensitivity = 1;
  List<SlotLabel>? _slotNames;
  Map<String, HueLightCommand> _restore = const {};

  /// Lights of the current target, for the sleep timer to switch off.
  List<String> _activeLightIds = const [];
  Duration? _sleepAfter;
  DateTime? _sleepEndsAt;
  Timer? _sleepTimer;
  Timer? _sleepTicker;
  Timer? _fadeTimer;
  bool _fadingOut = false;
  bool _disposed = false;

  /// Bumped by every stop, so a start that completes afterwards knows it
  /// has been cancelled.
  int _generation = 0;

  /// The previous stop or cancellation still releasing its resources; a new
  /// start waits for it, so its `action: stop` cannot kill the new stream.
  Future<void>? _teardown;

  /// Things worth telling the user, e.g. why playback could not start.
  Stream<PlaybackNotice> get notices => _notices.stream;

  /// The effect playing, or the one that plays on the next [start].
  LightingEffect get effect => _effect;

  /// The playlist being played, if any.
  Playlist? get playlist => _playlist;

  /// Whether the player of [effectId] shows what plays now: the effect
  /// itself, or any effect of the playlist that plays (that player follows
  /// the playlist from one effect to the next).
  bool isShownBy(String effectId) =>
      _effect.id == effectId ||
      (_playlist?.effectIds.contains(effectId) ?? false);

  /// Position of [effect] in the playlist's order (0-based).
  int get playlistIndex => _playlistIndex;

  /// The playlist's effects that still exist.
  List<LightingEffect> get playlistEffects => _playlistEffects(_playlist);

  List<LightingEffect> _playlistEffects(Playlist? playlist) => [
        for (final id in playlist?.effectIds ?? const <String>[])
          if (_resolveEffect(id) case final effect?) effect,
      ];

  /// Plays [playlist] from its first effect (or a random one when it
  /// shuffles), starting playback if nothing plays. Nothing happens when
  /// none of its effects exists any more.
  Future<void> playPlaylist(Playlist playlist) async {
    final effects = _playlistEffects(playlist);
    if (effects.isEmpty) {
      return;
    }
    _playlist = playlist;
    _playlistIndex = playlist.shuffle ? _random.nextInt(effects.length) : 0;
    await _switchEffect(effects[_playlistIndex]);
    if (_status == PlaybackStatus.idle) {
      await start();
    } else if (_status == PlaybackStatus.paused) {
      await resume();
    }
    if (_playlist == playlist && _status == PlaybackStatus.playing) {
      _armPlaylistTimer(playlist.each);
    }
    _notify();
  }

  /// Whether [saveAsHueScene] can work now: an effect plays on a room or
  /// zone.
  bool get canSaveAsHueScene =>
      group != null &&
      _player != null &&
      _activeLightIds.isNotEmpty &&
      (_status == PlaybackStatus.playing || _status == PlaybackStatus.paused);

  /// Saves what the lights show right now as a scene named [name] in the
  /// room or zone, then refreshes the bridge so it appears with the other
  /// scenes. Throws when the bridge refuses.
  Future<HueScene?> saveAsHueScene(String name) async {
    final group = this.group;
    final player = _player;
    final home = this.home;
    final client = _bridge.client;
    if (!canSaveAsHueScene ||
        group == null ||
        player == null ||
        home == null ||
        client == null) {
      return null;
    }
    final frames = player.currentFrames;
    final lightIds = player.lightIds;
    final actions = <String, HueLightCommand>{
      for (var i = 0; i < lightIds.length && i < frames.length; i++)
        if (home.lights[lightIds[i]] case final light?)
          light.id: HueLightCommand.forLight(
              light, frames[i].color, frames[i].brightness),
    };
    final id = await client.createScene(
      name: name,
      group: group,
      actions: actions,
    );
    await _bridge.refresh();
    return this.home?.scenes.where((s) => s.id == id).firstOrNull ??
        HueScene(id: id, name: name, groupId: group.id);
  }

  /// Moves the playlist on to its next effect now.
  Future<void> nextInPlaylist() async {
    final playlist = _playlist;
    final effects = _playlistEffects(playlist);
    if (playlist == null || effects.isEmpty) {
      return;
    }
    var next = (_playlistIndex + 1) % effects.length;
    if (playlist.shuffle && effects.length > 1) {
      next = _random.nextInt(effects.length - 1);
      if (next >= _playlistIndex) {
        next++;
      }
    }
    _playlistIndex = next;
    await _switchEffect(effects[next]);
    if (_playlist == playlist && _status == PlaybackStatus.playing) {
      _armPlaylistTimer(playlist.each);
    }
    _notify();
  }

  void _armPlaylistTimer(Duration after) {
    _playlistTimer?.cancel();
    _playlistLeft = null;
    _playlistNextAt = DateTime.now().add(after);
    _playlistTimer = Timer(after, () => unawaited(nextInPlaylist()));
  }

  void _pausePlaylistTimer() {
    final nextAt = _playlistNextAt;
    _playlistTimer?.cancel();
    _playlistTimer = null;
    if (nextAt != null) {
      final left = nextAt.difference(DateTime.now());
      _playlistLeft = left.isNegative ? Duration.zero : left;
    }
    _playlistNextAt = null;
  }

  void _endPlaylist() {
    _playlistTimer?.cancel();
    _playlistTimer = null;
    _playlistNextAt = null;
    _playlistLeft = null;
    _playlist = null;
  }

  PlaybackStatus get status => _status;
  bool get isPlaying => _status == PlaybackStatus.playing;
  bool get isBusy => _status == PlaybackStatus.starting;
  EffectPlayer? get player => _player;
  MusicSyncController? get music => _music;
  EffectControls get controls => _controls;
  double get sensitivity => _sensitivity;

  /// Where Music Sync listens: the preference, unless it asks for the
  /// phone's audio where that cannot be captured.
  MusicSource get musicSource =>
      _preferences.musicSource == MusicSource.phoneAudio &&
              _phoneAudioInput != null
          ? MusicSource.phoneAudio
          : MusicSource.microphone;

  /// The source the current Music Sync controller listens to, if any.
  MusicSource? _musicSourceInUse;

  /// The dimmable lights of the selected room or zone, each with whether
  /// it takes part in the effect.
  List<({HueLight light, bool enabled})> get groupLights {
    final home = this.home;
    final group = this.group;
    if (home == null || group == null) {
      return const [];
    }
    final excluded = _preferences.excludedLights(group.id);
    return [
      for (final id in group.lightIds)
        if (home.lights[id] case final light? when light.isDimmable)
          (light: light, enabled: !excluded.contains(id)),
    ];
  }

  /// Leaves [lightId] out of effects on the selected room or zone, or
  /// brings it back. The last light cannot be left out. A running effect
  /// restarts on the new set of lights.
  Future<void> toggleLight(String lightId) async {
    final group = this.group;
    final lights = groupLights;
    final current = lights.where((l) => l.light.id == lightId).firstOrNull;
    if (group == null || current == null) {
      return;
    }
    if (current.enabled && lights.where((l) => l.enabled).length <= 1) {
      return;
    }
    final wasPlaying = _status == PlaybackStatus.playing;
    final playlist = _playlist;
    if (_status != PlaybackStatus.idle) {
      await stop();
    }
    await _preferences.setLightExcluded(group.id, lightId, current.enabled);
    _notify();
    if (wasPlaying) {
      if (playlist != null) {
        await playPlaylist(playlist);
      } else {
        await start();
      }
    }
  }

  /// The colour variant chosen for this effect, or null for the original.
  String? get variantId => _preferences.variantOf(effect.id);

  /// The effect with the chosen colour variant applied.
  LightingEffect get effectToPlay => effect.withVariant(variantId);

  /// Plays [next] instead of the current effect, leaving any playlist.
  /// When idle it is only selected; while playing or paused the lights
  /// cross-fade to it without being put back in between, and Music Sync
  /// starts or stops as needed.
  Future<void> switchEffect(LightingEffect next) async {
    if (_playlist != null) {
      _endPlaylist();
      _notify();
    }
    await _switchEffect(next);
  }

  Future<void> _switchEffect(
    LightingEffect next, {
    Duration crossfade = const Duration(milliseconds: 1500),
  }) async {
    if (identical(next, _effect)) {
      return;
    }
    _effect = next;
    final player = _player;
    if (player == null || _status == PlaybackStatus.starting) {
      _notify();
      return;
    }
    if (next.usesMicrophone) {
      if (_status == PlaybackStatus.playing && !await _startListening()) {
        await stop();
        return;
      }
    } else {
      await _music?.stop();
    }
    if (!identical(_player, player)) {
      return;
    }
    player.crossfadeTo(effectToPlay, over: crossfade);
    unawaited(_preferences.recordPlayed(next.id));
    _notify();
  }

  /// Picks a colour variant; a running player switches colours in place.
  Future<void> setVariant(String? variantId) async {
    await _preferences.setVariant(effect.id, variantId);
    _player?.effect = effectToPlay;
    _notify();
  }

  /// The sleep timer the user chose, or null for none.
  Duration? get sleepTimer => _sleepAfter;

  /// Time left before the lights go out; null when no timer is running.
  Duration? get sleepRemaining {
    final endsAt = _sleepEndsAt;
    if (endsAt == null) {
      return null;
    }
    final left = endsAt.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  /// The timer ran out and the effect is fading to black.
  bool get isFadingOut => _fadingOut;

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
  List<SlotLabel> get lightNames {
    final playing = _slotNames;
    if (playing != null && _player != null) {
      return playing;
    }
    final home = this.home;
    final group = this.group;
    final area = this.area;
    if (home != null && group != null) {
      return [
        for (final id in _effectLights(home, group))
          NamedSlot(home.lights[id]?.name ?? id),
      ];
    }
    if (home != null && area != null) {
      return _channelNames(home, area);
    }
    return [for (var i = 1; i <= previewLightCount; i++) PreviewLamp(i)];
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
      final teardown = _teardown;
      if (teardown != null) {
        await teardown;
        if (cancelled()) {
          return;
        }
      }
      if (!await _startListening()) {
        if (!cancelled()) {
          _setStatus(PlaybackStatus.idle);
        }
        return;
      }
      if (cancelled()) {
        return await _cleanUpCancelled(null);
      }

      var lightIds = [for (var i = 0; i < previewLightCount; i++) 'p$i'];
      List<SlotLabel>? names;
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
          return _abortStart(PlaybackNotice(
            PlaybackNoticeKind.bridgeUnreachable,
            problem: _bridge.problem,
          ));
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
          unawaited(opened.session.done.then(
            (_) => _onStreamEnded(opened, null),
            onError: (Object error) => _onStreamEnded(opened, error),
          ));
        } else if (group != null) {
          final usable = _effectLights(home, group);
          if (usable.isEmpty) {
            return _abortStart(PlaybackNotice(
              PlaybackNoticeKind.onOffOnlyLights,
              name: group.name,
            ));
          }
          restore = _snapshot(home, usable);
          output = hueRestOutput(client, home.lights);
          lightIds = usable;
          names = [
            for (final id in usable) NamedSlot(home.lights[id]?.name ?? id),
          ];
        } else {
          return _abortStart(
              const PlaybackNotice(PlaybackNoticeKind.targetGone));
        }
      }

      _restore = _preferences.restoreLights ? restore : const {};
      _activeLightIds = selectedTarget == null ? const [] : lightIds;
      _slotNames = names;
      // Assigned before play(): if the first tick throws, stop() can still
      // find and stop the player (and its timer).
      final player = _player = EffectPlayer(
        effect: effectToPlay,
        lightIds: lightIds,
        output: output,
        seed: DateTime.now().millisecondsSinceEpoch & 0x7FFFFFFF,
        controls: _controls,
        tick: tick,
        // Read on every tick, so a later switch to (or from) a Music Sync
        // effect is picked up.
        audio: () {
          final music = _music;
          return _effect.usesMicrophone && music != null && music.isListening
              ? music.features
              : null;
        },
      )..softFlashes = _preferences.softFlashes;
      player.play();
      unawaited(_screenWake.keepOn(true));
      unawaited(_preferences.recordPlayed(effect.id));
      _armSleepTimer();
      _setStatus(PlaybackStatus.playing);
    } on Object catch (error) {
      if (cancelled()) {
        return _cleanUpCancelled(streaming);
      }
      final player = _player;
      _player = null;
      await player?.stop();
      await streaming?.close();
      return _abortStart(
          PlaybackNotice(PlaybackNoticeKind.startFailed, error: error));
    }
  }

  Future<void> pause() async {
    final player = _player;
    if (_status != PlaybackStatus.playing || player == null) {
      return;
    }
    player.pause();
    _pausePlaylistTimer();
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
    if (!await _startListening()) {
      return;
    }
    if (_player != player) {
      // Stopped or retargeted while the microphone was starting.
      await _music?.stop();
      return;
    }
    player.play();
    unawaited(_screenWake.keepOn(true));
    final left = _playlistLeft;
    if (_playlist != null && left != null) {
      _armPlaylistTimer(left);
    }
    _setStatus(PlaybackStatus.playing);
  }

  /// Stops playback and, unless [restore] is false, puts the lights back.
  Future<void> stop({bool restore = true}) {
    _generation++;
    _cancelSleepTimer();
    _endPlaylist();
    final player = _player;
    final commands = _restore;
    _player = null;
    _slotNames = null;
    _restore = const {};
    _activeLightIds = const [];
    _setStatus(PlaybackStatus.idle);
    final previous = _teardown;
    late final Future<void> current;
    current = () async {
      if (previous != null) {
        await previous;
      }
      try {
        await player?.stop();
      } finally {
        try {
          await _music?.stop();
        } finally {
          unawaited(_screenWake.keepOn(false));
          final client = _bridge.client;
          if (restore && commands.isNotEmpty && client != null) {
            unawaited(restoreLights(client, commands));
          }
        }
      }
    }()
        .whenComplete(() {
      if (identical(_teardown, current)) {
        _teardown = null;
      }
    });
    return _teardown = current;
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
    final playlist = _playlist;
    await stop();
    _targetKey = targetKey;
    _targetChosen = true;
    unawaited(_preferences.setLastTarget(targetKey));
    _notify();
    if (wasPlaying) {
      if (playlist != null) {
        await playPlaylist(playlist);
      } else {
        await start();
      }
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

  /// Switches the lights off after [duration] (null: never). Counts wall
  /// time from now, or from the next start when nothing is playing.
  void setSleepTimer(Duration? duration) {
    _sleepAfter = duration;
    _cancelSleepTimer();
    if (_status == PlaybackStatus.playing || _status == PlaybackStatus.paused) {
      _armSleepTimer();
    }
    _notify();
  }

  void _armSleepTimer() {
    final after = _sleepAfter;
    _cancelSleepTimer();
    if (after == null) {
      return;
    }
    _sleepEndsAt = DateTime.now().add(after);
    _sleepTimer = Timer(after, _onSleepElapsed);
    // Repaint the remaining time now and then.
    _sleepTicker =
        Timer.periodic(const Duration(seconds: 15), (_) => _notify());
  }

  void _cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepTicker?.cancel();
    _sleepTicker = null;
    _fadeTimer?.cancel();
    _fadeTimer = null;
    _sleepEndsAt = null;
    _fadingOut = false;
  }

  /// Fades the effect to black over [sleepFade], then switches the lights
  /// off for good instead of restoring them.
  void _onSleepElapsed() {
    final player = _player;
    if (_disposed || player == null) {
      return;
    }
    if (_status != PlaybackStatus.playing) {
      // Paused: nothing to fade, just finish.
      unawaited(_finishSleep());
      return;
    }
    _fadingOut = true;
    _sleepEndsAt = null;
    _notify();
    const step = Duration(milliseconds: 100);
    final steps = (sleepFade.inMilliseconds / step.inMilliseconds).ceil();
    var elapsed = 0;
    _fadeTimer = Timer.periodic(step, (timer) {
      elapsed++;
      player.masterLevel = (1 - elapsed / steps).clamp(0.0, 1.0);
      if (elapsed >= steps) {
        timer.cancel();
        unawaited(_finishSleep());
      }
    });
  }

  Future<void> _finishSleep() async {
    const off = HueLightCommand(on: false, transition: Duration(seconds: 2));
    _restore = {for (final id in _activeLightIds) id: off};
    await stop();
    _notice(const PlaybackNotice(PlaybackNoticeKind.sleepTimerDone));
  }

  /// Starts the microphone (or the phone's audio) for Music Sync effects.
  /// Returns false (after telling the user why) when it cannot listen.
  Future<bool> _startListening() async {
    if (!effect.usesMicrophone) {
      return true;
    }
    final source = musicSource;
    var music = _music;
    if (music != null && _musicSourceInUse != source) {
      // The preference changed since: listen to the new source.
      await _dropMusic(music);
      music = null;
    }
    if (music == null) {
      final input = source == MusicSource.phoneAudio
          ? _phoneAudioInput ?? _audioInput
          : _audioInput;
      music = _music = MusicSyncController(input)..sensitivity = _sensitivity;
      _musicSourceInUse = source;
      music.addListener(_onMusicChanged);
    }
    await music.start();
    switch (music.status) {
      case MusicSyncStatus.listening:
        return true;
      case MusicSyncStatus.denied:
        _notice(PlaybackNotice(source == MusicSource.phoneAudio
            ? PlaybackNoticeKind.phoneAudioDenied
            : PlaybackNoticeKind.microphoneDenied));
      default:
        _notice(PlaybackNotice(source == MusicSource.phoneAudio
            ? PlaybackNoticeKind.phoneAudioFailed
            : PlaybackNoticeKind.microphoneFailed));
    }
    return false;
  }

  Future<void> _dropMusic(MusicSyncController music) async {
    if (identical(_music, music)) {
      _music = null;
      _musicSourceInUse = null;
    }
    music.removeListener(_onMusicChanged);
    await music.stop();
    music.dispose();
  }

  /// The Music Sync source preference changed: listen to the new one at
  /// once when an effect plays, else just drop the old controller so the
  /// next start uses the new source.
  Future<void> _switchMusicSource() async {
    final music = _music;
    if (music == null || _musicSourceInUse == musicSource) {
      return;
    }
    final wasListening = music.isListening;
    await _dropMusic(music);
    if (wasListening && _status == PlaybackStatus.playing && !_disposed) {
      await _startListening();
    }
    _notify();
  }

  void _abortStart(PlaybackNotice notice) {
    unawaited(_music?.stop());
    _setStatus(PlaybackStatus.idle);
    _notice(notice);
  }

  /// A stop or dispose happened while starting: undo what was set up.
  Future<void> _cleanUpCancelled(EntertainmentLightOutput? streaming) {
    final previous = _teardown;
    late final Future<void> current;
    current = () async {
      if (previous != null) {
        await previous;
      }
      await streaming?.close();
      if (_status == PlaybackStatus.idle || _disposed) {
        await _music?.stop();
      }
    }()
        .whenComplete(() {
      if (identical(_teardown, current)) {
        _teardown = null;
      }
    });
    return _teardown = current;
  }

  /// The microphone stopped on its own while an effect plays: say so, since
  /// the lights would otherwise just sit at the dim floor.
  void _onMusicChanged() {
    if (_disposed || _music?.status != MusicSyncStatus.failed) {
      return;
    }
    if (_status == PlaybackStatus.playing) {
      _notice(PlaybackNotice(_musicSourceInUse == MusicSource.phoneAudio
          ? PlaybackNoticeKind.phoneAudioStopped
          : PlaybackNoticeKind.microphoneStopped));
    }
  }

  void _onStreamEnded(LightOutput output, Object? error) {
    if (_disposed || _player?.output != output) {
      return;
    }
    unawaited(stop());
    _notice(PlaybackNotice(PlaybackNoticeKind.streamEnded, error: error));
  }

  void _onBridgeChanged() => _notify();

  /// Settings changed while playing (e.g. soften flashes from the warning
  /// dialog): apply them to the running player.
  void _onPreferencesChanged() {
    _player?.softFlashes = _preferences.softFlashes;
    final defaults = _preferences.defaultControls;
    if (defaults != _defaults) {
      // New defaults from Settings apply from now on.
      _defaults = defaults;
      setControls(defaults);
    }
    if (!_targetChosen &&
        _status == PlaybackStatus.idle &&
        _targetKey != _preferences.lastTarget) {
      // The saved preferences finished loading after this was created.
      _targetKey = _preferences.lastTarget;
    }
    if (_music != null && _musicSourceInUse != musicSource) {
      unawaited(_switchMusicSource());
    }
    _notify();
  }

  void _setStatus(PlaybackStatus status) {
    _status = status;
    _notify();
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  void _notice(PlaybackNotice notice) {
    if (!_disposed) {
      _notices.add(notice);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelSleepTimer();
    _endPlaylist();
    _bridge.removeListener(_onBridgeChanged);
    _preferences.removeListener(_onPreferencesChanged);
    final music = _music;
    music?.removeListener(_onMusicChanged);
    unawaited(stop().whenComplete(() => music?.dispose()));
    unawaited(_notices.close());
    super.dispose();
  }

  /// Lights that can show an effect: on/off-only lights (plugs, relays)
  /// are skipped, since switching them several times a second is useless
  /// and can wear them out, and so are the lights the user left out.
  List<String> _effectLights(HueHome home, HueGroup group) {
    final excluded = _preferences.excludedLights(group.id);
    return [
      for (final id in group.lightIds)
        if ((home.lights[id]?.isDimmable ?? false) && !excluded.contains(id))
          id,
    ];
  }

  static List<SlotLabel> _channelNames(
    HueHome home,
    HueEntertainmentArea area,
  ) =>
      [
        for (final channel in area.spatialChannels)
          channel.lightIds.isEmpty
              ? UnnamedChannel(channel.id)
              : NamedSlot(channel.lightIds
                  .map((id) => home.lights[id]?.name ?? id)
                  .join(' / ')),
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
