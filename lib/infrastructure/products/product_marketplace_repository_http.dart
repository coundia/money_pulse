// Implementation using multipart POST to marketplace API
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:money_pulse/domain/products/entities/product.dart';
import 'package:money_pulse/domain/products/repositories/product_marketplace_repository.dart';
import 'package:money_pulse/sync/infrastructure/sync_headers_provider.dart';

class ProductMarketplaceRepositoryHttp implements ProductMarketplaceRepository {
  final String baseUri;
  final http.Client _http;
  final HeaderBuilder _headers;

  ProductMarketplaceRepositoryHttp(this.baseUri, this._http, this._headers);

  @override
  Future<void> pushToMarketplace(Product product, List<File> images) async {
    final uri = Uri.parse('$baseUri/api/v1/marketplace');
    final request = http.MultipartRequest('POST', uri);

    final headers = _headers();
    request.headers.addAll(headers..remove('Content-Type'));

    final productJson = {
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
    };

    request.fields['product'] = jsonEncode(productJson);

    for (final img in images) {
      request.files.add(await http.MultipartFile.fromPath('files', img.path));
    }

    final resp = await http.Response.fromStream(await _http.send(request));
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw StateError(
        'Marketplace push failed: ${resp.statusCode} ${resp.body}',
      );
    }
  }
}
