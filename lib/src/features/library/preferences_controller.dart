import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/audio/audio_input.dart';
import '../../core/effects/engine/effect_renderer.dart';
import '../playlists/playlist.dart';
import 'user_scene.dart';

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
      _musicSource = MusicSource.values.asNameMap()[json['musicSource']] ??
          MusicSource.microphone;
      final scenes = json['userScenes'];
      _userScenes = [
        if (scenes is List)
          for (final item in scenes)
            if (UserScene.fromJson(item) case final scene?) scene,
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

  /// Removes the scene, and takes it out of favourites, recents and
  /// playlists.
  Future<void> deleteUserScene(String id) {
    _userScenes = [
      for (final s in _userScenes)
        if (s.id != id) s,
    ];
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
      'musicSource': _musicSource.name,
      'playlists': [for (final p in _playlists) p.toJson()],
      'userScenes': [for (final s in _userScenes) s.toJson()],
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

  static double _unit(Object? value, double fallback) =>
      ((value as num?)?.toDouble() ?? fallback).clamp(0.0, 1.0);
}
