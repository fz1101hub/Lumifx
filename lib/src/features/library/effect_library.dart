import '../../core/effects/effect.dart';
import '../effects/catalog/effect_catalog.dart';
import 'preferences_controller.dart';
import 'user_scene.dart';

/// Every effect the app can play: the built-in catalog and the scenes the
/// user made (stored with the preferences, so listen to those for
/// changes).
class EffectLibrary {
  EffectLibrary(this._preferences);

  final PreferencesController _preferences;
  final _effects = Expando<LightingEffect>();

  /// The user's scenes as effects, newest first.
  List<LightingEffect> get userScenes => [
        for (final scene in _preferences.userScenes.reversed) _effectOf(scene),
      ];

  UserScene? userScene(String id) =>
      _preferences.userScenes.where((s) => s.id == id).firstOrNull;

  bool isUserScene(String id) => id.startsWith(UserScene.idPrefix);

  LightingEffect? byId(String id) {
    if (isUserScene(id)) {
      final scene = userScene(id);
      return scene == null ? null : _effectOf(scene);
    }
    return effectById(id);
  }

  /// Effects of [kind]; scenes include the user's own first unless
  /// [builtInOnly].
  List<LightingEffect> ofKind(EffectKind kind, {bool builtInOnly = false}) => [
        if (kind == EffectKind.scene && !builtInOnly) ...userScenes,
        ...effectsOfKind(kind),
      ];

  /// One effect object per stored scene, so the same scene compares as
  /// the same effect until it is edited.
  LightingEffect _effectOf(UserScene scene) =>
      _effects[scene] ??= scene.toEffect();
}
