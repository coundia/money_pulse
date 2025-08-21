/// Use case to refresh session and persist it.
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/secure_token_store.dart';
import '../../domain/entities/auth_session.dart';

class RefreshTokenUseCase {
  final AuthRepository authRepository;
  final SecureTokenStore tokenStore;

  RefreshTokenUseCase(this.authRepository, this.tokenStore);

  Future<AuthSession> execute(String refreshToken) async {
    final session = await authRepository.refresh(refreshToken: refreshToken);
    await tokenStore.write(session);
    return session;
  }
}
