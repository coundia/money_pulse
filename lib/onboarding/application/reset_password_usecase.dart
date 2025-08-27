// Use case to reset a password using a token and a new password.
import '../domain/repositories/access_repository.dart';

class ResetPasswordUseCase {
  final AccessRepository repo;
  ResetPasswordUseCase(this.repo);

  Future<void> execute(String token, String newPassword) {
    return repo.resetPassword(token, newPassword);
  }
}
