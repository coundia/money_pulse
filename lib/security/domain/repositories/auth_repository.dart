/// Domain repository contract for authentication workflows.
import '../entities/auth_user.dart';
import '../entities/auth_session.dart';

abstract class AuthRepository {
  Future<AuthSession> login({required String email, required String password});
  Future<AuthSession> register({
    required String name,
    required String email,
    required String password,
  });
  Future<void> logout();
  Future<AuthUser> me({String? accessToken});
  Future<AuthSession> refresh({required String refreshToken});
  Future<void> requestPasswordReset({required String email});
  Future<void> resetPassword({
    required String token,
    required String newPassword,
  });
}
