/// In-memory fallback token store useful for tests and web.
import '../../domain/entities/auth_session.dart';
import '../../domain/repositories/secure_token_store.dart';

class SecureTokenStoreMem implements SecureTokenStore {
  AuthSession? _session;

  @override
  Future<void> clear() async {
    _session = null;
  }

  @override
  Future<AuthSession?> read() async {
    return _session;
  }

  @override
  Future<void> write(AuthSession session) async {
    _session = session;
  }
}
