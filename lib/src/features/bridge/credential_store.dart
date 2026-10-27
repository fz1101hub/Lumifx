import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/hue/hue_models.dart';
import '../library/preferences_controller.dart';

/// Secure storage could not be read right now (e.g. the keychain is locked
/// during a launch). The credentials may well still be there.
class CredentialStoreException implements Exception {
  const CredentialStoreException(this.cause);

  final Object cause;

  @override
  String toString() => 'CredentialStoreException: $cause';
}

/// Persists the paired bridge, and any others paired before (a second
/// home). The application key grants full control of the user's lights,
/// so it lives in the platform keychain/keystore.
abstract interface class CredentialStore {
  Future<HueCredentials?> load();
  Future<void> save(HueCredentials credentials);
  Future<void> clear();

  /// The other bridges paired, not in use now.
  Future<List<HueCredentials>> loadOthers();
  Future<void> saveOthers(List<HueCredentials> others);
}

class SecureCredentialStore implements CredentialStore {
  SecureCredentialStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'hue_credentials';
  static const _othersKey = 'hue_credentials_others';

  final FlutterSecureStorage _storage;

  @override
  Future<HueCredentials?> load() async {
    final String? raw;
    try {
      raw = await _storage.read(key: _key);
    } on Object catch (error) {
      // A transient platform error must not throw the pairing away.
      throw CredentialStoreException(error);
    }
    if (raw == null) {
      return null;
    }
    try {
      return HueCredentials.fromJson(
          (jsonDecode(raw) as Map).cast<String, Object?>());
    } on Object {
      // Corrupt or from an incompatible version: pair again.
      try {
        await clear();
      } on Object {
        // Nothing more to do; the next pairing overwrites it.
      }
      return null;
    }
  }

  @override
  Future<void> save(HueCredentials credentials) =>
      _storage.write(key: _key, value: jsonEncode(credentials.toJson()));

  @override
  Future<void> clear() => _storage.delete(key: _key);

  @override
  Future<List<HueCredentials>> loadOthers() async {
    final String? raw;
    try {
      raw = await _storage.read(key: _othersKey);
    } on Object catch (error) {
      throw CredentialStoreException(error);
    }
    if (raw == null) {
      return const [];
    }
    try {
      return [
        for (final item in jsonDecode(raw) as List)
          HueCredentials.fromJson((item as Map).cast<String, Object?>()),
      ];
    } on Object {
      // Corrupt: those bridges pair again.
      return const [];
    }
  }

  @override
  Future<void> saveOthers(List<HueCredentials> others) => others.isEmpty
      ? _storage.delete(key: _othersKey)
      : _storage.write(
          key: _othersKey,
          value: jsonEncode([for (final c in others) c.toJson()]));
}

class InMemoryCredentialStore implements CredentialStore {
  InMemoryCredentialStore([this._credentials]);

  HueCredentials? _credentials;

  @override
  Future<HueCredentials?> load() async => _credentials;

  @override
  Future<void> save(HueCredentials credentials) async =>
      _credentials = credentials;

  @override
  Future<void> clear() async => _credentials = null;

  var _others = <HueCredentials>[];

  @override
  Future<List<HueCredentials>> loadOthers() async => _others;

  @override
  Future<void> saveOthers(List<HueCredentials> others) async =>
      _others = [...others];
}

/// Marks that this install of the app has been seen.
const installedKey = 'lumifx.installed';

/// The iOS keychain can keep the bridge's keys after the app is deleted;
/// the app's own storage goes with it. On a fresh install (nothing in
/// [store] yet) the keys left behind by an earlier one are forgotten, so
/// a reinstalled app pairs again, as the privacy policy says. Older
/// installs already have their preferences saved and keep their pairing.
Future<void> forgetEarlierInstall(
  KeyValueStore store,
  CredentialStore credentials,
) async {
  try {
    if (await store.read(installedKey) != null) {
      return;
    }
    if (await store.read(PreferencesController.storageKey) == null) {
      await credentials.clear();
      await credentials.saveOthers(const []);
    }
    await store.write(installedKey, '1');
  } on Object {
    // The keychain is locked right now: the next launch tries again.
  }
}
