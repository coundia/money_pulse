/// Use case to perform logout and clear session.
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/secure_token_store.dart';

class LogoutUseCase {
  final AuthRepository authRepository;
  final SecureTokenStore tokenStore;

  LogoutUseCase(this.authRepository, this.tokenStore);

  Future<void> execute() async {
    try {
      await authRepository.logout();
    } finally {
      await tokenStore.clear();
    }
  }
}
