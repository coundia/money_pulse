/// Use case to confirm password reset using token and new password.
import '../../domain/repositories/auth_repository.dart';

class ConfirmPasswordResetUseCase {
  final AuthRepository authRepository;
  ConfirmPasswordResetUseCase(this.authRepository);

  Future<void> execute({required String token, required String newPassword}) {
    return authRepository.resetPassword(token: token, newPassword: newPassword);
  }
}
