// HTTP repository with rich error propagation for server messages.
import 'dart:convert';
import 'dart:developer' as dev;
import 'package:http/http.dart' as http;
import '../domain/repositories/access_repository.dart';
import '../domain/entities/access_grant.dart';
import '../domain/models/access_identity.dart';
import 'api_error.dart';

class HttpAccessRepository implements AccessRepository {
  final http.Client client;
  final Uri baseUri;

  Uri _uri(String path) => baseUri.resolve(path);

  const HttpAccessRepository({required this.client, required this.baseUri});

  @override
  Future<void> requestCode({required AccessIdentity identity}) async {
    final uri = baseUri.resolve('/api/auth/request-code');
    final res = await client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(identity.toJson()),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final msg = _extractMessage(res.body) ?? 'REQUEST_CODE_FAILED';
      _logHttpError(
        'requestCode',
        uri.toString(),
        res.statusCode,
        msg,
        res.body,
      );
      throw ApiError(status: res.statusCode, message: msg, raw: res.body);
    }
  }

  @override
  Future<AccessGrant> register({
    required String username,
    required String password,
  }) async {
    final uri = baseUri.resolve('/api/auth/register');
    final res = await client.post(
      uri,
      headers: {'Content-Type': 'application/json', 'accept': '*/*'},
      body: jsonEncode({'username': username, 'password': password}),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      final msg = _extractMessage(res.body) ?? 'register_failed';
      _logHttpError('register', uri.toString(), res.statusCode, msg, res.body);
      throw ApiError(status: res.statusCode, message: msg, raw: res.body);
    }

    final map = _safeDecode(res.body);
    final token = (map['token'] ?? '') as String;
    final id = (map['id'] ?? '') as String;
    final u = (map['username'] ?? username) as String;
    final expIso = (map['expirationAt'] ?? '') as String;
    final grantedAt = DateTime.now();
    final email = u.contains('@') ? u : '';
    final at = expIso.isNotEmpty
        ? DateTime.tryParse(expIso) ?? grantedAt
        : grantedAt;

    return AccessGrant(
      email: email,
      username: u,
      token: token,
      grantedAt: grantedAt,
      phone: null,
      expiresAt: at.toString(),
      id: id,
    );
  }

  @override
  Future<AccessGrant> verifyCode({
    required AccessIdentity identity,
    required String code,
  }) async {
    final uri = baseUri.resolve('/api/auth/check-code');
    final payload = {...identity.toJson(), 'code': code};
    final res = await client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final msg = _extractMessage(res.body) ?? 'VERIFY_CODE_FAILED';
      _logHttpError(
        'verifyCode',
        uri.toString(),
        res.statusCode,
        msg,
        res.body,
      );
      throw ApiError(status: res.statusCode, message: msg, raw: res.body);
    }
    final data = _safeDecode(res.body);
    return AccessGrant(
      email: identity.email ?? '',
      token: (data['token'] as String?) ?? '',
      id: (data['id'] as String?) ?? '',
      grantedAt: DateTime.now(),
      username: (data['username'] as String?) ?? identity.email,
      phone: (data['phone'] as String?) ?? identity.email,
    );
  }

  @override
  Future<AccessGrant> login(String username, String password) async {
    final uri = _uri('/api/auth/login');
    final res = await client.post(
      uri,
      headers: {'Content-Type': 'application/json', 'accept': '*/*'},
      body: jsonEncode({'username': username, 'password': password}),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final msg = _extractMessage(res.body) ?? 'login_failed';
      _logHttpError('login', uri.toString(), res.statusCode, msg, res.body);
      throw ApiError(status: res.statusCode, message: msg, raw: res.body);
    }
    final map = _safeDecode(res.body);
    final code = map['code'] is num ? (map['code'] as num).toInt() : -1;
    final token = map['token']?.toString() ?? '';
    final uname = map['username']?.toString() ?? username;
    if (code != 1 || token.isEmpty) {
      final msg = _extractMessage(res.body) ?? 'login invalid response';
      _logHttpError(
        'login_payload',
        uri.toString(),
        res.statusCode,
        msg,
        res.body,
      );
      throw ApiError(
        status: res.statusCode,
        message: msg,
        raw: res.body,
        code: code,
      );
    }
    return AccessGrant(
      email: uname,
      token: token,
      grantedAt: DateTime.now().toUtc(),
      username: (map['username'] as String?) ?? uname,
      phone: (map['phone'] as String?) ?? uname,
      id: (map['id'] as String?) ?? "",
    );
  }

  @override
  Future<void> forgotPassword(String username) async {
    final uri = _uri('/api/auth/forgot-password');
    final res = await client.post(
      uri,
      headers: {'Content-Type': 'application/json', 'accept': '*/*'},
      body: jsonEncode({'username': username}),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final msg = _extractMessage(res.body) ?? 'forgotPassword failed';
      _logHttpError(
        'forgotPassword',
        uri.toString(),
        res.statusCode,
        msg,
        res.body,
      );
      throw ApiError(status: res.statusCode, message: msg, raw: res.body);
    }
  }

  @override
  Future<void> resetPassword(String token, String newPassword) async {
    final uri = _uri('/api/auth/reset-password');
    final res = await client.post(
      uri,
      headers: {'Content-Type': 'application/json', 'accept': '*/*'},
      body: jsonEncode({'token': token, 'newPassword': newPassword}),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final msg = _extractMessage(res.body) ?? 'resetPassword failed';
      _logHttpError(
        'resetPassword',
        uri.toString(),
        res.statusCode,
        msg,
        res.body,
      );
      throw ApiError(status: res.statusCode, message: msg, raw: res.body);
    }
  }

  Map<String, dynamic> _safeDecode(String body) {
    try {
      final map = jsonDecode(body);
      if (map is Map<String, dynamic>) return map;
      return <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  String? _extractMessage(String body) {
    try {
      final map = jsonDecode(body);
      if (map is Map && map['message'] is String) {
        return map['message'] as String;
      }
    } catch (_) {}
    if (body.trim().isEmpty) return null;
    return body.length > 280 ? '${body.substring(0, 280)}…' : body;
  }

  void _logHttpError(
    String op,
    String url,
    int status,
    String msg,
    String body,
  ) {
    final snippet = body.length > 512 ? '${body.substring(0, 512)}…' : body;
    dev.log(
      'HTTP error',
      name: 'HttpAccessRepository.$op',
      error: {'url': url, 'status': status, 'message': msg, 'body': snippet},
    );
  }
}
