import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'application/product_list_providers.dart';
import 'pages/product_list_body.dart';

class ProductListPage extends ConsumerWidget {
  const ProductListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queryCtrl = ref.watch(productQueryControllerProvider);

    // ✅ Key pour accéder au state interne du body (afin d'appeler startAdd()).
    final bodyKey = GlobalKey<ProductListBodyState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Produits'),
        actions: [
          IconButton(
            tooltip: 'Rafraîchir',
            onPressed: () =>
                ref.read(productsFutureProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Ajouter',
            // ✅ Ouvre le panneau d’ajout via la méthode publique du state
            onPressed: () => bodyKey.currentState?.startAdd(),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => bodyKey.currentState?.startAdd(),
        icon: const Icon(Icons.add),
        label: const Text('Nouveau produit'),
      ),
      // ✅ on passe la key au body
      body: ProductListBody(key: bodyKey, queryController: queryCtrl),
    );
  }
}
