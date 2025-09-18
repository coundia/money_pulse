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
  /// - champ texte `product`: JSON de l'objet produit (voir mapping ci-dessous)
  /// - champs fichiers `files`: 1..n fichiers image
  Future<void> pushToMarketplace(Product product, List<File> images) async {
    if (images.isEmpty) {
      throw ArgumentError('Aucune image fournie');
    }

    final uri = Uri.parse(_join(baseUri, '/api/v1/marketplace'));
    final req = http.MultipartRequest('POST', uri);

    // En-têtes: on part des headers globaux, mais on enlève Content-Type,
    // car http.MultipartRequest gère sa propre boundary.
    final baseHeaders = ref.read(syncHeaderBuilderProvider)();
    final headers = Map<String, String>.from(baseHeaders);
    headers.remove('Content-Type');
    req.headers.addAll(headers);

    // Payload JSON "product" (aligné sur ton cURL)
    final productMap = _buildProductMap(product);
    req.fields['product'] = jsonEncode(productMap);

    // Fichiers
    for (final file in images) {
      if (!await file.exists()) continue;
      final mime = _mimeFromPath(file.path);
      final mediaType = MediaType.parse(mime);
      req.files.add(
        await http.MultipartFile.fromPath(
          'files',
          file.path,
          contentType: mediaType,
        ),
      );
    }

    // Envoi
    final streamed = await req.send();
    final resp = await http.Response.fromStream(streamed);

    // 2xx OK, sinon on renvoie l’erreur avec le body du serveur
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw HttpException(
        'HTTP ${resp.statusCode} ${resp.reasonPhrase ?? ''} • ${resp.body}',
        uri: uri,
      );
    }
  }

  // ---- Helpers ----

  // Construit le JSON pour le champ "product" de la requête multipart
  Map<String, dynamic> _buildProductMap(Product p) {
    final map = <String, dynamic>{
      'remoteId': p.remoteId,
      'localId': p.id,
      'code': p.code ?? p.id, // fallback pour éviter vide
      'name': p.name ?? p.code ?? 'Produit',
      'description': p.description,
      'barcode': p.barcode,
      'unit': p.unitId,
      'syncAt': DateTime.now().toUtc().toIso8601String(),
      'category': p.categoryId,
      // Si ton entité Product a un champ "account", mets-le ici :
      // 'account': p.account,
      'defaultPrice': (p.defaultPrice / 100.0),
      'statuses': p.statuses,
      'purchasePrice': (p.purchasePrice / 100.0),
    };

    // Supprimer les nulls pour un JSON propre
    map.removeWhere((_, v) => v == null);
    return map;
  }

  String _mimeFromPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'application/octet-stream';
  }

  String _join(String base, String path) {
    if (base.endsWith('/')) base = base.substring(0, base.length - 1);
    return '$base$path';
  }
}
