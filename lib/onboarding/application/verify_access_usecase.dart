// Application use case: verify the confirmation code and return an access grant.

import '../domain/entities/access_grant.dart';
import '../domain/repositories/access_repository.dart';

class VerifyAccessUseCase {
  final AccessRepository repo;
  const VerifyAccessUseCase(this.repo);

  Future<AccessGrant> execute(String email, String code) {
    return repo.verifyCode(email: email.trim(), code: code.trim());
  }
}
