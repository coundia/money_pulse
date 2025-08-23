// Application use case to verify code and obtain grant.
import '../domain/repositories/access_repository.dart';
import '../domain/entities/access_grant.dart';
import '../domain/models/access_identity.dart';

class VerifyAccessUseCase {
  final AccessRepository repo;
  const VerifyAccessUseCase(this.repo);

  Future<AccessGrant> execute(AccessIdentity identity, String code) {
    return repo.verifyCode(identity: identity, code: code);
  }
}
