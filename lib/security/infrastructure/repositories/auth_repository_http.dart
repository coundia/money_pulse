/// HTTP AuthRepository implementation with guarded authed calls and reset flows.
import '../../domain/repositories/auth_repository.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/entities/auth_session.dart';
import '../http/auth_api_client.dart';
import '../http/auth_http_guard.dart';

class AuthRepositoryHttp implements AuthRepository {
  final AuthApiClient api;
  final AuthHttpGuard guard;

  AuthRepositoryHttp(this.api, this.guard);

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final data = await api.post('/auth/login', {
      'email': email,
      'password': password,
    });
    return _mapSession(data);
  }

  @override
  Future<AuthSession> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final data = await api.post('/auth/register', {
      'name': name,
      'email': email,
      'password': password,
    });
    return _mapSession(data);
  }

  @override
  Future<void> logout() async {
    await guard.post('/auth/logout', {});
  }

  @override
  Future<AuthUser> me({String? accessToken}) async {
    final data = await guard.get('/auth/me');
    return AuthUser.fromJson(data);
  }

  @override
  Future<AuthSession> refresh({required String refreshToken}) async {
    final data = await api.post('/auth/refresh', {
      'refreshToken': refreshToken,
    });
    return _mapSession(data);
  }

  @override
  Future<void> requestPasswordReset({required String email}) async {
    await api.post('/auth/forgot', {'email': email});
  }

  @override
  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    await api.post('/auth/reset', {'token': token, 'password': newPassword});
  }

  AuthSession _mapSession(Map<String, Object?> json) {
    final expires = json['expiresAt'] as String?;
    return AuthSession(
      accessToken: (json['accessToken'] ?? '') as String,
      refreshToken: (json['refreshToken'] ?? '') as String,
      expiresAt: expires != null ? DateTime.tryParse(expires) : null,
    );
  }
}
