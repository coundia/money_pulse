// Application use case: request a confirmation code sent to user's email.

import '../domain/repositories/access_repository.dart';

class RequestAccessUseCase {
  final AccessRepository repo;
  const RequestAccessUseCase(this.repo);

  Future<void> execute(String email) {
    return repo.requestCode(email: email.trim());
  }
}
