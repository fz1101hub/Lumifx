import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/audio/audio_input.dart';
import '../../core/effects/engine/effect_renderer.dart';
import '../../core/weather/weather.dart';
import '../fun/countdown.dart';
import '../notifications/notification_lights.dart';
import '../playlists/playlist.dart';
import 'user_scene.dart';
import 'user_story.dart';

/// Where preferences are persisted. Nothing in here is sensitive; bridge
/// credentials live in [CredentialStore] instead.
abstract interface class KeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

class SharedPreferencesStore implements KeyValueStore {
  SharedPreferencesStore([SharedPreferencesAsync? preferences])
      : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;

  @override
  Future<String?> read(String key) => _preferences.getString(key);

  @override
  Future<void> write(String key, String value) =>
      _preferences.setString(key, value);
}

class InMemoryKeyValueStore implements KeyValueStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

/// Favorites, recently played effects and default playback settings.
class PreferencesController extends ChangeNotifier {
  PreferencesController({required KeyValueStore store}) : _store = store;

  static const _key = 'lumifx.preferences.v1';
  static const maxRecents = 8;

  final KeyValueStore _store;

  List<String> _favorites = const [];
  List<String> _recents = const [];
  EffectControls _defaultControls = const EffectControls();
  String? _lastTarget;
  bool _restoreLights = true;
  bool _softFlashes = false;
  bool _flashWarningShown = false;
  Map<String, String> _variants = const {};
  Map<String, List<String>> _excludedLights = const {};
  MusicSource _musicSource = MusicSource.microphone;
  List<Playlist> _playlists = const [];
  List<UserScene> _userScenes = const [];
  List<UserStory> _userStories = const [];

  /// Effect ids, most recently added first.
  List<String> get favorites => _favorites;

  /// Effect ids, most recently played first.
  List<String> get recents => _recents;

  /// Controls a new playback starts with.
  EffectControls get defaultControls => _defaultControls;

  /// The player's last target (`group:<id>`, `area:<id>`), or null for the
  /// preview.
  String? get lastTarget => _lastTarget;

  /// Put lights back the way they were when an effect stops.
  bool get restoreLights => _restoreLights;

  /// Slow down sudden brightness changes (lightning, beats) for
  /// photosensitive users.
  bool get softFlashes => _softFlashes;

  /// The one-time warning before a flashing effect has been shown.
  bool get flashWarningShown => _flashWarningShown;

  /// Where Music Sync listens; the phone's own audio only counts where
  /// the platform can capture it (the player falls back to the
  /// microphone elsewhere).
  MusicSource get musicSource => _musicSource;

  /// The user's playlists, in the order they were created.
  List<Playlist> get playlists => _playlists;

  /// The scenes the user made, in the order they were created.
  List<UserScene> get userScenes => _userScenes;

  /// The user's own stories, oldest first.
  List<UserStory> get userStories => _userStories;

  /// The colour variant chosen for an effect, or null for its original.
  String? variantOf(String effectId) => _variants[effectId];

  /// Lights of a room or zone that sit out of effects played on it.
  List<String> excludedLights(String groupId) =>
      _excludedLights[groupId] ?? const [];

  bool isFavorite(String effectId) => _favorites.contains(effectId);

  /// Set once the user changes anything, so a slow [load] cannot overwrite
  /// it with the stale snapshot from disk.
  bool _dirty = false;
  Future<void> _writes = Future.value();

  bool _loaded = false;
  bool _firstRun = false;
  bool _onboardingDone = false;
  bool _keepPlayingScreenOff = true;
  bool _gentleStart = true;
  bool _soundOn = true;
  double _soundVolume = 0.6;
  bool _readAlong = true;
  bool _readAloud = false;

  /// The phone reads a story's words aloud as they appear.
  bool get readAloud => _readAloud;

  Future<void> setReadAloud(bool value) {
    _readAloud = value;
    return _changed();
  }

  var _adventOpened = <String>[];

  /// Whether door [day] of the advent calendar of the season of [today]
  /// has been opened (the season runs into early January).
  bool isAdventOpened(int day, DateTime today) =>
      _adventOpened.contains(_adventKey(day, today));

