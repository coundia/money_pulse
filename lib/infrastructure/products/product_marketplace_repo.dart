// Marketplace repo: publish/unpublish product, persist remoteId/status using response body (product.id) or headers/URLs.
import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:money_pulse/domain/products/entities/product.dart';
import 'package:money_pulse/domain/products/repositories/product_repository.dart';
import 'package:money_pulse/presentation/features/products/product_repo_provider.dart';
import '../../sync/infrastructure/sync_headers_provider.dart';

class ProductMarketplaceRepo {
  final Ref ref;
  final String baseUri;
  ProductMarketplaceRepo(this.ref, this.baseUri);

  Future<Product> pushToMarketplace(Product product, List<File> images) async {
    if (images.isEmpty) {
      throw ArgumentError('Aucune image fournie');
    }
    if ((product.remoteId ?? '').trim().isNotEmpty ||
        product.statuses == 'PUBLISHED') {
      throw StateError('Le produit est déjà publié');
    }

    final uri = Uri.parse(_join(baseUri, '/api/v1/marketplace'));
    final req = http.MultipartRequest('POST', uri);

    final baseHeaders = ref.read(syncHeaderBuilderProvider)();
    final headers = Map<String, String>.from(baseHeaders)
      ..remove('Content-Type');
    req.headers.addAll(headers);

    final map = _buildProductMap(product);
    req.files.add(
      http.MultipartFile.fromString(
        'product',
        jsonEncode(map),
        filename: 'product.json',
        contentType: MediaType('application', 'json'),
      ),
    );

    for (final f in images) {
      if (!await f.exists()) continue;
      final mime = _mimeFromPath(f.path);
      req.files.add(
        await http.MultipartFile.fromPath(
          'files',
          f.path,
          contentType: MediaType.parse(mime),
        ),
      );
    }

    final streamed = await req.send().timeout(const Duration(seconds: 45));
    final resp = await http.Response.fromStream(streamed);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw HttpException(
        'HTTP ${resp.statusCode} ${resp.reasonPhrase ?? ''} • ${resp.body}',
        uri: uri,
      );
    }

    final remoteId =
        _parseRemoteIdFromBody(resp.body) ??
        _parseRemoteIdFromHeaders(streamed.headers);

    final updated = product.copyWith(
      remoteId: (remoteId ?? '').isEmpty ? product.remoteId : remoteId,
      statuses: 'PUBLISHED',
      updatedAt: DateTime.now(),
      isDirty: 1,
    );

