import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/audio/audio_input.dart';
import '../../core/effects/engine/effect_renderer.dart';

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

  Future<void> load() async {
    try {
      final raw = await _store.read(_key);
      if (raw == null || _dirty) {
        return;
      }
      final json = (jsonDecode(raw) as Map).cast<String, Object?>();
      _favorites = _strings(json['favorites']);
      _recents = _strings(json['recents']);
      _lastTarget = json['lastTarget'] as String?;
      _restoreLights = json['restoreLights'] as bool? ?? true;
      _softFlashes = json['softFlashes'] as bool? ?? false;
      _flashWarningShown = json['flashWarningShown'] as bool? ?? false;
      _musicSource = MusicSource.values.asNameMap()[json['musicSource']] ??
          MusicSource.microphone;
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
    }
    notifyListeners();
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
      'musicSource': _musicSource.name,
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
