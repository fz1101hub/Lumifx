import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/hue/hue_models.dart';

/// Persists the paired bridge. The application key grants full control of
/// the user's lights, so it lives in the platform keychain/keystore.
abstract interface class CredentialStore {
  Future<HueCredentials?> load();
  Future<void> save(HueCredentials credentials);
  Future<void> clear();
}

class SecureCredentialStore implements CredentialStore {
  SecureCredentialStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'hue_credentials';

  final FlutterSecureStorage _storage;

  @override
  Future<HueCredentials?> load() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) {
      return null;
    }
    try {
      return HueCredentials.fromJson(
          (jsonDecode(raw) as Map).cast<String, Object?>());
    } on Object {
      // Corrupt or from an incompatible version: pair again.
      await clear();
      return null;
    }
  }

  @override
  Future<void> save(HueCredentials credentials) =>
      _storage.write(key: _key, value: jsonEncode(credentials.toJson()));

  @override
  Future<void> clear() => _storage.delete(key: _key);
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
}