    final productRepo = ref.read(productRepoProvider);
    await productRepo.update(updated);
    return updated;
  }

  Future<Product> changeRemoteStatus({
    required Product product,
    required String statusesCode,
  }) async {
    final remoteId = (product.remoteId ?? '').trim();
    if (remoteId.isEmpty) {
      throw StateError('remoteId manquant pour ce produit');
    }

    final uri = Uri.parse(_join(baseUri, '/api/v1/commands/product/$remoteId'));
    final headers = <String, String>{
      ...ref.read(syncHeaderBuilderProvider)(),
      'Content-Type': 'application/json',
      'accept': 'application/json',
    };

    final body = jsonEncode(
      {
        'remoteId': product.remoteId,
        'localId': product.localId ?? product.id,
        'code': product.code ?? product.id,
        'name': product.name ?? product.code ?? 'Produit',
        'description': product.description,
        'barcode': product.barcode,
        'unit': product.unitId,
        'syncAt': DateTime.now().toUtc().toIso8601String(),
        'category': product.categoryId,
        'account': product.account,
        'defaultPrice': product.defaultPrice / 100.0,
        'statuses': statusesCode,
        'purchasePrice': product.purchasePrice / 100.0,
      }..removeWhere((k, v) => v == null),
    );

    final resp = await http.put(uri, headers: headers, body: body);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw HttpException(
        'HTTP ${resp.statusCode} ${resp.reasonPhrase ?? ''} • ${resp.body}',
        uri: uri,
      );
    }

    final updated = product.copyWith(
      statuses: statusesCode,
      updatedAt: DateTime.now(),
      isDirty: 1,
    );
    final productRepo = ref.read(productRepoProvider);
    await productRepo.update(updated);
    return updated;
  }

  Future<Product> withdrawPublicationWithApi({
    required Product product,
    required String statusesCode,
  }) {
    return changeRemoteStatus(product: product, statusesCode: statusesCode);
  }

  Map<String, dynamic> _buildProductMap(Product p) {
    final map = <String, dynamic>{
      'remoteId': p.remoteId,
      'localId': p.localId ?? p.id,
      'code': p.code ?? p.id,
      'name': p.name ?? p.code ?? 'Produit',
      'description': p.description,
      'barcode': p.barcode,
      'unit': p.unitId,
      'syncAt': DateTime.now().toUtc().toIso8601String(),
      'category': p.categoryId,
      'account': p.account,
      'defaultPrice': p.defaultPrice / 100.0,
      'statuses': "PUBLISH",
      'purchasePrice': p.purchasePrice / 100.0,
    };
    map.removeWhere((_, v) => v == null);
    return map;
  }

  String _mimeFromPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  String _join(String base, String path) {
    final b = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    final p = path.startsWith('/') ? path : '/$path';
    return '$b$p';
  }

  String? _parseRemoteIdFromBody(String body) {
    try {
      final d = json.decode(body);
      if (d is Map<String, dynamic>) {
        if (d['product'] is Map<String, dynamic>) {
          final p = d['product'] as Map<String, dynamic>;
          final v1 = (p['remoteId'] ?? '').toString().trim();
          if (v1.isNotEmpty) return v1;
          final v2 = (p['id'] ?? '').toString().trim();
          if (v2.isNotEmpty) return v2;
        }
        final v0 = (d['remoteId'] ?? d['id'] ?? '').toString().trim();
        if (v0.isNotEmpty) return v0;
        if (d['data'] is Map<String, dynamic>) {
          final m = d['data'] as Map<String, dynamic>;
          final v = (m['id'] ?? m['remoteId'] ?? '').toString().trim();
          if (v.isNotEmpty) return v;
        }
        if (d['result'] is Map<String, dynamic>) {
          final m = d['result'] as Map<String, dynamic>;
          final v = (m['id'] ?? m['remoteId'] ?? '').toString().trim();
          if (v.isNotEmpty) return v;
        }
        if (d['images'] is List && (d['images'] as List).isNotEmpty) {
          final first = (d['images'] as List).first;
          if (first is Map<String, dynamic>) {
            final url = (first['url'] ?? '').toString();
            final fromUrl = _extractIdFromPublicUrl(url);
            if (fromUrl != null && fromUrl.isNotEmpty) return fromUrl;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  String? _parseRemoteIdFromHeaders(Map<String, String> headers) {
    final loc = headers['location'] ?? headers['Location'];
    if (loc == null || loc.isEmpty) return null;
    final parts = loc.split('/');
    return parts.isNotEmpty ? parts.last.trim() : null;
  }

  String? _extractIdFromPublicUrl(String url) {
    final idx = url.indexOf('/products/');
    if (idx == -1) return null;
    final after = url.substring(idx + '/products/'.length);
    final segs = after.split('/');
    if (segs.isEmpty) return null;
    return segs.first.trim();
  }

  Future<void> deleteRemote(Product product) async {
    final remoteId = (product.remoteId ?? '').trim();
    if (remoteId.isEmpty) {
      throw StateError('remoteId manquant pour ce produit');
    }

    final uri = Uri.parse(_join(baseUri, '/api/v1/commands/product/$remoteId'));

    final headers = <String, String>{
      ...ref.read(syncHeaderBuilderProvider)(), // doit contenir Authorization
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };

    final resp = await http.delete(uri, headers: headers);

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw HttpException(
        'HTTP ${resp.statusCode} ${resp.reasonPhrase ?? ''} • ${resp.body}',
        uri: uri,
      );
    }
  }
}
