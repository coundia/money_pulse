import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:money_pulse/domain/products/entities/product.dart';
import 'package:money_pulse/presentation/shared/formatters.dart';

/// Panneau lecture seule pour afficher les détails d'un produit,
/// destiné à être affiché dans un right drawer (voir `showRightDrawer`).
class ProductViewPanel extends StatelessWidget {
  final Product product;

  /// Libellé lisible de la catégorie (ex: code ou nom). Optionnel.
  final String? categoryLabel;

  /// Actions externes (la page parente gère la logique).
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onShare;

  const ProductViewPanel({
    super.key,
    required this.product,
    this.categoryLabel,
    this.onEdit,
    this.onDelete,
    this.onShare,
  });

  String _money(int cents) {
    final v = cents / 100.0;
    // Pas de symbole ici; laissez l’AppBar/Balance gérer la devise
    return NumberFormat.currency(symbol: '', decimalDigits: 0).format(v);
  }

  @override
  Widget build(BuildContext context) {
    final title = (product.name?.isNotEmpty == true)
        ? product.name!
        : (product.code ?? 'Produit');

    final subtitleParts = <String>[
      if ((product.code ?? '').isNotEmpty) 'Code: ${product.code}',
      if ((product.barcode ?? '').isNotEmpty) 'EAN: ${product.barcode}',
      if ((categoryLabel ?? '').isNotEmpty) 'Catégorie: $categoryLabel',
    ];
    final subtitle = subtitleParts.join('  •  ');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Détails du produit'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Fermer',
        ),
        actions: [
          IconButton(
            tooltip: 'Partager',
            icon: const Icon(Icons.ios_share),
            onPressed: onShare,
          ),
          IconButton(
            tooltip: 'Modifier',
            icon: const Icon(Icons.edit_outlined),
            onPressed: onEdit,
          ),
          IconButton(
            tooltip: 'Supprimer',
            icon: const Icon(Icons.delete_outline),
            onPressed: onDelete,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // En-tête
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 26,
                child: Text(
                  (title.isNotEmpty ? title.characters.first : '?')
                      .toUpperCase(),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _PriceBadge(text: _money(product.defaultPrice)),
            ],
          ),

          const SizedBox(height: 16),

          // Chips info
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if ((product.code ?? '').isNotEmpty)
                const _ChipIcon(text: 'Code', icon: Icons.tag),
              if ((product.barcode ?? '').isNotEmpty)
                const _ChipIcon(text: 'EAN', icon: Icons.qr_code_2),
              if ((categoryLabel ?? '').isNotEmpty)
                const _ChipIcon(
                  text: 'Catégorie',
                  icon: Icons.category_outlined,
                ),
              const _ChipIcon(
                text: 'Produit',
                icon: Icons.inventory_2_outlined,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Description
          if ((product.description ?? '').isNotEmpty) ...[
            Text('Description', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(product.description!),
            const SizedBox(height: 16),
          ],

          // Détails techniques
          Text('Détails', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _KeyValueRow('Nom', product.name ?? '—'),
          _KeyValueRow('Code (SKU)', product.code ?? '—'),
          _KeyValueRow('Code barre (EAN/UPC)', product.barcode ?? '—'),
          _KeyValueRow('Catégorie', categoryLabel ?? product.categoryId ?? '—'),
          _KeyValueRow('Prix par défaut', _money(product.defaultPrice)),
          _KeyValueRow('Version', '${product.version}'),
          _KeyValueRow(
            'Marqué à synchroniser',
            product.isDirty == 1 ? 'Oui' : 'Non',
          ),

          const SizedBox(height: 8),
          Text('Métadonnées', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _KeyValueRow('Créé le', Formatters.dateFull(product.createdAt)),
          _KeyValueRow('Mis à jour le', Formatters.dateFull(product.updatedAt)),
          _KeyValueRow(
            'Supprimé le',
            product.deletedAt == null
                ? '—'
                : Formatters.dateFull(product.deletedAt!),
          ),
          _KeyValueRow(
            'SyncAt',
            product.syncAt == null ? '—' : Formatters.dateFull(product.syncAt!),
          ),
          _KeyValueRow('ID', product.id),
          _KeyValueRow('Remote ID', product.remoteId ?? '—'),

          const SizedBox(height: 24),

          // Actions secondaires (optionnelles)
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onShare,
                  icon: const Icon(Icons.ios_share),
                  label: const Text('Partager'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Modifier'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.errorContainer,
              foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
            ),
            label: const Text('Supprimer'),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/* ============================ UI helpers ============================ */

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

class _ChipIcon extends StatelessWidget {
  final String text;
  final IconData icon;
  const _ChipIcon({required this.text, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Chip(avatar: Icon(icon, size: 18), label: Text(text));
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
