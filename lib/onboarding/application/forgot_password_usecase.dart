// Use case to request a password reset link or code for a given username.
import '../domain/repositories/access_repository.dart';

class ForgotPasswordUseCase {
  final AccessRepository repo;
  ForgotPasswordUseCase(this.repo);

  Future<void> execute(String username) {
    return repo.forgotPassword(username);
  }
}
