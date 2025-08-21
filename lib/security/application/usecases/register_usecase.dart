/// Use case to perform registration and persist session.
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/secure_token_store.dart';
import '../../domain/entities/auth_session.dart';

class RegisterUseCase {
  final AuthRepository authRepository;
  final SecureTokenStore tokenStore;

  RegisterUseCase(this.authRepository, this.tokenStore);

  Future<AuthSession> execute({
    required String name,
    required String email,
    required String password,
  }) async {
    final session = await authRepository.register(
      name: name,
      email: email,
      password: password,
    );
    await tokenStore.write(session);
    return session;
  }
}
