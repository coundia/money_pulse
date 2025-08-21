/// Use case to retrieve the current authenticated user.
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/secure_token_store.dart';
import '../../domain/entities/auth_user.dart';

class GetCurrentUserUseCase {
  final AuthRepository authRepository;
  final SecureTokenStore tokenStore;

  GetCurrentUserUseCase(this.authRepository, this.tokenStore);

  Future<AuthUser?> execute() async {
    final session = await tokenStore.read();
    if (session == null) return null;
    final user = await authRepository.me(accessToken: session.accessToken);
    return user;
  }
}