  Future<void> openAdventDoor(int day, DateTime today) {
    final key = _adventKey(day, today);
    if (_adventOpened.contains(key)) {
      return Future.value();
    }
    // Only this season's doors are worth keeping.
    final season = _adventKey(0, today).split('-').first;
    _adventOpened = [
      for (final k in _adventOpened)
        if (k.startsWith('$season-')) k,
      key,
    ];
    return _changed();
  }

  static String _adventKey(int day, DateTime today) =>
      '${today.month == 1 ? today.year - 1 : today.year}-$day';

  var _countdowns = <Countdown>[];

  /// Days to wait for, soonest first.
  List<Countdown> get countdowns => List.unmodifiable(_countdowns);

  Future<void> saveCountdown(Countdown countdown) {
    _countdowns = [
      for (final c in _countdowns)
        if (c.id != countdown.id) c,
      countdown,
    ]..sort((a, b) => a.date.compareTo(b.date));
    if (_countdowns.length > Countdown.maxCountdowns) {
      _countdowns =
          _countdowns.sublist(_countdowns.length - Countdown.maxCountdowns);
    }
    return _changed();
  }

  Future<void> deleteCountdown(String id) {
    _countdowns = [
      for (final c in _countdowns)
        if (c.id != id) c,
    ];
    return _changed();
  }

  var _routineSteps = <String, List<String>>{};

  /// The steps a grown-up kept in [routine] (by name); null: all of them.
  List<String>? routineSteps(String routine) => _routineSteps[routine];

  Future<void> setRoutineSteps(String routine, List<String> steps) {
    _routineSteps = {..._routineSteps, routine: steps.take(20).toList()};
    return _changed();
  }

  var _notificationLights = const NotificationLightsSettings();

  /// Which apps' notifications flash the lights, and how (Android).
  NotificationLightsSettings get notificationLights => _notificationLights;

  Future<void> setNotificationLights(NotificationLightsSettings settings) {
    _notificationLights = settings;
    return _changed();
  }

  var _stars = <String>[];

  /// The stars earned, one per routine and day (`yyyy-mm-dd:routine`).
  Set<String> get stars => _stars.toSet();

  /// Gives the star of [key] unless it was given already; true if new.
  bool earnStar(String key) {
    if (_stars.contains(key)) {
      return false;
    }
    // A year of stars is plenty to keep.
    _stars = [..._stars, key];
    if (_stars.length > 800) {
      _stars = _stars.sublist(_stars.length - 800);
    }
    unawaited(_changed());
    return true;
  }

  List<String>? _kidsEffects;

  /// The effects offered in kids mode; null until a grown-up chooses.
  List<String>? get kidsEffects => _kidsEffects;

  Future<void> setKidsEffects(List<String> ids) {
    _kidsEffects = ids.take(24).toList();
    return _changed();
  }

  bool _kidsLocked = false;

  /// Kids mode is on: LumiFX opens in it until a grown-up leaves it.
  bool get kidsLocked => _kidsLocked;

  Future<void> setKidsLocked(bool value) {
    if (value == _kidsLocked) {
      return Future.value();
    }
    _kidsLocked = value;
    return _changed();
  }

  var _naturalLights = <String>[];

  /// The smart scenes LumiFX made for natural light (the bridge does not
  /// say who made one).
  Set<String> get naturalLightIds => _naturalLights.toSet();

  Future<void> addNaturalLight(String id) {
    _naturalLights = [..._naturalLights.where((i) => i != id), id];
    return _changed();
  }

  Future<void> removeNaturalLight(String id) {
    _naturalLights = [..._naturalLights.where((i) => i != id)];
    return _changed();
  }

  int _countingBest = 0;

  /// The most right answers in one game of Count the lights.
  int get countingBest => _countingBest;

  /// Keeps [score] if it beats the best; true when it does.
  bool recordCountingScore(int score) {
    if (score <= _countingBest) {
      return false;
    }
    _countingBest = score;
    unawaited(_changed());
    return true;
  }

  String? _learnLanguage;

  /// The language chosen last in Colours in another language.
  String? get learnLanguage => _learnLanguage;

