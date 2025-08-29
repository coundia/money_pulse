// HTTP repository implementation for auth request and check endpoints.
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../domain/repositories/access_repository.dart';
import '../domain/entities/access_grant.dart';
import '../domain/models/access_identity.dart';

class HttpAccessRepository implements AccessRepository {
  final http.Client client;
  final Uri baseUri;

  Uri _uri(String path) => baseUri.resolve(path);

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
    print("connected #### respone");
    print(data);
    return AccessGrant(
      email: identity.email ?? '',
      token: (data['token'] as String?) ?? '',
      grantedAt: DateTime.now(),
      username: (data['username'] as String?) ?? identity.email,
      phone: (data['phone'] as String?) ?? identity.email,
    );
  }

  @override
  Future<AccessGrant> login(String username, String password) async {
    final res = await client.post(
      _uri('/api/auth/login'),
      headers: {'Content-Type': 'application/json', 'accept': '*/*'},
      body: jsonEncode({'username': username, 'password': password}),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('login failed');
    }
    final map = jsonDecode(res.body) as Map<String, dynamic>;
    print("connected #### respone");
    print(map);
    final code = map['code'] is num ? (map['code'] as num).toInt() : -1;
    final token = map['token']?.toString() ?? '';
    final uname = map['username']?.toString() ?? username;
    if (code != 1 || token.isEmpty) throw Exception('login invalid response');
    return AccessGrant(
      email: uname,
      token: token,
      grantedAt: DateTime.now().toUtc(),
      username: (map['username'] as String?) ?? uname,
      phone: (map['phone'] as String?) ?? uname,
    );
  }

  @override
  Future<void> forgotPassword(String username) async {
    final res = await client.post(
      _uri('/api/auth/forgot-password'),
      headers: {'Content-Type': 'application/json', 'accept': '*/*'},
      body: jsonEncode({'username': username}),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('forgotPassword failed');
    }
  }

  @override
  Future<void> resetPassword(String token, String newPassword) async {
    final res = await client.post(
      _uri('/api/auth/reset-password'),
      headers: {'Content-Type': 'application/json', 'accept': '*/*'},
      body: jsonEncode({'token': token, 'newPassword': newPassword}),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('resetPassword failed');
    }
  }
}
