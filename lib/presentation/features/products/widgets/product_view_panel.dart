// Right-drawer product details integrating publish/unpublish marketplace actions.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/domain/products/entities/product.dart';
import 'package:money_pulse/presentation/shared/formatters.dart';
import '../../../products/product_market_button.dart';
import 'product_unpublish_button.dart';
import 'product_files_gallery.dart';

class ProductViewPanel extends ConsumerWidget {
  final Product product;
  final String? categoryLabel;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onShare;
  final VoidCallback? onAdjust;

  const ProductViewPanel({
    super.key,
    required this.product,
    this.categoryLabel,
    this.onEdit,
    this.onDelete,
    this.onShare,
    this.onAdjust,
  });

  String _money(int cents) => Formatters.amountFromCents(cents);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = (product.name?.isNotEmpty == true)
        ? product.name!
        : (product.code ?? 'Produit');
    final subtitleParts = <String>[
      if ((product.code ?? '').isNotEmpty) 'Code: ${product.code}',
      if ((product.barcode ?? '').isNotEmpty) 'EAN: ${product.barcode}',
      if ((categoryLabel ?? '').isNotEmpty) 'Catégorie: $categoryLabel',
      if ((product.statuses ?? '').isNotEmpty) 'Statut: ${product.statuses}',
    ];
    final subtitle = subtitleParts.join('  •  ');
    final filesAsync = ref.watch(productFilesProvider(product.id));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Détails du produit'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Fermer',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Header(
            title: title,
            subtitle: subtitle,
            price: _money(product.defaultPrice),
            purchase: product.purchasePrice > 0
                ? _money(product.purchasePrice)
                : null,
          ),
          const SizedBox(height: 16),
          if ((product.description ?? '').isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(product.description!),
              ),
            ),
          const SizedBox(height: 12),
          ProductFilesGallery(productId: product.id),
          const SizedBox(height: 12),
          filesAsync.when(
            data: (files) {
              final imageFiles = <File>[];
              for (final f in files) {
                final mt = (f.mimeType ?? '').toLowerCase();
                final p = (f.filePath ?? '').trim();
                if (mt.startsWith('image/') && p.isNotEmpty) {
                  final file = File(p);
                  if (file.existsSync()) imageFiles.add(file);
                }
              }
              return Row(
                children: [
                  Expanded(
                    child: ProductMarketButton(
                      product: product,
                      images: imageFiles,
                      baseUri: 'http://127.0.0.1:8095',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ProductUnpublishButton(
                      product: product,
                      baseUri: 'http://127.0.0.1:8095',
                    ),
                  ),
                ],
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (_, __) => Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.storefront),
                    label: const Text('Publier'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: null,
                    icon: const Icon(Icons.unpublished_outlined),
                    label: const Text('Retirer publication'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (onShare != null)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onShare,
                    icon: const Icon(Icons.ios_share),
                    label: const Text('Partager'),
                  ),
                ),
              if (onShare != null) const SizedBox(width: 12),
              if (onEdit != null)
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Modifier'),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (onDelete != null)
            FilledButton.icon(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Supprimer'),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.errorContainer,
                foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String title;
  final String subtitle;
  final String price;
  final String? purchase;
  const _Header({
    required this.title,
    required this.subtitle,
    required this.price,
    this.purchase,
  });

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      Chip(label: Text('Vente: $price')),
      if (purchase != null) Chip(label: Text('Coût: $purchase')),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 6),
        if (subtitle.isNotEmpty)
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: chips),
      ],
    );
  }
}