  Future<void> setLearnLanguage(String code) {
    _learnLanguage = code;
    return _changed();
  }

  int _simonBest = 0;

  /// The longest sequence repeated in the memory game.
  int get simonBest => _simonBest;

  /// Keeps [score] if it beats the best; true when it does.
  bool recordSimonScore(int score) {
    if (score <= _simonBest) {
      return false;
    }
    _simonBest = score;
    unawaited(_changed());
    return true;
  }

  WeatherPlace? _weatherPlace;

  /// Where the weather lights look at the sky; null until one is chosen.
  WeatherPlace? get weatherPlace => _weatherPlace;

  Future<void> setWeatherPlace(WeatherPlace? place) {
    _weatherPlace = place;
    return _changed();
  }

  String _bedtimeStory = defaultBedtimeStory;
  int _bedtimeStoryMinutes = 10;
  int _bedtimeGlowMinutes = 20;
  double _bedtimeBrightness = 0.6;

  Map<String, String> _buttonActions = const {};

  /// What each Hue button does: an effect id, [buttonStop] or
  /// [buttonBedtime], by the button's id.
  Map<String, String> get buttonActions => _buttonActions;

  static const buttonStop = '@stop';
  static const buttonBedtime = '@bedtime';
  static const _maxButtons = 64;

  /// Sets what [buttonId] does; null leaves the button alone.
  Future<void> setButtonAction(String buttonId, String? action) {
    _buttonActions = {
      for (final MapEntry(:key, :value) in _buttonActions.entries)
        if (key != buttonId) key: value,
      if (action != null && _buttonActions.length < _maxButtons)
        buttonId: action,
    };
    return _changed();
  }

  static const defaultBedtimeStory = 'sleeping_dragon';
  static const bedtimeStoryChoices = [5, 10, 15, 20, 30];
  static const bedtimeGlowChoices = [5, 10, 20, 30, 45, 60];

  /// Bedtime as last chosen, so the next one is a single tap.
  String get bedtimeStory => _bedtimeStory;
  int get bedtimeStoryMinutes => _bedtimeStoryMinutes;
  int get bedtimeGlowMinutes => _bedtimeGlowMinutes;
  double get bedtimeBrightness => _bedtimeBrightness;

  Future<void> setBedtime({
    String? story,
    int? storyMinutes,
    int? glowMinutes,
    double? brightness,
  }) {
    _bedtimeStory = story ?? _bedtimeStory;
    if (storyMinutes != null && bedtimeStoryChoices.contains(storyMinutes)) {
      _bedtimeStoryMinutes = storyMinutes;
    }
    if (glowMinutes != null && bedtimeGlowChoices.contains(glowMinutes)) {
      _bedtimeGlowMinutes = glowMinutes;
    }
    if (brightness != null) {
      _bedtimeBrightness = brightness.clamp(0.1, 1.0);
    }
    return _changed();
  }

  /// The words of a story shown in time with its lights.
  bool get readAlong => _readAlong;

  Future<void> setReadAlong(bool value) {
    _readAlong = value;
    return _changed();
  }

  /// Ambient sounds under the effects that have them.
  bool get soundOn => _soundOn;

  /// 0..1.
  double get soundVolume => _soundVolume;

  Future<void> setSoundOn(bool value) {
    _soundOn = value;
    return _changed();
  }

  Future<void> setSoundVolume(double value) {
    _soundVolume = value.clamp(0.0, 1.0);
    return _changed();
  }

  /// Effects fade in from what the lights show instead of jumping.
  bool get gentleStart => _gentleStart;

  Future<void> setGentleStart(bool value) {
    _gentleStart = value;
    return _changed();
  }

  /// Effects on the lights go on when the phone locks (Android only).
  bool get keepPlayingScreenOff => _keepPlayingScreenOff;

  Future<void> setKeepPlayingScreenOff(bool value) {
    _keepPlayingScreenOff = value;
    return _changed();
  }

  /// [load] has finished.
  bool get isLoaded => _loaded;

  /// Nothing was stored yet when [load] ran: the app was just installed.
  bool get isFirstRun => _firstRun;

