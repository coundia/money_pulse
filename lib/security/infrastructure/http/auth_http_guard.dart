/// HTTP guard that injects Authorization header and refreshes on 401 using api + tokenStore directly.
import '../../domain/entities/auth_session.dart';
import '../../domain/repositories/secure_token_store.dart';
import 'auth_api_client.dart';
import 'http_exceptions.dart';

class AuthHttpGuard {
  final SecureTokenStore tokenStore;
  final AuthApiClient api;

  AuthHttpGuard({required this.tokenStore, required this.api});

  Future<Map<String, Object?>> get(String path) {
    return _run((headers) => api.get(path, headers: headers));
  }

  Future<Map<String, Object?>> post(String path, Map<String, Object?> body) {
    return _run((headers) => api.post(path, body, headers: headers));
  }

  Future<Map<String, Object?>> _run(
    Future<Map<String, Object?>> Function(Map<String, String> headers) call,
  ) async {
    AuthSession? session = await tokenStore.read();
    final headers = <String, String>{};
    if (session != null && session.accessToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer ${session.accessToken}';
    }
    try {
      return await call(headers);
    } on HttpUnauthorizedException {
      if (session == null || session.refreshToken.isEmpty) rethrow;
      final data = await api.post('/auth/refresh', {
        'refreshToken': session.refreshToken,
      });
      final newSession = AuthSession(
        accessToken: (data['accessToken'] ?? '') as String,
        refreshToken: (data['refreshToken'] ?? '') as String,
        expiresAt: (data['expiresAt'] as String?) != null
            ? DateTime.tryParse(data['expiresAt'] as String)
            : null,
      );
      await tokenStore.write(newSession);
      headers['Authorization'] = 'Bearer ${newSession.accessToken}';
      return await call(headers);
    }
  }
}
