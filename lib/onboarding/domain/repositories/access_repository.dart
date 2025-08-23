// Domain abstraction: access repository for requesting and verifying codes.
import '../entities/access_grant.dart';

abstract class AccessRepository {
  Future<void> requestCode({required String email});
  Future<AccessGrant> verifyCode({required String email, required String code});
}
