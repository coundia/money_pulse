// Repository interface for requesting and verifying access codes.
import '../entities/access_grant.dart';
import '../models/access_identity.dart';

abstract class AccessRepository {
  Future<void> requestCode({required AccessIdentity identity});
  Future<AccessGrant> verifyCode({
    required AccessIdentity identity,
    required String code,
  });

  Future<AccessGrant> login(String username, String password);
  Future<void> forgotPassword(String username);
  Future<void> resetPassword(String token, String newPassword);

  Future<AccessGrant> register({
    required String username,
    required String password,
  });
}
