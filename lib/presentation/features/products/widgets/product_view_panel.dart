// Right-drawer product view with live refresh after edit; uses a provider to reload
// the product from DB. Shows remoteId only in debug builds (kDebugMode) and provides
// an action to copy it to clipboard in any build variant.

import 'dart:io';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:money_pulse/domain/products/entities/product.dart';
import 'package:money_pulse/presentation/shared/formatters.dart';
import 'product_publish_actions.dart';
import 'product_files_gallery.dart';
import 'package:money_pulse/presentation/features/products/product_file_repo_provider.dart';
import 'package:money_pulse/presentation/features/products/product_repo_provider.dart';

final _productByIdProvider = FutureProvider.autoDispose
    .family<Product?, String>((ref, id) async {
      final repo = ref.read(productRepoProvider);
      return repo.findById(id);
    });

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

  // Async edit callback (awaited) to refresh after returning from edit flow
  final Future<void> Function()? onEdit;
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
    final productAsync = ref.watch(_productByIdProvider(product.id));
    final p = productAsync.asData?.value ?? product;

    final price = Formatters.amountFromCents(p.defaultPrice);
    final priceBuy = p.purchasePrice > 0
        ? Formatters.amountFromCents(p.purchasePrice)
        : null;
    final created = Formatters.dateFull(p.createdAt);
    final updated = Formatters.dateFull(p.updatedAt);
    final qty = NumberFormat.decimalPattern().format(p.quantity);

    final imagesAsync = ref.watch(_imagesForPublishProvider(p.id));

    Future<void> _editAndRefresh() async {
      if (onEdit != null) {
        await onEdit!.call();
        ref.invalidate(_productByIdProvider(product.id));
      }
    }

    Future<void> _copyRemoteId() async {
      final id = (p.remoteId ?? '').trim();
      if (id.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aucun identifiant distant.')),
        );
        return;
      }
      await Clipboard.setData(ClipboardData(text: id));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Identifiant copié.')));
    }

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
            onPressed: _editAndRefresh,
            icon: const Icon(Icons.edit),
            tooltip: 'Modifier',
          ),
          IconButton(
            onPressed: onAdjust,
            icon: const Icon(Icons.inventory_2_outlined),
            tooltip: 'Ajuster le stock',
          ),
          // Action accessible partout: copie du remoteId (sans l’afficher en prod)
          IconButton(
            onPressed: _copyRemoteId,
            icon: const Icon(Icons.copy_all_outlined),
            tooltip: 'Copier l’ID distant',
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Supprimer',
          ),
        ],
      ),
      body: productAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur: $e')),
        data: (_) {
          return LayoutBuilder(
            builder: (context, bc) {
              final maxW = 980.0;
              final side = bc.maxWidth > maxW ? (bc.maxWidth - maxW) / 2 : 0.0;
              final isNarrow = bc.maxWidth < 640;

              Widget infoColumn = Column(
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
                      Chip(label: Text('Stock: $qty')),
                      if ((categoryLabel ?? '').isNotEmpty)
                        Chip(label: Text('Catégorie: $categoryLabel')),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Créé: $created • Modifié: $updated',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  // ⬇️ N’affiche l’ID que en debug (pour respecter la consigne en prod)
                  if (kDebugMode && (p.remoteId ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    SelectableText(
                      'ID : ${p.remoteId}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ],
              );

              Widget publishActions = imagesAsync.when(
                data: (imgs) => ProductPublishActions(
                  product: p,
                  baseUri: marketplaceBaseUri,
                  images: imgs,
                  onChanged: () {
                    ref.invalidate(_productByIdProvider(product.id));
                    Navigator.of(context).maybePop(true);
                  },
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
              );

              Widget header;
              if (isNarrow) {
                header = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
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
                        const SizedBox(width: 12),
                        Expanded(child: infoColumn),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: publishActions,
                    ),
                  ],
                );
              } else {
                header = Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
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
                    const SizedBox(width: 16),
                    Expanded(child: infoColumn),
                    const SizedBox(width: 12),
                    publishActions,
                  ],
                );
              }

              return ListView(
                padding: EdgeInsets.fromLTRB(side + 16, 16, side + 16, 24),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: header,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ProductFilesGallery(productId: p.id),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
