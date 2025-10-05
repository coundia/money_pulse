// marketplace/infrastructure/marketplace_repo_provider.dart
// Exposes MarketplaceRepository as a Riverpod provider.family injected with baseUri.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'marketplace_repository.dart';

final marketplaceRepoProvider = Provider.family<MarketplaceRepository, String>((
  ref,
  baseUri,
) {
  return MarketplaceRepository(baseUri);
});
