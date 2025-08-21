/// Use case to perform login and persist session.
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/secure_token_store.dart';
import '../../domain/entities/auth_session.dart';

class LoginUseCase {
  final AuthRepository authRepository;
  final SecureTokenStore tokenStore;

  LoginUseCase(this.authRepository, this.tokenStore);

  Future<AuthSession> execute({
    required String email,
    required String password,
  }) async {
    final session = await authRepository.login(
      email: email,
      password: password,
    );
    await tokenStore.write(session);
    return session;
  }
}
