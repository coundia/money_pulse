// Infrastructure: HTTP implementation for access repository.
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../onboarding/domain/repositories/access_repository.dart';
import '../../onboarding/domain/entities/access_grant.dart';

class HttpAccessRepository implements AccessRepository {
  final http.Client client;
  final Uri baseUri;

  const HttpAccessRepository({required this.client, required this.baseUri});

  @override
  Future<void> requestCode({required String email}) async {
    final res = await client.post(
      baseUri.resolve('/api/v1/access/request-code'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('REQUEST_CODE_FAILED');
    }
  }

  @override
  Future<AccessGrant> verifyCode({
    required String email,
    required String code,
  }) async {
    final res = await client.post(
      baseUri.resolve('/api/v1  '),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'code': code}),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('VERIFY_CODE_FAILED');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return AccessGrant(
      email: email,
      token: data['token'] as String,
      grantedAt:
          DateTime.tryParse(data['grantedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
