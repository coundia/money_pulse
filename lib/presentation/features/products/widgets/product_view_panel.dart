// Right-drawer product view; closes with `true` on publish/unpublish to trigger parent refresh.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/domain/products/entities/product.dart';
import 'package:money_pulse/presentation/shared/formatters.dart';
import 'product_publish_actions.dart';
import 'product_files_gallery.dart';
import 'package:money_pulse/presentation/features/products/product_file_repo_provider.dart';

final _imagesForPublishProvider = FutureProvider.autoDispose
    .family<List<File>, String>((ref, productId) async {
      final repo = ref.read(productFileRepoProvider);
      final rows = await repo.findByProduct(productId);
      final list = <File>[];
      for (final r in rows) {
        final mt = (r.mimeType ?? '').toLowerCase();
        final p = (r.filePath ?? '').trim();
        if (mt.startsWith('image/') && p.isNotEmpty) {
          final f = File(p);
          if (await f.exists()) list.add(f);
        }
      }
      return list;
    });

class ProductViewPanel extends ConsumerWidget {
  final Product product;
  final String? categoryLabel;
  final String marketplaceBaseUri;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onShare;
  final VoidCallback? onAdjust;

  const ProductViewPanel({
    super.key,
    required this.product,
    required this.marketplaceBaseUri,
    this.categoryLabel,
    this.onEdit,
    this.onDelete,
    this.onShare,
    this.onAdjust,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = product;
    final price = Formatters.amountFromCents(p.defaultPrice);
    final priceBuy = p.purchasePrice > 0
        ? Formatters.amountFromCents(p.purchasePrice)
        : null;
    final created = Formatters.dateFull(p.createdAt);
    final updated = Formatters.dateFull(p.updatedAt);

    final imagesAsync = ref.watch(_imagesForPublishProvider(p.id));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Détails du produit'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).maybePop(false),
          tooltip: 'Fermer',
        ),
        actions: [
          IconButton(
            onPressed: onShare,
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Partager',
          ),
          IconButton(
            onPressed: onEdit,
            icon: const Icon(Icons.edit),
            tooltip: 'Modifier',
          ),
          IconButton(
            onPressed: onAdjust,
            icon: const Icon(Icons.inventory_2_outlined),
            tooltip: 'Ajuster le stock',
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Supprimer',
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, bc) {
          final maxW = 980.0;
          final side = bc.maxWidth > maxW ? (bc.maxWidth - maxW) / 2 : 0.0;

          return ListView(
            padding: EdgeInsets.fromLTRB(side + 16, 16, side + 16, 24),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    runSpacing: 10,
                    spacing: 16,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 24,
                        child: Text(
                          (p.name?.isNotEmpty == true
                                  ? p.name!.characters.first
                                  : 'P')
                              .toUpperCase(),
                        ),
                      ),
                      Flexible(
                        fit: FlexFit.loose,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.name ?? 'Produit',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            if ((p.description ?? '').isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  p.description!,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                Chip(label: Text('PU: $price')),
                                if (priceBuy != null)
                                  Chip(label: Text('Achat: $priceBuy')),
                                if ((categoryLabel ?? '').isNotEmpty)
                                  Chip(
                                    label: Text('Catégorie: $categoryLabel'),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Créé: $created • Modifié: $updated',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      imagesAsync.when(
                        data: (imgs) => ProductPublishActions(
                          product: p,
                          baseUri: marketplaceBaseUri,
                          images: imgs,
                          onChanged: () => Navigator.of(context).maybePop(true),
                        ),
                        loading: () => const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                        error: (e, _) => Text('Erreur images: $e'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ProductFilesGallery(productId: p.id),
            ],
          );
        },
      ),
    );
  }
}
