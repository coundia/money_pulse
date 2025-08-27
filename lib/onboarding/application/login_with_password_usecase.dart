// Use case to login with username and password returning an AccessGrant.
import '../domain/entities/access_grant.dart';
import '../domain/repositories/access_repository.dart';

class LoginWithPasswordUseCase {
  final AccessRepository repo;
  LoginWithPasswordUseCase(this.repo);

  Future<AccessGrant> execute(String username, String password) {
    return repo.login(username, password);
  }
}
