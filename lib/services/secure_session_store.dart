import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/session.dart';

/// Persists the active [AppSession] using the platform's secure storage
/// primitive (Keychain on iOS, EncryptedSharedPreferences/Keystore-backed
/// storage on Android) — never plain SharedPreferences, per section 3.6.
///
/// Only the *session* (a short-lived, scoped grant) is stored here, not the
/// raw deep-link token. The raw token is discarded immediately after a
/// successful exchange — persisting it would let anyone with disk access
/// replay the original claim link.
class SecureSessionStore {
  static const _sessionKey = 'omnipass.session.v1';

  final FlutterSecureStorage _storage;

  SecureSessionStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock,
              ),
            );

  Future<void> save(AppSession session) async {
    await _storage.write(
      key: _sessionKey,
      value: jsonEncode(session.toJson()),
    );
  }

  Future<AppSession?> read() async {
    final raw = await _storage.read(key: _sessionKey);
    if (raw == null) return null;
    try {
      return AppSession.fromJson(
        jsonDecode(raw) as Map<String, Object?>,
      );
    } catch (_) {
      // Corrupted entry — treat as no session rather than crashing.
      await clear();
      return null;
    }
  }

  Future<void> clear() async {
    await _storage.delete(key: _sessionKey);
  }
}
