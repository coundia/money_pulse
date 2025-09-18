// Riverpod provider.family to inject baseUri into MarketplaceRepository.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'marketplace_repository.dart';

final marketplaceRepoProvider = Provider.family<MarketplaceRepository, String>((
  ref,
  baseUri,
) {
  return MarketplaceRepository(baseUri);
});
