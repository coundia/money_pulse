// HTTP repository implementation for auth request and check endpoints.
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../domain/repositories/access_repository.dart';
import '../domain/entities/access_grant.dart';
import '../domain/models/access_identity.dart';

class HttpAccessRepository implements AccessRepository {
  final http.Client client;
  final Uri baseUri;

  const HttpAccessRepository({required this.client, required this.baseUri});

  @override
  Future<void> requestCode({required AccessIdentity identity}) async {
    final res = await client.post(
      baseUri.resolve('/api/auth/request-code'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(identity.toJson()),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('REQUEST_CODE_FAILED');
    }
  }

  @override
  Future<AccessGrant> verifyCode({
    required AccessIdentity identity,
    required String code,
  }) async {
    final payload = {...identity.toJson(), 'code': code};
    final res = await client.post(
      baseUri.resolve('/api/auth/check-code'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('VERIFY_CODE_FAILED');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return AccessGrant(
      email: identity.email ?? '',
      token: (data['token'] as String?) ?? '',
      grantedAt: DateTime.now(),
    );
  }
}
