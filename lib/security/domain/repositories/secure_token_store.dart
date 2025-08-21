/// Contract for securely persisting and reading session tokens.
import '../entities/auth_session.dart';

abstract class SecureTokenStore {
  Future<void> write(AuthSession session);
  Future<AuthSession?> read();
  Future<void> clear();
}
