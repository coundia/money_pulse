// Product marketplace HTTP repository with unified 'log' payload and safe dev logging.

import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:developer' as dev;
import 'package:http/http.dart' as http;
import 'package:jaayko/domain/products/entities/product.dart';
import 'package:jaayko/domain/products/repositories/product_marketplace_repository.dart';
import 'package:jaayko/sync/infrastructure/sync_headers_provider.dart';

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

  Map<String, dynamic> _clientLog({
    required String endpoint,
    required String action,
    Map<String, String>? headers,
    Map<String, dynamic>? extra,
  }) {
    final now = DateTime.now().toUtc();
    return {
      'at': now.toIso8601String(),
      'tzOffsetMin': DateTime.now().timeZoneOffset.inMinutes,
      'platform': Platform.operatingSystem,
      'platformVersion': Platform.operatingSystemVersion,
      'dartVersion': Platform.version,
      'endpoint': endpoint,
      'action': action,
      'headerUser': headers?['X-User-Id'] ?? headers?['x-user-id'],
      'headerTenant': headers?['X-Tenant-Id'] ?? headers?['x-tenant-id'],
      if (extra != null) ...extra,
    };
  }

  void _devLogPayload(String name, Uri uri, Object payload) {
    try {
      final pretty = const JsonEncoder.withIndent('  ').convert(payload);
      dev.log('POST→ $uri\n$pretty', name: name);
    } catch (_) {
      dev.log('POST→ $uri\n$payload', name: name);
    }
  }

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
    } catch (_) {}
    final t = body.trim();
    if (t.startsWith('{') || t.startsWith('['))
      return 'Une erreur est survenue côté serveur.';
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

      final productMap = {
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
        'log': _clientLog(
          endpoint: '/api/v1/marketplace',
          action: 'pushToMarketplace',
          headers: headers,
          extra: {'hasImages': images.isNotEmpty},
        ),
      }..removeWhere((_, v) => v == null);

      _devLogPayload('ProductMarketplaceRepositoryHttp', uri, {
        'product': productMap,
        'files': '[${images.length} files]',
      });

      req.fields['product'] = jsonEncode(productMap);

      for (final f in images) {
        req.files.add(await http.MultipartFile.fromPath('files', f.path));
      }

      final streamed = await _http.send(req);
      final resp = await http.Response.fromStream(streamed);

      if (resp.statusCode < 200 || resp.statusCode >= 300) _throwHttp(resp);

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
    print("[#####changeRemoteStatus]");
  }
}
