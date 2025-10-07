import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'application/product_list_providers.dart';
import 'pages/product_list_body.dart';

class ProductListPage extends ConsumerWidget {
  const ProductListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queryCtrl = ref.watch(productQueryControllerProvider);

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
            onPressed: () => ProductListBody.openAdd(context, ref),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => ProductListBody.openAdd(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Nouveau produit'),
      ),
      body: ProductListBody(queryController: queryCtrl),
    );
  }
}
