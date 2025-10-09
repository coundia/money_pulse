// HTTP client for /api/auth/refresh with structured logging; avoids leaking full token.
import 'dart:convert';
import 'dart:developer' as dev;
import 'package:http/http.dart' as http;
import '../domain/entities/access_grant.dart';

class TokenRefreshApi {
  final http.Client client;
  final Uri baseUri;

  const TokenRefreshApi({required this.client, required this.baseUri});

  Future<AccessGrant> refresh(AccessGrant current) async {
    print("[refreshTokenUseCaseProvider]");

    final uri = baseUri.resolve('/api/auth/refresh');

    final masked = current.token.length <= 10
        ? '***'
        : '${current.token.substring(0, 6)}…${current.token.substring(current.token.length - 4)}';

    dev.log(
      'Refreshing token',
      name: 'TokenRefreshApi',
      time: DateTime.now(),
      error: {
        'url': uri.toString(),
        'auth': 'Bearer $masked',
        'username': current.username,
        'expiresAt_prev': current.expiresAt,
      },
    );

    http.Response res;
    try {
      res = await client.post(
        uri,
        headers: {'accept': '*/*', 'Authorization': 'Bearer ${current.token}'},
      );
    } catch (e, st) {
      dev.log(
        'HTTP call failed',
        name: 'TokenRefreshApi',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }

    dev.log(
      'HTTP response',
      name: 'TokenRefreshApi',
      error: {
        'status': res.statusCode,
        'ok': res.statusCode >= 200 && res.statusCode < 300,
        'len': res.bodyBytes.length,
      },
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      final snippet = res.body.length > 280
          ? '${res.body.substring(0, 280)}…'
          : res.body;
      dev.log('Non-2xx response body', name: 'TokenRefreshApi', error: snippet);
      throw Exception('refresh_failed_http_${res.statusCode}');
    }

    Map<String, dynamic> map;
    try {
      map = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (e, st) {
      dev.log(
        'JSON parse error',
        name: 'TokenRefreshApi',
        error: e,
        stackTrace: st,
      );
      throw Exception('refresh_invalid_json');
    }

    final code = map['code'] is num ? (map['code'] as num).toInt() : -1;
    final token = map['token']?.toString() ?? '';
    if (code != 1 || token.isEmpty) {
      dev.log(
        'Invalid payload',
        name: 'TokenRefreshApi',
        error: {'code': code, 'hasToken': token.isNotEmpty},
      );
      throw Exception('refresh_invalid_payload');
    }

    final now = DateTime.now().toUtc();
    final username = map['username']?.toString();
    final expirationAt = map['expirationAt']?.toString();
    final id = map['id']?.toString();

    final updated = current.copyWith(
      token: token,
      grantedAt: now,
      username: (username == null || username.isEmpty)
          ? current.username
          : username,
      expiresAt: expirationAt ?? current.expiresAt,
      id: (id != null && id.isNotEmpty) ? id : current.id,
    );

    dev.log(
      'Token refreshed',
      name: 'TokenRefreshApi',
      error: {
        'username': updated.username,
        'expiresAt_new': updated.expiresAt,
        'grantedAt': updated.grantedAt.toIso8601String(),
      },
    );

    return updated;
  }
}
