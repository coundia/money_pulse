// HTTP client for /api/auth/refresh using only Authorization header; returns updated AccessGrant.
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../domain/entities/access_grant.dart';

class TokenRefreshApi {
  final http.Client client;
  final Uri baseUri;

  const TokenRefreshApi({required this.client, required this.baseUri});

  Future<AccessGrant> refresh(AccessGrant current) async {
    final uri = baseUri.resolve('/api/auth/refresh');
    final res = await client.post(
      uri,
      headers: {'accept': '*/*', 'Authorization': 'Bearer ${current.token}'},
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('refresh_failed_http_${res.statusCode}');
    }

    final map = jsonDecode(res.body) as Map<String, dynamic>;
    final code = map['code'] is num ? (map['code'] as num).toInt() : -1;
    final token = map['token']?.toString() ?? '';
    if (code != 1 || token.isEmpty) {
      throw Exception('refresh_invalid_payload');
    }

    final now = DateTime.now().toUtc();
    final username = map['username']?.toString();
    final expirationAt = map['expirationAt']?.toString();
    final id = map['id']?.toString();

    return current.copyWith(
      token: token,
      grantedAt: now,
      username: (username == null || username.isEmpty)
          ? current.username
          : username,
      expiresAt: expirationAt ?? current.expiresAt,
      id: id?.isNotEmpty == true ? id : current.id,
    );
  }
}
