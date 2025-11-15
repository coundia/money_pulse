import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:jaayko/domain/products/entities/product.dart';

class ProductDeletePanel extends StatelessWidget {
  final Product product;
  const ProductDeletePanel({super.key, required this.product});

  String _money(int cents) {
    final v = cents / 100.0;
    return NumberFormat.currency(symbol: '', decimalDigits: 0).format(v);
  }

  @override
  Widget build(BuildContext context) {
    final title = product.name?.isNotEmpty == true
        ? product.name!
        : (product.code ?? 'Produit');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Supprimer le produit'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context, false),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              size: 64,
              color: Colors.amber,
            ),
            const SizedBox(height: 12),
            Text(
              'Confirmer la suppression ?',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.inventory_2_outlined),
              title: Text(title),
              subtitle: Text(
                [
                  if ((product.code ?? '').isNotEmpty) 'Code: ${product.code}',
                  if ((product.barcode ?? '').isNotEmpty)
                    'EAN: ${product.barcode}',
                ].join('  •  '),
              ),
              trailing: Text(_money(product.defaultPrice)),
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Annuler'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () => Navigator.pop(context, true),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Supprimer'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
