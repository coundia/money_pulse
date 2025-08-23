// Application use case to request an access code.
import '../domain/repositories/access_repository.dart';
import '../domain/models/access_identity.dart';

class RequestAccessUseCase {
  final AccessRepository repo;
  const RequestAccessUseCase(this.repo);

  Future<void> execute(AccessIdentity identity) {
    return repo.requestCode(identity: identity);
  }
}
