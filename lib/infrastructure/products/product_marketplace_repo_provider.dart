// Riverpod provider.family wiring repository with baseUri and local ProductRepository.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jaayko/domain/products/repositories/product_repository.dart';
import '../../presentation/features/products/product_repo_provider.dart';
import 'product_marketplace_repo.dart';

final productMarketplaceRepoProvider =
    Provider.family<ProductMarketplaceRepo, String>((ref, baseUri) {
      final productRepo = ref.read(productRepoProvider);
      return ProductMarketplaceRepo(ref, baseUri)..toString();
    });
