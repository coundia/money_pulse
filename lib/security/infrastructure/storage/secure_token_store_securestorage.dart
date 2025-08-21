/// Secure token store using flutter_secure_storage, with web fallback key names.
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/repositories/secure_token_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureTokenStoreSecureStorage implements SecureTokenStore {
  final FlutterSecureStorage _storage;
  final String key;

  SecureTokenStoreSecureStorage({
    FlutterSecureStorage? storage,
    this.key = 'auth_session',
  }) : _storage = storage ?? const FlutterSecureStorage();

  @override
  Future<void> clear() async {
    await _storage.delete(key: key);
  }

  @override
  Future<AuthSession?> read() async {
    final raw = await _storage.read(key: key);
    if (raw == null || raw.isEmpty) return null;
    final map = jsonDecode(raw) as Map<String, Object?>;
    return AuthSession.fromJson(map);
  }

  @override
  Future<void> write(AuthSession session) async {
    final raw = jsonEncode(session.toJson());
    await _storage.write(key: key, value: raw);
  }
}
