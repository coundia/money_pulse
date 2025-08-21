/// Use case to request a password reset link by email.
import '../../domain/repositories/auth_repository.dart';

class RequestPasswordResetUseCase {
  final AuthRepository authRepository;
  RequestPasswordResetUseCase(this.authRepository);

  Future<void> execute({required String email}) {
    return authRepository.requestPasswordReset(email: email);
  }
}
