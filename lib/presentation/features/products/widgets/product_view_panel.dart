// Right-drawer product details panel with inline product files gallery and image-based header avatar.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:money_pulse/domain/products/entities/product.dart';
import 'package:money_pulse/presentation/shared/formatters.dart';

import '../../../products/product_market_button.dart';
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

    final priceBadges = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _PriceBadge(text: 'Vente: ${_money(product.defaultPrice)}'),
        if (product.purchasePrice > 0)
          _PriceBadge(text: "Coût: ${_money(product.purchasePrice)}"),
      ],
    );

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
          // HEADER (avec avatar image si dispo)
          filesAsync.when(
            data: (files) {
              File? hero;
              for (final f in files) {
                final mt = (f.mimeType ?? '').toLowerCase();
                final p = (f.filePath ?? '').trim();
                if (mt.startsWith('image/') &&
                    p.isNotEmpty &&
                    File(p).existsSync()) {
                  hero = File(p);
                  break;
                }
              }
              return _HeaderBlock(
                title: title,
                subtitle: subtitle,
                priceBadges: priceBadges,
                heroImage: hero,
              );
            },
            loading: () => _HeaderBlock(
              title: title,
              subtitle: subtitle,
              priceBadges: priceBadges,
            ),
            error: (_, __) => _HeaderBlock(
              title: title,
              subtitle: subtitle,
              priceBadges: priceBadges,
            ),
          ),

          const SizedBox(height: 16),

          if ((product.description ?? '').isNotEmpty)
            _SectionCard(
              title: 'Description',
              child: Text(product.description!),
            ),

          _SectionCard(
            title: 'Détails',
            child: Column(
              children: [
                _KeyValueRow('Nom', product.name ?? '—'),
                _KeyValueRow('Code (SKU)', product.code ?? '—'),
                _KeyValueRow('Code barre (EAN/UPC)', product.barcode ?? '—'),
                _KeyValueRow(
                  'Catégorie',
                  categoryLabel ?? product.categoryId ?? '—',
                ),
                _KeyValueRow('Prix de vente', _money(product.defaultPrice)),
                _KeyValueRow(
                  "Prix d'achat",
                  product.purchasePrice > 0
                      ? _money(product.purchasePrice)
                      : '—',
                ),
                _KeyValueRow('Statut', product.statuses ?? "-"),
              ],
            ),
          ),

          // GALERIE INLINE
          ProductFilesGallery(productId: product.id),

          const SizedBox(height: 12),

          // ACTIONS BASÉES SUR LES FICHIERS CONNUS
          filesAsync.when(
            data: (files) {
              // On récupère la liste de File existants sur le disque, uniquement images (utile pour l’API marketplace)
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
                  if (onShare != null)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onShare,
                        icon: const Icon(Icons.ios_share),
                        label: const Text('Partager'),
                      ),
                    ),
                  if (onShare != null) const SizedBox(width: 12),

                  // Bouton Envoyer (désactivé si aucune image)
                  Expanded(
                    child: ProductMarketButton(
                      product: product,
                      images: imageFiles, // <=== images réelles
                      baseUri: 'http://127.0.0.1:8095',
                      // accountId: '...', unitId: '...', // si ton API en a besoin
                    ),
                  ),
                  const SizedBox(width: 12),

                  if (onEdit != null)
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Modifier'),
                      ),
                    ),
                ],
              );
            },
            loading: () => Row(
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
                const Expanded(
                  child: SizedBox(
                    height: 40,
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
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
            error: (_, __) => Row(
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
                // En erreur, on désactive l’envoi (pas d’images fiables)
                Expanded(
                  child: FilledButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.storefront),
                    label: const Text('Envoyer'),
                  ),
                ),
                const SizedBox(width: 12),
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
          ),

          const SizedBox(height: 12),

          if (onDelete != null)
            FilledButton.icon(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.errorContainer,
                foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
              ),
              label: const Text('Supprimer'),
            ),
        ],
      ),
    );
  }
}

class _HeaderBlock extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget priceBadges;
  final File? heroImage;
  const _HeaderBlock({
    required this.title,
    required this.subtitle,
    required this.priceBadges,
    this.heroImage,
  });

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 520;

    final avatar = CircleAvatar(
      radius: 26,
      child: heroImage == null
          ? Text(
              (title.isNotEmpty ? title.characters.first : '?').toUpperCase(),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            )
          : ClipOval(
              child: Image.file(
                heroImage!,
                width: 52,
                height: 52,
                fit: BoxFit.cover,
              ),
            ),
    );

    final titleText = Text(
      title,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.titleLarge,
    );

    final subtitleText = subtitle.isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          );

    if (isCompact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              avatar,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [titleText, subtitleText],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          priceBadges,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        avatar,
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleText,
              subtitleText,
              const SizedBox(height: 8),
              priceBadges,
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: cs.surfaceVariant.withOpacity(0.35),
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.all(12),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

class _KeyValueRow extends StatelessWidget {
  final String k;
  final String v;
  const _KeyValueRow(this.k, this.v);

  @override
  Widget build(BuildContext context) {
    final keyStyle = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 160, child: Text(k, style: keyStyle)),
          const SizedBox(width: 8),
          Expanded(child: Text(v)),
        ],
      ),
    );
  }
}

class _PriceBadge extends StatelessWidget {
  final String text;
  const _PriceBadge({required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: cs.onPrimaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
