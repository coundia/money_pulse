/// Helper that injects Authorization header and auto-refreshes on 401 once.
import '../../domain/entities/auth_session.dart';
import '../../domain/repositories/secure_token_store.dart';
import '../../application/usecases/refresh_token_usecase.dart';
import 'auth_api_client.dart';
import 'http_exceptions.dart';

typedef AuthedCall =
    Future<Map<String, Object?>> Function(Map<String, String> headers);

class AuthHttpGuard {
  final SecureTokenStore tokenStore;
  final RefreshTokenUseCase refreshUseCase;
  final AuthApiClient api;

  AuthHttpGuard({
    required this.tokenStore,
    required this.refreshUseCase,
    required this.api,
  });

  Future<Map<String, Object?>> get(String path) async {
    return _run((headers) => api.get(path, headers: headers));
  }

  Future<Map<String, Object?>> post(
    String path,
    Map<String, Object?> body,
  ) async {
    return _run((headers) => api.post(path, body, headers: headers));
  }

  Future<Map<String, Object?>> _run(AuthedCall call) async {
    AuthSession? session = await tokenStore.read();
    final headers = <String, String>{};
    if (session != null && session.accessToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer ${session.accessToken}';
    }
    try {
      return await call(headers);
    } on HttpUnauthorizedException {
      if (session == null || session.refreshToken.isEmpty) rethrow;
      final newSession = await refreshUseCase.execute(session.refreshToken);
      session = newSession;
      headers['Authorization'] = 'Bearer ${newSession.accessToken}';
      return await call(headers);
    }
  }
}
