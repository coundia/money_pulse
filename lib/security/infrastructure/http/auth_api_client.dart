/// Low-level HTTP client for auth endpoints with basic error mapping.
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'http_exceptions.dart';

class AuthApiClient {
  final String baseUrl;
  final http.Client _http;

  AuthApiClient({required this.baseUrl, http.Client? httpClient})
    : _http = httpClient ?? http.Client();

  Future<Map<String, Object?>> post(
    String path,
    Map<String, Object?> body, {
    Map<String, String>? headers,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final res = await _http.post(
      uri,
      headers: {'Content-Type': 'application/json', ...?headers},
      body: jsonEncode(body),
    );
    return _map(res);
  }

  Future<Map<String, Object?>> get(
    String path, {
    Map<String, String>? headers,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final res = await _http.get(uri, headers: headers);
    return _map(res);
  }

  Map<String, Object?> _map(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final dynamic decoded = res.body.isEmpty ? {} : jsonDecode(res.body);
      if (decoded is Map) return decoded.cast<String, Object?>();
      return {'data': decoded};
    }
    if (res.statusCode == 401) {
      throw HttpUnauthorizedException(message: res.body);
    }
    throw HttpError(res.statusCode, message: res.body);
  }
}
