import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../core/audio/audio_input.dart';
import '../../core/color/light_color.dart';
import '../../core/effects/effect.dart';
import '../../core/effects/effect_event.dart';
import '../../core/effects/engine/effect_player.dart';
import '../../core/effects/engine/effect_renderer.dart';
import '../../core/effects/engine/light_frame.dart';
import '../../core/effects/engine/light_output.dart';
import '../../core/hue/entertainment/entertainment_session.dart';
import '../../core/hue/hue_bridge_client.dart';
import '../../core/hue/hue_models.dart';
import '../../core/hue/hue_exceptions.dart';
import '../../core/hue/hue_schedules.dart';
import '../../core/screen_wake.dart';
import '../../core/sound/melody.dart';
import '../../core/sound/sound_player.dart';
import '../../core/sound/soundscape.dart';
import '../bridge/bridge_controller.dart';
import '../library/preferences_controller.dart';
import '../music/music_sync_controller.dart';
import '../tv/camera_input.dart';
import '../tv/tv_sync_controller.dart';
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

  /// TV Sync: the camera was refused, or could not be opened.
  cameraDenied,
  cameraFailed,

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

  /// A one-shot effect (a timer, a game) came to its end and stopped;
  /// [PlaybackNotice.name] is its name.
  finished,
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
    SoundPlayer sound = const NoSoundPlayer(),
    CameraInput camera = const NoCameraInput(),
  })  : _effect = effect,
        _camera = camera,
        _sound = sound,
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
  final SoundPlayer _sound;
  final CameraInput _camera;

  /// Watches the frames for lightning, to answer with thunder.
  StreamSubscription<List<LightFrame>>? _lightningWatch;
  Timer? _thunderTimer;
  DateTime? _lastThunder;
  bool _soundPlaying = false;

  /// The default controls last applied, to notice when Settings change them.
  EffectControls _defaults;

  /// The user picked a target here, so a late preferences load must not
  /// replace it.
  bool _targetChosen = false;

  Playlist? _playlist;
  int _playlistIndex = 0;

  _Bedtime? _bedtime;
  Timer? _bedtimeTimer;

  /// Watches a one-shot effect for its end.
  Timer? _endWatch;
  Timer? _playlistTimer;
  DateTime? _playlistNextAt;
  Duration? _playlistLeft;

  final _notices = StreamController<PlaybackNotice>.broadcast();
  PlaybackStatus _status = PlaybackStatus.idle;
  EffectPlayer? _player;
  MusicSyncController? _music;
  TvSyncController? _tv;
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

  /// What the current effect sounds like (silent for most).
  Soundscape get soundscape => soundscapeOf(effectToPlay);

  /// Starts (or replaces) the sounds of the current effect for [player].
  void _startSound(EffectPlayer player) {
    _stopSound();
    final scape = soundscape;
    if (!_preferences.soundOn || scape.isSilent) {
      return;
    }
    _soundPlaying = true;
    unawaited(_sound.play(scape, volume: _preferences.soundVolume));
    if (scape.thunder) {
      unawaited(_sound.prepare(thunder: true));
      double? previous;
      _lightningWatch = player.frames.listen((frames) {
        if (frames.isEmpty) {
          return;
        }
        final mean =
            frames.fold<double>(0, (s, f) => s + f.brightness) / frames.length;
        // A sudden jump in brightness is a strike: thunder follows, a
        // moment later, as sound travels slower than light.
        if (previous != null && mean - previous! > 0.3) {
          _scheduleThunder();
        }
        previous = mean;
      });
    }
  }

  void _scheduleThunder() {
    final last = _lastThunder;
    if ((_thunderTimer?.isActive ?? false) ||
        (last != null &&
            DateTime.now().difference(last) < const Duration(seconds: 3))) {
      return;
    }
    // Close behind the flash, as if the storm were near: a long, real
    // delay reads as the sound lagging behind the light.
    _thunderTimer =
        Timer(Duration(milliseconds: 150 + _random.nextInt(450)), () {
      if (_status == PlaybackStatus.playing && _soundPlaying) {
        _lastThunder = DateTime.now();
        unawaited(_sound.thunder(volume: _preferences.soundVolume));
      }
    });
  }

  void _stopSound() {
    unawaited(_lightningWatch?.cancel());
    _lightningWatch = null;
    _thunderTimer?.cancel();
    _thunderTimer = null;
    if (_soundPlaying) {
      _soundPlaying = false;
      unawaited(_sound.stop());
    }
  }

  bool _systemReducesMotion = false;

  /// The phone asks apps to reduce motion (iOS Reduce Motion, Android
  /// "Remove animations"): flashes are softened as with the setting.
  bool get systemReducesMotion => _systemReducesMotion;
  set systemReducesMotion(bool value) {
    if (value == _systemReducesMotion) {
      return;
    }
    _systemReducesMotion = value;
    _player?.softFlashes = softFlashes;
    _notify();
  }

  /// Whether flashes are softened: by the user's setting or the phone's.
  bool get softFlashes => _preferences.softFlashes || _systemReducesMotion;

  /// Whether the player of [effectId] shows what plays now: the effect
  /// itself, or any effect of the playlist that plays (that player follows
  /// the playlist from one effect to the next).
  bool isShownBy(String effectId) =>
      _effect.id == effectId ||
      (_playlist?.effectIds.contains(effectId) ?? false) ||
      _bedtime?.storyId == effectId;

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
    _endBedtime();
    _playlist = playlist;
    _playlistIndex = playlist.shuffle ? _random.nextInt(effects.length) : 0;
    await _switchEffect(effects[_playlistIndex]);
    if (_status == PlaybackStatus.idle) {
      await start();
    } else if (_status == PlaybackStatus.paused) {
      await resume();
    }
    if (_playlist == playlist) {
      if (_status == PlaybackStatus.playing) {
        _armPlaylistTimer(playlist.each);
      } else {
        // It could not start (bridge away, microphone refused): no
        // playlist left behind that would never move on.
        _endPlaylist();
      }
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

  /// The palette a dynamic Hue scene of the current effect would move
  /// through: for effects made of one drifting palette (the built-in
  /// ambient scenes and the user's own), null for stories and the like,
  /// whose events the bridge cannot play.
  HueScenePalette? get dynamicPalette {
    final effect = effectToPlay;
    final events = effect.events
        .where((e) => e.type == EffectEventTypes.ambientPalette)
        .toList();
    if (events.length != 1 || effect.events.length != 1) {
      return null;
    }
    final p = events.single.parameters;
    final palette = p['palette'];
    if (palette is! List || palette.length < 2) {
      return null;
    }
    double number(String key, double fallback) =>
        (p[key] as num?)?.toDouble() ?? fallback;
    final middle =
        (number('brightnessMin', 0.3) + number('brightnessMax', 0.8)) / 2;
    // The renderer's speeds run from about 0.015 (calm) to 0.12 (flames);
    // the bridge's from 0 to 1.
    final speed = number('speed', 0.05) * _controls.speed / 0.15;
    return HueScenePalette(
      colors: [
        for (final hex in palette.whereType<String>()) LightColor.fromHex(hex),
      ],
      brightness: (middle * _controls.brightness).clamp(0.05, 1.0),
      speed: speed.clamp(0.05, 1.0),
    );
  }

  /// Saves what the lights show right now as a scene named [name] in the
  /// room or zone, then refreshes the bridge so it appears with the other
  /// scenes. When [dynamic] and the effect has a [dynamicPalette], the
  /// scene keeps moving through it on its own. Throws when the bridge
  /// refuses.
  Future<HueScene?> saveAsHueScene(String name, {bool dynamic = false}) async {
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
    final actions = lightCommands(
      home.lights,
      {
        for (final (i, id) in player.lightIds.indexed)
          if (i < player.currentFrames.length) id: player.currentFrames[i],
      },
    );
    final id = await client.createScene(
      name: name,
      group: group,
      actions: actions,
      palette: dynamic ? dynamicPalette : null,
    );
    await _bridge.refresh();
    return this.home?.scenes.where((s) => s.id == id).firstOrNull ??
        HueScene(id: id, name: name, groupId: group.id);
  }

  /// Whether the effect can be scheduled on the bridge: one drifting
  /// palette (the bridge plays it as a dynamic scene) on a room or zone.
  bool get canScheduleOnBridge =>
      canSaveAsHueScene && dynamicPalette != null && group?.idV1 != null;

  /// Saves the effect as a dynamic Hue scene and has the bridge recall it
  /// at [hour]:[minute] on [days] (none: once), and switch the room off
  /// at the stop time if one is given. Runs with the phone off.
  Future<void> scheduleOnBridge({
    required String name,
    required int hour,
    required int minute,
    required List<int> days,
    int? stopHour,
    int? stopMinute,
  }) async {
    final groupId = group?.idV1;
    final client = _bridge.client;
    if (!canScheduleOnBridge || groupId == null || client == null) {
      throw const HueException('Play the effect on a room or zone first');
    }
    final scene = await saveAsHueScene(name, dynamic: true);
    final sceneId = scene?.idV1;
    if (sceneId == null) {
      throw const HueException('The bridge did not create the scene');
    }
    await client.createEffectSchedule(HueEffectScheduleDraft(
      name: name,
      groupId: groupId,
      sceneId: sceneId,
      hour: hour,
      minute: minute,
      days: days,
      stopHour: stopHour,
      stopMinute: stopMinute,
    ));
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

  /// Every light (or only the one [at] along the room, 0 to 1) shows
  /// [color] at once for [length], over the effect: a game's answer to a
  /// tap. Nothing happens unless an effect plays.
  void flash(
    LightColor color, {
    Duration length = const Duration(milliseconds: 600),
    double? at,
  }) {
    if (_status == PlaybackStatus.playing) {
      _player?.flashNow(color, length: length, at: at);
    }
  }

  /// A clap of thunder on the phone (a scare at a Halloween party). Silent
  /// when sounds are off.
  Future<void> thunder() async {
    if (!_preferences.soundOn) {
      return;
    }
    await _sound.thunder(volume: _preferences.soundVolume);
  }

  /// Gets the notes [midis] of [instrument] (and the thunder) ready ahead,
  /// so the first key or scare sounds at once.
  Future<void> prepareSounds({
    Iterable<int> midis = const [],
    Instrument instrument = Instrument.musicBox,
    bool thunder = false,
  }) =>
      _sound.prepare(midis: midis, instrument: instrument, thunder: thunder);

  /// One note of [instrument] on the phone, on top of the effect's sounds
  /// (the light piano). Silent when sounds are off.
  Future<void> note(int midi, Instrument instrument) async {
    if (!_preferences.soundOn) {
      return;
    }
    await _sound.note(midi, instrument, volume: _preferences.soundVolume);
  }

  MusicSyncController? get music => _music;

  /// The camera watching the TV, while a TV Sync effect plays.
  TvSyncController? get tvSync => _tv;
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

  /// The controls the lights run with: an effect with a tune keeps the
  /// tune's own pace whatever the speed set, so the lights stay with the
  /// music (and the music is not cut off when the lights end early); one
  /// tied to the clock keeps to the clock.
  EffectControls _playerControls(EffectControls controls) =>
      controls.speed != 1 &&
              (effectToPlay.keepsRealTime ||
                  soundscapeOf(effectToPlay).melody != null)
          ? controls.copyWith(speed: 1)
          : controls;

  /// How fast the lights' time runs now (see [_playerControls]).
  double get effectiveSpeed => _playerControls(_controls).speed;

  /// Plays [next] instead of the current effect, leaving any playlist
  /// or bedtime. When idle it is only selected; while playing or paused
  /// the lights cross-fade to it without being put back in between, and
  /// Music Sync starts or stops as needed.
  Future<void> switchEffect(LightingEffect next) async {
    if (_playlist != null) {
      _endPlaylist();
      _notify();
    }
    _endBedtime();
    await _switchEffect(next);
  }

  /// The night glow bedtime ends with.
  static const bedtimeGlowId = 'goodnight_glow';

  /// Bedtime is on: [story] now, then the night glow, then lights off.
  bool get inBedtime => _bedtime != null;

  /// When bedtime moves on to the night glow, and when the lights go off.
  DateTime? get bedtimeGlowAt => _bedtime?.glowAt;
  DateTime? get bedtimeOffAt => _bedtime?.offAt;

  /// Bedtime in one tap: [story] for [storyFor] at [brightness], then the
  /// night glow for [glowFor], then the lights fade out and switch off
  /// (the sleep timer). Controls and sleep timer go back to what they
  /// were when bedtime ends.
  Future<void> startBedtime(
    LightingEffect story, {
    required Duration storyFor,
    required Duration glowFor,
    double? brightness,
  }) async {
    final controls = _controls;
    final sleep = _sleepAfter;
    await switchEffect(story);
    if (brightness != null) {
      setControls(_controls.copyWith(brightness: brightness));
    }
    setSleepTimer(storyFor + glowFor);
    if (_status == PlaybackStatus.idle) {
      await start();
    } else if (_status == PlaybackStatus.paused) {
      await resume();
    }
    if (_status != PlaybackStatus.playing || !identical(_effect, story)) {
      // It could not start: leave things as they were.
      setControls(controls);
      setSleepTimer(sleep);
      return;
    }
    final now = DateTime.now();
    _bedtime = _Bedtime(
      storyId: story.id,
      glowAt: now.add(storyFor),
      offAt: now.add(storyFor + glowFor),
      controls: controls,
      sleepAfter: sleep,
    );
    _bedtimeTimer = Timer(storyFor, () {
      final glow = _resolveEffect(bedtimeGlowId);
      if (_bedtime != null && glow != null && _player != null) {
        unawaited(_switchEffect(glow, crossfade: const Duration(seconds: 8)));
      }
    });
    _notify();
  }

  /// When the one-shot effect playing reaches its end, the lights fade out
  /// and switch off instead of going back to how they were.
  bool _offAtEnd = false;

  /// Ends the one-shot effect now playing (a lullaby) by fading the
  /// lights out and switching them off; any other effect started since
  /// ends as usual.
  void switchOffAtEnd() {
    if (!_effect.isLooping) {
      _offAtEnd = true;
    }
  }

  /// A one-shot effect (a timer, a game) stops by itself at its end and
  /// puts the lights back; looping effects play until stopped.
  void _watchEnd() {
    _endWatch?.cancel();
    _endWatch = null;
    if (_effect.isLooping || _player == null) {
      return;
    }
    _endWatch = Timer.periodic(const Duration(milliseconds: 250), (_) {
      final player = _player;
      if (player == null || _effect.isLooping) {
        _endWatch?.cancel();
        _endWatch = null;
        return;
      }
      if (player.position >= _effect.cycleLength) {
        _endWatch?.cancel();
        _endWatch = null;
        final name = _effect.name;
        if (_offAtEnd && _status == PlaybackStatus.playing) {
          // Hold the last instant while it fades, then switch off.
          _offAtEnd = false;
          _cancelSleepTimer();
          _onSleepElapsed();
          return;
        }
        unawaited(stop());
        _notice(PlaybackNotice(PlaybackNoticeKind.finished, name: name));
      }
    });
  }

  /// Bedtime is over (stopped, or the user chose something else): the
  /// brightness and sleep timer from before come back.
  void _endBedtime() {
    final bedtime = _bedtime;
    if (bedtime == null) {
      return;
    }
    _bedtime = null;
    _bedtimeTimer?.cancel();
    _bedtimeTimer = null;
    _controls = bedtime.controls;
    _player?.controls = _playerControls(bedtime.controls);
    _sleepAfter = bedtime.sleepAfter;
    if (_status == PlaybackStatus.playing || _status == PlaybackStatus.paused) {
      // The user's own timer again, from now (or none).
      _armSleepTimer();
    } else {
      _cancelSleepTimer();
    }
    _notify();
  }

  Future<void> _switchEffect(
    LightingEffect next, {
    Duration crossfade = const Duration(milliseconds: 1500),
  }) async {
    if (identical(next, _effect)) {
      return;
    }
    _effect = next;
    _offAtEnd = false;
    _player?.controls = _playerControls(_controls);
    final player = _player;
    if (player == null || _status == PlaybackStatus.starting) {
      _notify();
      return;
    }
    if (!next.usesMicrophone) {
      await _music?.stop();
    }
    if (!next.usesCamera) {
      await _tv?.stop();
    }
    if (next.usesMicrophone || next.usesCamera) {
      if (_status == PlaybackStatus.playing && !await _startListening()) {
        await stop();
        return;
      }
    }
    if (!identical(_player, player)) {
      return;
    }
    player.crossfadeTo(effectToPlay, over: crossfade);
    _watchEnd();
    _startSound(player);
    if (_status == PlaybackStatus.paused && _soundPlaying) {
      unawaited(_sound.pause());
    }
    if (!next.isGenerated) {
      unawaited(_preferences.recordPlayed(next.id));
    }
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

  static const _severalPrefix = 'groups:';

  /// The target key that plays on all of [groupIds] at once.
  static String severalRoomsKey(Iterable<String> groupIds) =>
      '$_severalPrefix${groupIds.join(',')}';

  /// The rooms and zones the effect plays on: the selected one, or the
  /// several chosen together (those that still exist).
  List<HueGroup> get roomGroups {
    final key = _targetKey;
    if (key != null && key.startsWith(_severalPrefix)) {
      final ids = key.substring(_severalPrefix.length).split(',');
      return [
        for (final id in ids)
          if (groups.where((g) => g.id == id).firstOrNull case final g?) g,
      ];
    }
    final single = group;
    return single == null ? const [] : [single];
  }

  /// Whether several rooms or zones play together.
  bool get playsSeveralRooms =>
      (_targetKey?.startsWith(_severalPrefix) ?? false) &&
      roomGroups.isNotEmpty;

  /// Where the effect plays, for labels: the area, or the rooms joined
  /// with "+"; null for the preview.
  String? get targetName =>
      area?.name ??
      (roomGroups.isEmpty ? null : roomGroups.map((g) => g.name).join(' + '));

  /// The selected target if it still exists; null means the preview.
  String? get selectedTarget =>
      roomGroups.isNotEmpty || area != null ? _targetKey : null;

  /// One label per slot of the lamp preview.
  List<SlotLabel> get lightNames {
    final playing = _slotNames;
    if (playing != null && _player != null) {
      return playing;
    }
    final home = this.home;
    final rooms = roomGroups;
    final area = this.area;
    if (home != null && rooms.isNotEmpty) {
      return _slotLabels(home, _lightsOfGroups(home, rooms));
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
      final listeningFor = _effect;
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
      // What each slot shows before the effect, to fade in from; the
      // preview's lamps start dark.
      List<LightFrame>? before;

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
        final rooms = roomGroups;
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
          before = [
            for (final channel in area.spatialChannels)
              switch (channel.lightIds) {
                [final id, ...] when home.lights[id] != null =>
                  home.lights[id]!.currentFrame,
                _ => LightFrame.off,
              },
          ];
          // Hue recommends 50-60 messages per second; the bridge forwards
          // them to the lights at 25 Hz.
          tick = const Duration(milliseconds: 20);
          final opened = streaming;
          unawaited(opened.session.done.then(
            (_) => _onStreamEnded(opened, null),
            onError: (Object error) => _onStreamEnded(opened, error),
          ));
        } else if (rooms.isNotEmpty) {
          final usable = _lightsOfGroups(home, rooms);
          if (usable.isEmpty) {
            return _abortStart(PlaybackNotice(
              PlaybackNoticeKind.onOffOnlyLights,
              name: rooms.map((g) => g.name).join(' + '),
            ));
          }
          restore = _snapshot(home, {for (final id in usable) lightOfSlot(id)});
          output = hueRestOutput(client, home.lights);
          lightIds = usable;
          names = _slotLabels(home, usable);
          before = [
            for (final slot in usable) _currentFrameOfSlot(home, slot),
          ];
        } else {
          return _abortStart(
              const PlaybackNotice(PlaybackNoticeKind.targetGone));
        }
      }

      _restore = _preferences.restoreLights ? restore : const {};
      // The real lights (an area's slots are channels, not lights), for
      // the sleep timer to switch off.
      _activeLightIds =
          selectedTarget == null ? const [] : restore.keys.toList();
      _slotNames = names;
      // Assigned before play(): if the first tick throws, stop() can still
      // find and stop the player (and its timer).
      final player = _player = EffectPlayer(
        effect: effectToPlay,
        lightIds: lightIds,
        output: output,
        seed: DateTime.now().millisecondsSinceEpoch & 0x7FFFFFFF,
        controls: _playerControls(_controls),
        tick: tick,
        // Read on every tick, so a later switch to (or from) a Music Sync
        // effect is picked up.
        audio: () {
          final music = _music;
          return _effect.usesMicrophone && music != null && music.isListening
              ? music.features
              : null;
        },
        screen: () => _effect.usesCamera ? _tv?.colors : null,
      )..softFlashes = softFlashes;
      if (_preferences.gentleStart) {
        player
            .fadeInFrom(before ?? List.filled(lightIds.length, LightFrame.off));
      }
      player.play();
      _startSound(player);
      unawaited(_screenWake.keepOn(true));
      if (!effect.isGenerated) {
        unawaited(_preferences.recordPlayed(effect.id));
      }
      _armSleepTimer();
      _setStatus(PlaybackStatus.playing);
      _watchEnd();
      if (!identical(_effect, listeningFor)) {
        // Switched while starting: the microphone or camera opened for the
        // effect chosen first.
        unawaited(_matchInputs());
      }
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
    if (_soundPlaying) {
      unawaited(_sound.pause());
    }
    unawaited(_sound.stopCues());
    _setStatus(PlaybackStatus.paused);
    // No reason to keep the microphone open or the screen on while paused.
    unawaited(_screenWake.keepOn(false));
    await _stopInputs();
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
      await _stopInputs();
      return;
    }
    player.play();
    unawaited(_screenWake.keepOn(true));
    final left = _playlistLeft;
    if (_playlist != null && left != null) {
      _armPlaylistTimer(left);
    }
    if (_soundPlaying) {
      unawaited(_sound.resume());
    }
    _setStatus(PlaybackStatus.playing);
  }

  /// Stops playback and, unless [restore] is false, puts the lights back.
  Future<void> stop({bool restore = true}) {
    _generation++;
    _offAtEnd = false;
    _endWatch?.cancel();
    _endWatch = null;
    _cancelSleepTimer();
    _endPlaylist();
    _stopSound();
    // A piano note or a clap of thunder still ringing stops with the rest.
    unawaited(_sound.stopCues());
    final player = _player;
    final commands = _restore;
    _player = null;
    _slotNames = null;
    _restore = const {};
    _activeLightIds = const [];
    _setStatus(PlaybackStatus.idle);
    _endBedtime();
    final previous = _teardown;
    Future<void>? restoring;
    final stopped = () async {
      if (previous != null) {
        await previous;
      }
      try {
        await player?.stop();
      } finally {
        try {
          await _stopInputs();
        } finally {
          unawaited(_screenWake.keepOn(false));
          final client = _bridge.client;
          if (restore && commands.isNotEmpty && client != null) {
            restoring = restoreLights(client, commands);
          }
        }
      }
    }();
    // The next start waits for the lights to be put back as well, so it
    // never takes the effect's colours for the lights' own (to restore
    // later, or to fade in from); the caller only waits for the stop.
    late final Future<void> current;
    current = stopped
        .then((_) => restoring)
        .catchError((Object _) {})
        .whenComplete(() {
      if (identical(_teardown, current)) {
        _teardown = null;
      }
    });
    _teardown = current;
    return stopped;
  }

  /// Set by the app where the platform can keep it running with the
  /// screen off (Android) and the user wants that.
  bool keepPlayingInBackground = false;

  /// The app went to the background. Unless it can keep running there,
  /// it cannot keep driving the lights, so it stops cleanly instead of
  /// leaving them frozen mid-effect. The preview always stops: nobody
  /// sees it.
  Future<void> handleAppPaused() async {
    if (_status == PlaybackStatus.idle) {
      return;
    }
    // The camera closes in the background, so TV Sync cannot go on.
    if (keepPlayingInBackground &&
        selectedTarget != null &&
        _status != PlaybackStatus.starting &&
        !_effect.usesCamera) {
      return;
    }
    await stop();
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
    _player?.controls = _playerControls(controls);
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
      if (_soundPlaying) {
        unawaited(
            _sound.setVolume(_preferences.soundVolume * player.masterLevel));
      }
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

  /// Starts the microphone (or the phone's audio) for Music Sync effects,
  /// or the camera for TV Sync. Returns false (after telling the user why)
  /// when it cannot.
  Future<bool> _startListening() async {
    if (effect.usesCamera) {
      return _startWatching();
    }
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

  /// Opens the camera for TV Sync.
  Future<bool> _startWatching() async {
    final tv = _tv ??= TvSyncController(_camera)..addListener(_notify);
    await tv.start();
    switch (tv.status) {
      case TvSyncStatus.watching:
        return true;
      case TvSyncStatus.denied:
        _notice(const PlaybackNotice(PlaybackNoticeKind.cameraDenied));
      default:
        _notice(const PlaybackNotice(PlaybackNoticeKind.cameraFailed));
    }
    return false;
  }

  /// Opens the microphone or camera the current effect needs and closes
  /// the others; stops when the needed one cannot open.
  Future<void> _matchInputs() async {
    if (!_effect.usesMicrophone) {
      await _music?.stop();
    }
    if (!_effect.usesCamera) {
      await _tv?.stop();
    }
    if (_status == PlaybackStatus.playing && !await _startListening()) {
      await stop();
    }
  }

  /// Closes the microphone and the camera.
  Future<void> _stopInputs() async {
    await Future.wait([
      if (_music case final music?) music.stop(),
      if (_tv case final tv?) tv.stop(),
    ]);
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
    unawaited(_stopInputs());
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
        await _stopInputs();
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
    _player?.softFlashes = softFlashes;
    _applySoundPreferences();
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

  /// Sound switched on or off, or its volume changed, while playing.
  void _applySoundPreferences() {
    if (!_preferences.soundOn) {
      // Even with no soundscape playing (the piano's notes).
      unawaited(_sound.stopCues());
    }
    final player = _player;
    if (player == null || _status == PlaybackStatus.starting) {
      return;
    }
    final wanted = _preferences.soundOn && !soundscape.isSilent;
    if (wanted && !_soundPlaying) {
      _startSound(player);
      if (_status == PlaybackStatus.paused) {
        unawaited(_sound.pause());
      }
    } else if (!wanted && _soundPlaying) {
      _stopSound();
    } else if (_soundPlaying && !_fadingOut) {
      unawaited(_sound.setVolume(_preferences.soundVolume));
    }
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
    _bedtimeTimer?.cancel();
    _endWatch?.cancel();
    _endPlaylist();
    _stopSound();
    unawaited(_sound.stopCues());
    _bridge.removeListener(_onBridgeChanged);
    _preferences.removeListener(_onPreferencesChanged);
    final music = _music;
    music?.removeListener(_onMusicChanged);
    final tv = _tv;
    tv?.removeListener(_notify);
    unawaited(stop().whenComplete(() {
      music?.dispose();
      tv?.dispose();
    }));
    unawaited(_notices.close());
    super.dispose();
  }

  /// The effect's slots on a room or zone: one per light that can show
  /// an effect, or several for a gradient light (`<id>#<segment>`).
  /// On/off-only lights (plugs, relays) are skipped, since switching them
  /// several times a second is useless and can wear them out, and so are
  /// the lights the user left out.
  List<String> _effectLights(HueHome home, HueGroup group) {
    final excluded = _preferences.excludedLights(group.id);
    return [
      for (final id in group.lightIds)
        if (home.lights[id] case final light?
            when light.isDimmable && !excluded.contains(id))
          if (light.segments == 1)
            id
          else
            for (var s = 0; s < light.segments; s++) '$id#$s',
    ];
  }

  /// The slots of several rooms and zones, each light once (a light can
  /// be in a room and a zone).
  List<String> _lightsOfGroups(HueHome home, List<HueGroup> groups) {
    final seen = <String>{};
    return [
      for (final group in groups)
        for (final slot in _effectLights(home, group))
          if (seen.add(slot)) slot,
    ];
  }

  static LightFrame _currentFrameOfSlot(HueHome home, String slot) {
    final light = home.lights[lightOfSlot(slot)];
    if (light == null) {
      return LightFrame.off;
    }
    final hash = slot.indexOf('#');
    return hash < 0
        ? light.currentFrame
        : light.currentFrameOfSegment(
            int.parse(slot.substring(hash + 1)), light.segments);
  }

  static List<SlotLabel> _slotLabels(HueHome home, List<String> slots) => [
        for (final slot in slots)
          switch (slot.indexOf('#')) {
            -1 => NamedSlot(home.lights[slot]?.name ?? slot),
            final hash =>
              NamedSlot('${home.lights[slot.substring(0, hash)]?.name ?? slot} '
                  '${int.parse(slot.substring(hash + 1)) + 1}'),
          },
      ];

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

/// The light a slot belongs to: slots of gradient lights are named
/// `<light id>#<segment>`.
String lightOfSlot(String slot) {
  final hash = slot.indexOf('#');
  return hash < 0 ? slot : slot.substring(0, hash);
}

/// One command per light for the frames of [slots]: gradient segments are
/// combined into the light's gradient.
Map<String, HueLightCommand> lightCommands(
  Map<String, HueLight> lights,
  Map<String, LightFrame> slots, {
  Duration? transition,
}) {
  final segments = <String, List<(int, LightFrame)>>{};
  final commands = <String, HueLightCommand>{};
  slots.forEach((slot, frame) {
    final hash = slot.indexOf('#');
    if (hash >= 0) {
      segments
          .putIfAbsent(slot.substring(0, hash), () => [])
          .add((int.parse(slot.substring(hash + 1)), frame));
      return;
    }
    final light = lights[slot];
    commands[slot] = light == null
        ? HueLightCommand.fromColor(frame.color, frame.brightness,
            transition: transition)
        : HueLightCommand.forLight(light, frame.color, frame.brightness,
            transition: transition);
  });
  segments.forEach((id, parts) {
    parts.sort((a, b) => a.$1.compareTo(b.$1));
    commands[id] = HueLightCommand.gradient(
      [for (final p in parts) p.$2.color],
      [for (final p in parts) p.$2.brightness],
      transition: transition,
    );
  });
  return commands;
}

/// Sends frames to Hue lights through the REST API, adapting each command
/// to what the light supports. Gradient segments are sent together as one
/// gradient command per light, within the same command budget.
LightOutput hueRestOutput(
  HueBridgeClient client,
  Map<String, HueLight> lights,
) {
  final segments = <String, Map<String, LightFrame>>{};
  final limited = RateLimitedLightOutput(
    // A slow command still on its way when the effect stops is waited for
    // until it has landed or failed, so it never undoes the restore.
    closeTimeout: HueBridgeClient.requestTimeout + const Duration(seconds: 1),
    send: (lightId, frame, transition) {
      final parts = segments[lightId] ?? {lightId: frame};
      final command = lightCommands(lights, parts, transition: transition);
      return client.setLight(lightId, command[lightId]!);
    },
  );
  return GradientLightOutput(limited, segments);
}

/// Folds the segment slots of gradient lights into one frame per light for
/// the rate limiter (so a strip costs one command, not three), keeping the
/// segments in [segments] for the command itself.
class GradientLightOutput implements LightOutput {
  GradientLightOutput(this._inner, this.segments);

  final LightOutput _inner;
  final Map<String, Map<String, LightFrame>> segments;

  @override
  void update(Map<String, LightFrame> frames, Duration tick) {
    final perLight = <String, LightFrame>{};
    final grouped = <String, Map<String, LightFrame>>{};
    frames.forEach((slot, frame) {
      final light = lightOfSlot(slot);
      if (light == slot) {
        perLight[slot] = frame;
      } else {
        (grouped[light] ??= {})[slot] = frame;
      }
    });
    grouped.forEach((light, parts) {
      segments[light] = parts;
      perLight[light] = _summary(parts.values.toList());
    });
    _inner.update(perLight, tick);
  }

  /// A frame that changes whenever any segment changes noticeably: the
  /// segments' colours side by side would be ideal, but one frame is all
  /// the limiter compares, so it gets their sum (and the peak brightness).
  /// Each colour counts as much as its segment is bright, so one segment
  /// dimming under a brighter one still registers.
  static LightFrame _summary(List<LightFrame> parts) {
    var r = 0.0, g = 0.0, b = 0.0, peak = 0.0;
    for (final (i, frame) in parts.indexed) {
      // Weighted by position, so colours trading places still register.
      final weight = (i + 1) / parts.length * frame.brightness;
      r += frame.color.r * weight;
      g += frame.color.g * weight;
      b += frame.color.b * weight;
      peak = math.max(peak, frame.brightness);
    }
    final n = parts.isEmpty ? 1 : parts.length;
    return LightFrame(LightColor(r / n, g / n, b / n), peak);
  }

  @override
  Future<void> close() => _inner.close();
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

/// What bedtime remembers to put back when it ends.
class _Bedtime {
  const _Bedtime({
    required this.storyId,
    required this.glowAt,
    required this.offAt,
    required this.controls,
    required this.sleepAfter,
  });

  final String storyId;
  final DateTime glowAt;
  final DateTime offAt;
  final EffectControls controls;
  final Duration? sleepAfter;
}
