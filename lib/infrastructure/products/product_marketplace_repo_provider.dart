// Marketplace repository: push product + images as multipart/form-data
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'package:money_pulse/domain/products/entities/product.dart';

import '../../sync/infrastructure/sync_headers_provider.dart';

// Provider family pour injecter la baseUri (ex: http://127.0.0.1:8095)
final productMarketplaceRepoProvider =
    Provider.family<ProductMarketplaceRepo, String>((ref, baseUri) {
      return ProductMarketplaceRepo(ref, baseUri);
    });

class ProductMarketplaceRepo {
  final Ref ref;
  final String baseUri;
  ProductMarketplaceRepo(this.ref, this.baseUri);

  /// Envoie le produit et ses images au endpoint `/api/v1/marketplace`.
  /// - part JSON  "product" (Content-Type: application/json)
  /// - parts files "files"   (image/jpeg|png|gif|webp)
  Future<void> pushToMarketplace(Product product, List<File> images) async {
    if (images.isEmpty) {
      throw ArgumentError('Aucune image fournie');
    }

    final uri = Uri.parse(_join(baseUri, '/api/v1/marketplace'));
    final req = http.MultipartRequest('POST', uri);

    // En-têtes globaux : on retire Content-Type (MultipartRequest gère boundary)
    final baseHeaders = ref.read(syncHeaderBuilderProvider)();
    final headers = Map<String, String>.from(baseHeaders)
      ..remove('Content-Type');
    req.headers.addAll(headers);

    // ---- PART JSON "product" en application/json (clé attendue par @RequestPart("product"))
    final productMap = _buildProductMap(product);
    req.files.add(
      http.MultipartFile.fromString(
        'product',
        jsonEncode(productMap),
        filename: 'product.json',
        contentType: MediaType('application', 'json'),
      ),
    );

    // ---- PARTS "files" (images)
    for (final file in images) {
      if (!await file.exists()) continue;
      final mime = _mimeFromPath(file.path);
      req.files.add(
        await http.MultipartFile.fromPath(
          'files',
          file.path,
          contentType: MediaType.parse(mime),
        ),
      );
    }

    // Envoi
    final streamed = await req.send();
    final resp = await http.Response.fromStream(streamed);

    // 2xx OK, sinon on remonte l’erreur avec le body
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw HttpException(
        'HTTP ${resp.statusCode} ${resp.reasonPhrase ?? ''} • ${resp.body}',
        uri: uri,
      );
    }
  }

  // ---- Helpers ----

  // Construit le JSON pour la part "product"
  Map<String, dynamic> _buildProductMap(Product p) {
    final map = <String, dynamic>{
      'remoteId': p.remoteId,
      'localId': p.id,
      'code': p.code ?? p.id,
      'name': p.name ?? p.code ?? 'Produit',
      'description': p.description,
      'barcode': p.barcode,
      'unit': p.unitId,
      'syncAt': DateTime.now().toUtc().toIso8601String(),
      'category': p.categoryId,
      // 'account': p.account, // dé-commente si présent dans ton modèle
      'defaultPrice': (p.defaultPrice / 100.0),
      'statuses': p.statuses,
      'purchasePrice': (p.purchasePrice / 100.0),
    };

    // Nettoyage des nulls
    map.removeWhere((_, v) => v == null);
    return map;
  }

  String _mimeFromPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.webp')) return 'image/webp';
    // On reste sur image/jpeg par défaut pour éviter application/octet-stream que ton serveur n'accepte pas
    return 'image/jpeg';
  }

  String _join(String base, String path) {
    final b = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    final p = path.startsWith('/') ? path : '/$path';
    return '$b$p';
  }
}
