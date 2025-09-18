// Read-only product detail panel for right drawer.
import 'package:flutter/material.dart';
import '../../shared/formatters.dart';
import '../domain/entities/marketplace_item.dart';

class ProductViewPanel extends StatelessWidget {
  final MarketplaceItem item;
  const ProductViewPanel({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final img = item.imageUrls.isNotEmpty ? item.imageUrls.first : null;
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
                  if (img != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Image.network(img, fit: BoxFit.cover),
                      ),
                    ),
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
                  FilledButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.shopping_bag),
                    label: const Text('Commander'),
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