  /// The welcome pages have been seen (or skipped).
  bool get onboardingDone => _onboardingDone;

  Future<void> setOnboardingDone() {
    _onboardingDone = true;
    return _changed();
  }

  Future<void> load() async {
    try {
      final raw = await _store.read(_key);
      if (raw == null) {
        _firstRun = !_dirty;
        return;
      }
      if (_dirty) {
        return;
      }
      final json = (jsonDecode(raw) as Map).cast<String, Object?>();
      _favorites = _strings(json['favorites']);
      _recents = _strings(json['recents']);
      _lastTarget = json['lastTarget'] as String?;
      _restoreLights = json['restoreLights'] as bool? ?? true;
      _softFlashes = json['softFlashes'] as bool? ?? false;
      _flashWarningShown = json['flashWarningShown'] as bool? ?? false;
      _onboardingDone = json['onboardingDone'] as bool? ?? true;
      _keepPlayingScreenOff = json['keepPlayingScreenOff'] as bool? ?? true;
      _gentleStart = json['gentleStart'] as bool? ?? true;
      _soundOn = json['soundOn'] as bool? ?? true;
      _soundVolume = _unit(json['soundVolume'], 0.6);
      _readAlong = json['readAlong'] as bool? ?? true;
      _readAloud = json['readAloud'] == true;
      _weatherPlace = WeatherPlace.fromJson(json['weatherPlace']);
      _adventOpened = _strings(json['adventOpened']).take(60).toList();
      final countdowns = json['countdowns'];
      _countdowns = [
        if (countdowns is List)
          for (final item in countdowns.take(Countdown.maxCountdowns))
            if (Countdown.fromJson(item) case final countdown?) countdown,
      ]..sort((a, b) => a.date.compareTo(b.date));
      final routines = json['routineSteps'];
      _routineSteps = {
        if (routines is Map)
          for (final MapEntry(:key, :value) in routines.entries)
            if (key is String && value is List && key.length <= 20)
              key: _strings(value).take(20).toList(),
      };
      _stars = _strings(json['stars']).take(800).toList();
      _notificationLights =
          NotificationLightsSettings.fromJson(json['notificationLights']);
      final kids = json['kidsEffects'];
      _kidsEffects = kids is List ? _strings(kids).take(24).toList() : null;
      _kidsLocked = json['kidsLocked'] == true;
      _naturalLights = _strings(json['naturalLights'])
          .where((id) => id.length <= 80)
          .take(20)
          .toList();
      final counting = json['countingBest'];
      _countingBest =
          counting is int && counting > 0 && counting < 10000 ? counting : 0;
      final learn = json['learnLanguage'];
      _learnLanguage = learn is String && learn.length <= 5 ? learn : null;
      final simon = json['simonBest'];
      _simonBest = simon is int && simon > 0 && simon < 1000 ? simon : 0;
      final buttons = json['buttonActions'];
      _buttonActions = {
        if (buttons is Map)
          for (final MapEntry(:key, :value)
              in buttons.entries.take(_maxButtons))
            if (key is String &&
                value is String &&
                key.length <= 80 &&
                value.length <= 80)
              key: value,
      };
      final bedtime = json['bedtime'];
      if (bedtime is Map) {
        final story = bedtime['story'];
        final storyMinutes = bedtime['storyMinutes'];
        final glowMinutes = bedtime['glowMinutes'];
        if (story is String && story.length <= 80) {
          _bedtimeStory = story;
        }
        if (bedtimeStoryChoices.contains(storyMinutes)) {
          _bedtimeStoryMinutes = storyMinutes as int;
        }
        if (bedtimeGlowChoices.contains(glowMinutes)) {
          _bedtimeGlowMinutes = glowMinutes as int;
        }
        _bedtimeBrightness = _unit(bedtime['brightness'], 0.6).clamp(0.1, 1.0);
      }
      _musicSource = MusicSource.values.asNameMap()[json['musicSource']] ??
          MusicSource.microphone;
      final scenes = json['userScenes'];
      _userScenes = [
        if (scenes is List)
          for (final item in scenes)
            if (UserScene.fromJson(item) case final scene?) scene,
      ];
      final stories = json['userStories'];
      _userStories = [
        if (stories is List)
          for (final item in stories)
            if (UserStory.fromJson(item) case final story?) story,
      ];
      final playlists = json['playlists'];
      _playlists = [
        if (playlists is List)
          for (final item in playlists)
            if (Playlist.fromJson(item) case final playlist?) playlist,
      ];
      final variants = json['variants'];
      _variants = {
        if (variants is Map)
          for (final MapEntry(:key, :value) in variants.entries)
            if (key is String && value is String) key: value,
      };
      final excluded = json['excludedLights'];
      _excludedLights = {
        if (excluded is Map)
          for (final MapEntry(:key, :value) in excluded.entries)
            if (key is String && value is List) key: _strings(value),
      };
      final controls = json['defaultControls'];
      if (controls is Map) {
        _defaultControls = EffectControls(
          brightness: _unit(controls['brightness'], 1),
          intensity: _unit(controls['intensity'], 1),
          speed: ((controls['speed'] as num?)?.toDouble() ?? 1).clamp(0.25, 3),
        );
      }
    } on Object {
      // Unreadable preferences are not worth failing over; start fresh.
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  Future<void> toggleFavorite(String effectId) {
    _favorites = isFavorite(effectId)
        ? [
            for (final id in _favorites)
              if (id != effectId) id
          ]
        : [effectId, ..._favorites];
    return _changed();
  }

  Future<void> recordPlayed(String effectId) {
    _recents = [
      effectId,
      for (final id in _recents)
        if (id != effectId) id,
    ].take(maxRecents).toList();
    return _changed();
  }

  Future<void> setDefaultControls(EffectControls controls) {
    _defaultControls = controls;
    return _changed();
  }

  Future<void> setRestoreLights(bool value) {
    _restoreLights = value;
    return _changed();
  }

  Future<void> setSoftFlashes(bool value) {
    _softFlashes = value;
    return _changed();
  }

  Future<void> setFlashWarningShown(bool value) {
    _flashWarningShown = value;
    return _changed();
  }

  /// Adds [playlist], or replaces the one with the same id.
  Future<void> savePlaylist(Playlist playlist) {
    final index = _playlists.indexWhere((p) => p.id == playlist.id);
    _playlists = [
      for (final p in _playlists) p.id == playlist.id ? playlist : p,
      if (index < 0) playlist,
    ];
    return _changed();
  }

  /// Adds [scene], or replaces the one with the same id.
  Future<void> saveUserScene(UserScene scene) {
    final exists = _userScenes.any((s) => s.id == scene.id);
    _userScenes = [
      for (final s in _userScenes) s.id == scene.id ? scene : s,
      if (!exists) scene,
    ];
    return _changed();
  }

  /// Adds scenes, stories and playlists in one go (an imported link).
  Future<void> addAll({
    List<UserScene> scenes = const [],
    List<UserStory> stories = const [],
    List<Playlist> playlists = const [],
  }) {
    _userScenes = [..._userScenes, ...scenes];
    _userStories = [..._userStories, ...stories];
    _playlists = [..._playlists, ...playlists];
    return _changed();
  }

  /// Adds [story], or replaces the one with the same id.
  Future<void> saveUserStory(UserStory story) {
    final exists = _userStories.any((s) => s.id == story.id);
    _userStories = [
      for (final s in _userStories) s.id == story.id ? story : s,
      if (!exists) story,
    ];
    return _changed();
  }

  /// Removes the scene, and takes it out of favourites, recents and
  /// playlists.
  Future<void> deleteUserScene(String id) {
    _userScenes = [
      for (final s in _userScenes)
        if (s.id != id) s,
    ];
    return _forget(id);
  }

  /// Removes the story, and takes it out of favourites, recents and
  /// playlists.
  Future<void> deleteUserStory(String id) {
    _userStories = [
      for (final s in _userStories)
        if (s.id != id) s,
    ];
    return _forget(id);
  }

  Future<void> _forget(String id) {
    _favorites = [
      for (final f in _favorites)
        if (f != id) f,
    ];
    _recents = [
      for (final r in _recents)
        if (r != id) r,
    ];
    _playlists = [
      for (final p in _playlists)
        p.effectIds.contains(id)
            ? p.copyWith(effectIds: [
                for (final e in p.effectIds)
                  if (e != id) e,
              ])
            : p,
    ];
    return _changed();
  }

  Future<void> deletePlaylist(String id) {
    _playlists = [
      for (final p in _playlists)
        if (p.id != id) p,
    ];
    return _changed();
  }

  Future<void> setMusicSource(MusicSource value) {
    _musicSource = value;
    return _changed();
  }

  Future<void> setLightExcluded(
    String groupId,
    String lightId,
    bool excluded,
  ) {
    final ids = {
      ...excludedLights(groupId),
      if (excluded) lightId,
    }..removeWhere((id) => !excluded && id == lightId);
    _excludedLights = {
      for (final MapEntry(:key, :value) in _excludedLights.entries)
        if (key != groupId) key: value,
      if (ids.isNotEmpty) groupId: ids.toList(),
    };
    return _changed();
  }

  Future<void> setVariant(String effectId, String? variantId) {
    _variants = {
      for (final MapEntry(:key, :value) in _variants.entries)
        if (key != effectId) key: value,
      if (variantId != null) effectId: variantId,
    };
    return _changed();
  }

  Future<void> setLastTarget(String? target) {
    if (target == _lastTarget) {
      return Future.value();
    }
    _lastTarget = target;
    return _changed();
  }

  /// Writes are serialised so they land on disk in the order they were
  /// made; a failed write is logged, not thrown at a fire-and-forget
  /// caller (the in-memory state already shows the change).
  Future<void> _changed() {
    _dirty = true;
    notifyListeners();
    final snapshot = jsonEncode({
      'favorites': _favorites,
      'recents': _recents,
      'lastTarget': _lastTarget,
      'restoreLights': _restoreLights,
      'softFlashes': _softFlashes,
      'flashWarningShown': _flashWarningShown,
      'onboardingDone': _onboardingDone,
      'keepPlayingScreenOff': _keepPlayingScreenOff,
      'gentleStart': _gentleStart,
      'soundOn': _soundOn,
      'soundVolume': _soundVolume,
      'readAlong': _readAlong,
      'readAloud': _readAloud,
      'weatherPlace': _weatherPlace?.toJson(),
      'simonBest': _simonBest,
      'countingBest': _countingBest,
      'learnLanguage': _learnLanguage,
      'naturalLights': _naturalLights,
      'kidsEffects': _kidsEffects,
      'routineSteps': _routineSteps,
      'stars': _stars,
      'notificationLights': _notificationLights.toJson(),
      'kidsLocked': _kidsLocked,
      'adventOpened': _adventOpened,
      'countdowns': [for (final c in _countdowns) c.toJson()],
      'buttonActions': _buttonActions,
      'bedtime': {
        'story': _bedtimeStory,
        'storyMinutes': _bedtimeStoryMinutes,
        'glowMinutes': _bedtimeGlowMinutes,
        'brightness': _bedtimeBrightness,
      },
      'musicSource': _musicSource.name,
      'playlists': [for (final p in _playlists) p.toJson()],
      'userScenes': [for (final s in _userScenes) s.toJson()],
      'userStories': [for (final s in _userStories) s.toJson()],
      'variants': _variants,
      'excludedLights': _excludedLights,
      'defaultControls': {
        'brightness': _defaultControls.brightness,
        'intensity': _defaultControls.intensity,
        'speed': _defaultControls.speed,
      },
    });
    return _writes = _writes
        .then((_) => _store.write(_key, snapshot))
        .catchError((Object error) => debugPrint('Preferences: $error'));
  }

  static List<String> _strings(Object? value) =>
      value is List ? value.whereType<String>().toList() : const [];

  /// A 0..1 number, or [fallback] for anything else (a wrong type must
  /// not throw and lose the rest of the preferences).
  static double _unit(Object? value, double fallback) =>
      (value is num && value.isFinite ? value.toDouble() : fallback)
          .clamp(0.0, 1.0);
}
