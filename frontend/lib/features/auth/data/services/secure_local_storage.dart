import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Secure session storage adapter delegating persistence to [FlutterSecureStorage].
///
/// Encrypts auth tokens using Android EncryptedSharedPreferences / KeyStore
/// and iOS Keychain. Tokens are NEVER stored in plaintext SharedPreferences.
class SecureLocalStorage extends LocalStorage {
  SecureLocalStorage({
    this.persistSessionKey = 'trustcue_secure_session',
    FlutterSecureStorage? storage,
  }) : _storage =
           storage ??
           const FlutterSecureStorage(
             aOptions: AndroidOptions(resetOnError: true),
             iOptions: IOSOptions(
               accessibility: KeychainAccessibility.first_unlock,
             ),
           );

  final String persistSessionKey;
  final FlutterSecureStorage _storage;

  @override
  Future<void> initialize() async {
    // FlutterSecureStorage requires no async initialization step.
  }

  @override
  Future<bool> hasAccessToken() async {
    try {
      final value = await _storage.read(key: persistSessionKey);
      return value != null && value.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<String?> accessToken() async {
    try {
      return await _storage.read(key: persistSessionKey);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> removePersistedSession() async {
    try {
      await _storage.delete(key: persistSessionKey);
    } catch (_) {
      // Best-effort deletion
    }
  }

  @override
  Future<void> persistSession(String persistSessionString) async {
    try {
      await _storage.write(key: persistSessionKey, value: persistSessionString);
    } catch (_) {
      // Handle storage write error silently without crashing
    }
  }
}
