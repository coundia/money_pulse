// Repository interface for requesting and verifying access codes.
import '../entities/access_grant.dart';
import '../models/access_identity.dart';

abstract class AccessRepository {
  Future<void> requestCode({required AccessIdentity identity});
  Future<AccessGrant> verifyCode({
    required AccessIdentity identity,
    required String code,
  });
}
