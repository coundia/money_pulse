// Read-only product detail panel with multi-image gallery.
import 'package:flutter/material.dart';
import '../../shared/formatters.dart';
import '../domain/entities/marketplace_item.dart';
import 'widgets/product_image_gallery.dart';

class ProductViewPanel extends StatelessWidget {
  final MarketplaceItem item;
  const ProductViewPanel({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Fermer',
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.close),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ProductImageGallery(imageUrls: item.imageUrls),
                  const SizedBox(height: 16),
                  Text(
                    '${Formatters.amountFromCents(item.defaultPrice * 100)} FCFA',
                    style: Theme.of(
                      context,
                    ).textTheme.headlineSmall?.copyWith(color: Colors.green),
                  ),
                  const SizedBox(height: 8),
                  if ((item.description ?? '').isNotEmpty)
                    Text(
                      item.description!,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.shopping_bag),
                          label: const Text('Commander'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton.filledTonal(
                        tooltip: 'Partager',
                        onPressed: () {},
                        icon: const Icon(Icons.share),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
