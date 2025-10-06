// Riverpod guard to prevent accidental duplicate orders for the same product within the session.
import 'package:flutter_riverpod/flutter_riverpod.dart';

class OrderedProductsGuard extends StateNotifier<Set<String>> {
  OrderedProductsGuard() : super(<String>{});

  bool isAlreadyOrdered(String productId) => state.contains(productId);

  void markOrdered(String productId) {
    if (productId.trim().isEmpty) return;
    state = {...state, productId};
  }

  void clearAll() {
    state = <String>{};
  }
}

final orderedProductsGuardProvider =
    StateNotifierProvider<OrderedProductsGuard, Set<String>>(
      (ref) => OrderedProductsGuard(),
    );
