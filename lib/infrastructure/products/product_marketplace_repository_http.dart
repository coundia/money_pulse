// product_marketplace_repository_http.dart
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:money_pulse/domain/products/entities/product.dart';
import 'package:money_pulse/domain/products/repositories/product_marketplace_repository.dart';
import 'package:money_pulse/sync/infrastructure/sync_headers_provider.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, [this.statusCode]);
  @override
  String toString() => message;
}

class ProductMarketplaceRepositoryHttp implements ProductMarketplaceRepository {
  final String baseUri;
  final http.Client _http;
  final HeaderBuilder _headers;

  ProductMarketplaceRepositoryHttp(this.baseUri, this._http, this._headers);

  String _extractApiMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        for (final k in ['message', 'error', 'detail', 'description']) {
          final v = decoded[k];
          if (v != null && v.toString().trim().isNotEmpty) {
            return v.toString().trim();
          }
        }
        final errs = decoded['errors'];
        if (errs is List && errs.isNotEmpty) {
          final first = errs.first.toString().trim();
          if (first.isNotEmpty) return first;
        }
      } else if (decoded is List && decoded.isNotEmpty) {
        final first = decoded.first.toString().trim();
        if (first.isNotEmpty) return first;
      }
    } catch (_) {
      /* ignore parse errors */
    }

    final t = body.trim();
    if (t.startsWith('{') || t.startsWith('[')) {
      return 'Une erreur est survenue côté serveur.';
    }
    return t.isEmpty ? 'Une erreur est survenue côté serveur.' : t;
  }

  Never _throwHttp(http.Response resp) {
    final msg = _extractApiMessage(resp.body);
    throw ApiException('(${resp.statusCode}) $msg', resp.statusCode);
  }

  @override
  Future<Product> pushToMarketplace(Product product, List<File> images) async {
    final uri = Uri.parse('$baseUri/api/v1/marketplace');
    final req = http.MultipartRequest('POST', uri);

    try {
      final headers = _headers();
      req.headers.addAll(headers..remove('Content-Type'));

      req.fields['product'] = jsonEncode({
        'remoteId': product.remoteId,
        'localId': product.localId,
        'code': product.code,
        'name': product.name,
        'description': product.description,
        'barcode': product.barcode,
        'syncAt': product.syncAt?.toIso8601String(),
        'category': product.categoryId,
        'account': product.account,
        'defaultPrice': product.defaultPrice,
        'statuses': product.statuses,
        'purchasePrice': product.purchasePrice,
      });

      for (final f in images) {
        req.files.add(await http.MultipartFile.fromPath('files', f.path));
      }

      final streamed = await _http.send(req);
      final resp = await http.Response.fromStream(streamed);

      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        _throwHttp(resp);
      }

      // Return product possibly enriched by the server response
      try {
        final body = jsonDecode(resp.body);
        if (body is Map<String, dynamic>) {
          final remoteId = (body['remoteId'] ?? body['id'] ?? '').toString();
          final statuses = (body['statuses'] ?? product.statuses)?.toString();
          return product.copyWith(
            remoteId: remoteId.isNotEmpty ? remoteId : product.remoteId,
            statuses: statuses,
          );
        }
      } catch (_) {}
      return product;
    } on SocketException {
      throw ApiException(
        'Impossible de se connecter au serveur. Vérifiez votre connexion.',
      );
    } on TimeoutException {
      throw ApiException('Délai dépassé. Réessayez plus tard.');
    }
  }

  @override
  Future<void> changeRemoteStatus({
    required Product product,
    required String statusesCode,
  }) async {
    final uri = Uri.parse(
      '$baseUri/api/v1/marketplace/${product.remoteId}/status',
    );
    final headers = _headers();
    try {
      final resp = await _http.post(
        uri,
        headers: {...headers, 'Content-Type': 'application/json'},
        body: jsonEncode({'statuses': statusesCode}),
      );
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        _throwHttp(resp);
      }
    } on SocketException {
      throw ApiException(
        'Impossible de se connecter au serveur. Vérifiez votre connexion.',
      );
    } on TimeoutException {
      throw ApiException('Délai dépassé. Réessayez plus tard.');
    }
  }
}
