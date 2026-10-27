import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/audio/audio_input.dart';
import '../../core/effects/engine/effect_renderer.dart';
import '../../core/weather/weather.dart';
import '../bedtime/ritual.dart';
import '../fun/countdown.dart';
import '../music_box/my_tune.dart';
import '../notifications/notification_lights.dart';
import '../playlists/playlist.dart';
import '../routines/child.dart';
import '../routines/custom_step.dart';
import '../routines/star_shop.dart';
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

  /// Where the preferences are kept in the [KeyValueStore].
  static const storageKey = _key;
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

  /// Set once anything changes.
  bool _dirty = false;

  /// True while [load] reads: a change made meanwhile is not written (it
  /// would replace everything saved with a snapshot of mostly empty
  /// fields) but saved once loading is done, on top of what was read.
  bool _loading = false;
  bool _changedWhileLoading = false;
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

  var _children = <Child>[];
  var _activeChild = '';

  /// The children with a profile; none until a grown-up adds one.
  List<Child> get children => List.unmodifiable(_children);

  /// The child whose routines and stars show; null without profiles.
  Child? get activeChild =>
      _children.where((c) => c.id == _activeChild).firstOrNull ??
      _children.firstOrNull;

  /// The active child's id, empty without profiles (or for the first).
  String get activeChildId => activeChild?.id ?? '';

  /// Adds a child, who becomes the active one, and gives back their id.
  Future<String> addChild(String name) async {
    final id =
        _children.isEmpty ? '' : 'c${DateTime.now().microsecondsSinceEpoch}';
    final child = Child.fromJson({'id': id, 'name': name});
    if (child == null || _children.length >= Child.maxChildren) {
      return activeChildId;
    }
    _children = [..._children, child];
    _activeChild = id;
    await _changed();
    return id;
  }

  Future<void> renameChild(String id, String name) {
    final renamed = Child.fromJson({'id': id, 'name': name});
    if (renamed == null) {
      return Future.value();
    }
    _children = [for (final c in _children) c.id == id ? renamed : c];
    return _changed();
  }

  /// Removes a child with their stars, routine steps and spent stars.
  Future<void> removeChild(String id) {
    _children = [
      for (final c in _children)
        if (c.id != id) c
    ];
    _stars = [
      for (final key in _stars)
        if (!_belongsTo(key, id)) key
    ];
    _routineSteps = {
      for (final MapEntry(:key, :value) in _routineSteps.entries)
        if (!_belongsTo(key, id)) key: value,
    };
    _starsSpent = {..._starsSpent}..remove(id);
    if (_activeChild == id) {
      _activeChild = _children.firstOrNull?.id ?? '';
    }
    return _changed();
  }

  Future<void> setActiveChild(String id) {
    _activeChild = id;
    return _changed();
  }

  /// [key] of [child]: as it is for the first child (or without
  /// profiles), with the child's id in front for the others.
  static String _ofChild(String child, String key) =>
      child.isEmpty ? key : '$child|$key';

  static bool _belongsTo(String key, String child) =>
      child.isEmpty ? !key.contains('|') : key.startsWith('$child|');

  var _customSteps = <CustomStep>[];

  /// The steps a grown-up made, for any routine.
  List<CustomStep> get customSteps => List.unmodifiable(_customSteps);

  /// Makes a step; null when there are too many or the name is empty.
  Future<CustomStep?> addCustomStep(
      String name, int iconIndex, String color) async {
    final step = CustomStep.fromJson({
      'id': '${DateTime.now().microsecondsSinceEpoch}',
      'name': name,
      'icon': iconIndex,
      'color': color,
    });
    if (step == null || _customSteps.length >= CustomStep.maxSteps) {
      return null;
    }
    _customSteps = [..._customSteps, step];
    await _changed();
    return step;
  }

  /// Removes a step a grown-up made, from every routine too.
  Future<void> removeCustomStep(String id) {
    final key = 'custom:$id';
    _customSteps = [
      for (final s in _customSteps)
        if (s.id != id) s
    ];
    _routineSteps = {
      for (final MapEntry(key: routine, value: steps) in _routineSteps.entries)
        routine: [
          for (final s in steps)
            if (s != key) s
        ],
    };
    return _changed();
  }

  var _routineSteps = <String, List<String>>{};

  /// The steps a grown-up kept in [routine] (by name) for [child] (the
  /// active one by default); null: all of them.
  List<String>? routineSteps(String routine, {String? child}) =>
      _routineSteps[_ofChild(child ?? activeChildId, routine)];

  Future<void> setRoutineSteps(String routine, List<String> steps,
      {String? child}) {
    _routineSteps = {
      ..._routineSteps,
      _ofChild(child ?? activeChildId, routine): steps.take(20).toList(),
    };
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

  /// The stars the active child earned, one per routine and day
  /// (`yyyy-mm-dd:routine`).
  Set<String> get stars => starsOf(activeChildId);

  /// The stars [child] earned.
  Set<String> starsOf(String child) => {
        for (final key in _stars)
          if (_belongsTo(key, child))
            child.isEmpty ? key : key.substring(child.length + 1),
      };

  /// Gives the active child (or [child]) the star of [key] unless it was
  /// given already; true if new.
  bool earnStar(String key, {String? child}) {
    final stored = _ofChild(child ?? activeChildId, key);
    if (_stars.contains(stored)) {
      return false;
    }
    // A year of stars for each child is plenty to keep.
    _stars = [..._stars, stored];
    if (_stars.length > _maxStars) {
      _stars = _stars.sublist(_stars.length - _maxStars);
    }
    unawaited(_changed());
    return true;
  }

  static const _maxStars = 800 * Child.maxChildren;

  var _ritual = const RitualSettings();

  /// How the bedtime ritual goes.
  RitualSettings get ritual => _ritual;

  Future<void> setRitual(RitualSettings settings) {
    _ritual = settings;
    return _changed();
  }

  var _rewards = <Reward>[];

  /// The star shop's rewards, the same for every child.
  List<Reward> get rewards => List.unmodifiable(_rewards);

  Future<void> addReward(String name, int cost, int icon) {
    final reward = Reward.fromJson({
      'id': 'r${DateTime.now().microsecondsSinceEpoch}',
      'name': name,
      'cost': cost,
      'icon': icon,
    });
    if (reward == null || _rewards.length >= Reward.maxRewards) {
      return Future.value();
    }
    _rewards = [..._rewards, reward];
    return _changed();
  }

  Future<void> removeReward(String id) {
    _rewards = [
      for (final r in _rewards)
        if (r.id != id) r
    ];
    return _changed();
  }

  var _starsSpent = <String, int>{};

  /// Stars [child] spent in the star shop.
  int starsSpent(String child) => _starsSpent[child] ?? 0;

  /// The stars [child] can still spend.
  int starBalance(String child) =>
      (starsOf(child).length - starsSpent(child)).clamp(0, 1 << 30);

  /// Spends [cost] of [child]'s stars; false when there are not enough.
  bool spendStars(String child, int cost) {
    if (cost <= 0 || starBalance(child) < cost) {
      return false;
    }
    _starsSpent = {..._starsSpent, child: starsSpent(child) + cost};
    unawaited(_changed());
    return true;
  }

  List<String>? _kidsActivities;

  /// The games kids mode offers besides the effects (by name); null for
  /// all of them.
  List<String>? get kidsActivities => _kidsActivities;

  Future<void> setKidsActivities(List<String> names) {
    _kidsActivities = names.take(10).toList();
    return _changed();
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

  Map<String, String> _speechVoices = const {};

  /// The voice chosen to read aloud, by speech language (`it-IT`); a
  /// language without one reads with the most natural voice the phone
  /// has.
  Map<String, String> get speechVoices => _speechVoices;

  String? speechVoiceFor(String language) => _speechVoices[language];

  /// Chooses [voiceId] for [language]; null goes back to the automatic
  /// choice.
  Future<void> setSpeechVoice(String language, String? voiceId) {
    _speechVoices = {
      for (final MapEntry(:key, :value) in _speechVoices.entries)
        if (key != language) key: value,
      if (voiceId != null) language: voiceId,
    };
    return _changed();
  }

  var _myTunes = <MyTune>[];

  /// The tunes kept from the light piano, newest last.
  List<MyTune> get myTunes => List.unmodifiable(_myTunes);

  /// Keeps [tune], replacing one of the same name; the oldest goes when
  /// there are too many.
  Future<void> saveTune(MyTune tune) {
    _myTunes = [
      for (final t in _myTunes)
        if (t.name != tune.name) t,
      tune,
    ];
    if (_myTunes.length > MyTune.maxTunes) {
      _myTunes = _myTunes.sublist(_myTunes.length - MyTune.maxTunes);
    }
    return _changed();
  }

  Future<void> deleteTune(String name) {
    _myTunes = [
      for (final t in _myTunes)
        if (t.name != name) t,
    ];
    return _changed();
  }

  String? _toothFairy;

  /// The tooth fairy's visit planned: the child's id and the time, as
  /// `<child>|<minutes since the epoch>`; null when none is planned.
  ({String child, DateTime at})? get toothFairy {
    final [child, minutes, ...] = [...?_toothFairy?.split('|'), '', ''];
    final at = int.tryParse(minutes);
    return _toothFairy == null || at == null
        ? null
        : (
            child: child,
            at: DateTime.fromMillisecondsSinceEpoch(
                at * Duration.millisecondsPerMinute),
          );
  }

  /// Plans the tooth fairy's visit, or forgets it (null).
  Future<void> setToothFairy(({String child, DateTime at})? visit) {
    _toothFairy = visit == null
        ? null
        : '${visit.child}|'
            '${visit.at.millisecondsSinceEpoch ~/ Duration.millisecondsPerMinute}';
    return _changed();
  }

  String? _goalTeam;

  /// The team the goal celebration is for: a `GoalTeam` name, or the
  /// colours of a team of your own (`#RRGGBB,#RRGGBB`).
  String? get goalTeam => _goalTeam;

  Future<void> setGoalTeam(String team) {
    _goalTeam = team;
    return _changed();
  }

  int? _napMinutes;

  /// The rest chosen last for the nap light.
  int? get napMinutes => _napMinutes;

  Future<void> setNapMinutes(int minutes) {
    _napMinutes = minutes;
    return _changed();
  }

  String? _noiseLimit;

  /// The noise light's limit chosen last (a `NoiseLimit` name).
  String? get noiseLimit => _noiseLimit;

  Future<void> setNoiseLimit(String name) {
    _noiseLimit = name;
    return _changed();
  }

  bool _teethTune = true;

  /// Whether the teeth timer plays a tune.
  bool get teethTune => _teethTune;

  Future<void> setTeethTune(bool on) {
    _teethTune = on;
    return _changed();
  }

  int _pianoEchoBest = 0;

  /// The longest tune played back in Repeat after me.
  int get pianoEchoBest => _pianoEchoBest;

  /// Keeps [notes] if it beats the best; true when it does.
  bool recordPianoEcho(int notes) {
    if (notes <= _pianoEchoBest) {
      return false;
    }
    _pianoEchoBest = notes;
    unawaited(_changed());
    return true;
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
    _loading = true;
    try {
      final raw = await _store.read(_key);
      if (raw == null) {
        _firstRun = !_dirty;
        return;
      }
      // What was saved wins over anything changed before it was read: the
      // saved scenes, stories, profiles and stars must never be lost.
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
            if (key is String && value is List && key.length <= 60)
              key: _strings(value).take(20).toList(),
      };
      _stars = _strings(json['stars']).take(_maxStars).toList();
      final children = json['children'];
      _children = [
        if (children is List)
          for (final item in children.take(Child.maxChildren))
            if (Child.fromJson(item) case final child?) child,
      ];
      final active = json['activeChild'];
      _activeChild = active is String ? active : '';
      _ritual = RitualSettings.fromJson(json['ritual']);
      final custom = json['customSteps'];
      _customSteps = [
        if (custom is List)
          for (final item in custom.take(CustomStep.maxSteps))
            if (CustomStep.fromJson(item) case final step?) step,
      ];
      final rewards = json['rewards'];
      _rewards = [
        if (rewards is List)
          for (final item in rewards.take(Reward.maxRewards))
            if (Reward.fromJson(item) case final reward?) reward,
      ];
      final spent = json['starsSpent'];
      _starsSpent = {
        if (spent is Map)
          for (final MapEntry(:key, :value) in spent.entries)
            if (key is String && value is int && value >= 0) key: value,
      };
      _notificationLights =
          NotificationLightsSettings.fromJson(json['notificationLights']);
      final activities = json['kidsActivities'];
      _kidsActivities =
          activities is List ? _strings(activities).take(10).toList() : null;
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
      final nap = json['napMinutes'];
      _napMinutes = nap is int && nap > 0 && nap <= 240 ? nap : null;
      final noise = json['noiseLimit'];
      _noiseLimit = noise is String && noise.length <= 20 ? noise : null;
      _teethTune = json['teethTune'] != false;
      final echo = json['pianoEchoBest'];
      _pianoEchoBest = echo is int && echo > 0 && echo <= 100 ? echo : 0;
      final simon = json['simonBest'];
      _simonBest = simon is int && simon > 0 && simon < 1000 ? simon : 0;
      final tunes = json['myTunes'];
      _myTunes = [
        if (tunes is Map)
          for (final MapEntry(:key, :value)
              in tunes.entries.take(MyTune.maxTunes))
            if (key is String && value is String)
              if (MyTune.decode(key, value) case final tune?) tune,
      ];
      final fairy = json['toothFairy'];
      _toothFairy = fairy is String && fairy.length <= 80 ? fairy : null;
      final goal = json['goalTeam'];
      _goalTeam = goal is String && goal.length <= 40 ? goal : null;
      final speechVoices = json['speechVoices'];
      _speechVoices = {
        if (speechVoices is Map)
          for (final MapEntry(:key, :value) in speechVoices.entries.take(16))
            if (key is String &&
                value is String &&
                key.length <= 16 &&
                value.length <= 200)
              key: value,
      };
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
      _loading = false;
      _loaded = true;
      notifyListeners();
      if (_changedWhileLoading) {
        _changedWhileLoading = false;
        unawaited(_changed());
      }
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
    if (_loading) {
      _changedWhileLoading = true;
      return Future.value();
    }
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
      'pianoEchoBest': _pianoEchoBest,
      'countingBest': _countingBest,
      'learnLanguage': _learnLanguage,
      'napMinutes': _napMinutes,
      'speechVoices': _speechVoices,
      'goalTeam': _goalTeam,
      'toothFairy': _toothFairy,
      'myTunes': {for (final t in _myTunes) t.name: t.encoded},
      'noiseLimit': _noiseLimit,
      'teethTune': _teethTune,
      'naturalLights': _naturalLights,
      'kidsEffects': _kidsEffects,
      'kidsActivities': _kidsActivities,
      'routineSteps': _routineSteps,
      'stars': _stars,
      'children': [for (final c in _children) c.toJson()],
      'activeChild': _activeChild,
      'starsSpent': _starsSpent,
      'rewards': [for (final r in _rewards) r.toJson()],
      'ritual': _ritual.toJson(),
      'customSteps': [for (final s in _customSteps) s.toJson()],
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
