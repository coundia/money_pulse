// Provider to inject marketplace repository
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:money_pulse/domain/products/repositories/product_marketplace_repository.dart';
import 'package:money_pulse/infrastructure/products/product_marketplace_repository_http.dart';
import 'package:money_pulse/sync/infrastructure/sync_headers_provider.dart';

final productMarketplaceRepoProvider =
    Provider.family<ProductMarketplaceRepository, String>((ref, baseUri) {
      final client = http.Client();
      final headers = ref.read(syncHeaderBuilderProvider);
      return ProductMarketplaceRepositoryHttp(baseUri, client, headers);
    });
