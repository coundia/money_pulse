// Use case to register a user with username and password.
import '../onboarding/domain/repositories/access_repository.dart';

class RegisterWithPasswordUseCase {
  final AccessRepository repo;
  RegisterWithPasswordUseCase(this.repo);

  Future<void> execute(String username, String password) {
    return repo.register(username: username, password: password);
  }
}
