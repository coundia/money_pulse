// Product detail right-drawer panel; shows selling price, purchase price, and single-string status.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:money_pulse/domain/products/entities/product.dart';
import 'package:money_pulse/presentation/shared/formatters.dart';

import 'package:money_pulse/domain/stock/repositories/stock_level_repository.dart'
    show StockLevelRow;
import 'package:money_pulse/presentation/features/stock/providers/stock_level_repo_provider.dart';

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

    final q = (product.code?.trim().isNotEmpty ?? false)
        ? product.code!.trim()
        : (product.name?.trim() ?? '');
    final asyncLevels = ref.watch(_stockSearchProvider(q));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Détails du produit'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Fermer',
        ),
        actions: [
          if (onAdjust != null)
            IconButton(
              tooltip: 'Ajuster le stock',
              icon: const Icon(Icons.tune),
              onPressed: onAdjust,
            ),
          if (onEdit != null)
            IconButton(
              tooltip: 'Modifier',
              icon: const Icon(Icons.edit_outlined),
              onPressed: onEdit,
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _PriceBadge(text: 'Vente: ${_money(product.defaultPrice)}'),
                  if (product.purchasePrice > 0)
                    _PriceBadge(text: "Coût: ${_money(product.purchasePrice)}"),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

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
              if ((product.statuses ?? '').isNotEmpty)
                _ChipIcon(
                  text: product.statuses ?? "-",
                  icon: Icons.flag_outlined,
                ),
            ],
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
                _KeyValueRow('Version', '${product.version}'),
                _KeyValueRow(
                  'Marqué à synchroniser',
                  product.isDirty == 1 ? 'Oui' : 'Non',
                ),
              ],
            ),
          ),

          _SectionCard(
            title: 'Métadonnées',
            child: Column(
              children: [
                _KeyValueRow('Créé le', Formatters.dateFull(product.createdAt)),
                _KeyValueRow(
                  'Mis à jour le',
                  Formatters.dateFull(product.updatedAt),
                ),
                _KeyValueRow(
                  'Supprimé le',
                  product.deletedAt == null
                      ? '—'
                      : Formatters.dateFull(product.deletedAt!),
                ),
                _KeyValueRow(
                  'SyncAt',
                  product.syncAt == null
                      ? '—'
                      : Formatters.dateFull(product.syncAt!),
                ),
                _KeyValueRow('ID', product.id),
                _KeyValueRow('Remote ID', product.remoteId ?? '—'),
              ],
            ),
          ),

          _SectionCard(
            title: 'Stock',
            trailing: (onAdjust != null)
                ? OutlinedButton.icon(
                    onPressed: onAdjust,
                    icon: const Icon(Icons.tune),
                    label: const Text('Ajuster le stock'),
                  )
                : null,
            child: asyncLevels.when(
              data: (rows) {
                final filtered = rows.where((r) {
                  if ((product.code ?? '').isNotEmpty) {
                    return r.productLabel.toLowerCase().contains(
                      product.code!.toLowerCase(),
                    );
                  }
                  if ((product.name ?? '').isNotEmpty) {
                    return r.productLabel.toLowerCase().contains(
                      product.name!.toLowerCase(),
                    );
                  }
                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return _EmptyStockCard(
                    hint: "Aucun niveau de stock trouvé pour ce produit.",
                    onAdjust: onAdjust,
                  );
                }

                final totalOnHand = filtered.fold<int>(
                  0,
                  (p, e) => p + e.stockOnHand,
                );
                final totalAllocated = filtered.fold<int>(
                  0,
                  (p, e) => p + e.stockAllocated,
                );

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TotalsBar(
                      onHand: totalOnHand,
                      allocated: totalAllocated,
                      updatedAt: filtered.first.updatedAt,
                    ),
                    const SizedBox(height: 8),
                    _ResponsiveStockListOrTable(rows: filtered),
                  ],
                );
              },
              loading: () => const _LoadingCard(),
              error: (err, _) =>
                  _EmptyStockCard(hint: 'Impossible de charger le stock: $err'),
            ),
          ),

          const SizedBox(height: 8),

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
          const SizedBox(height: 8),
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
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

final _stockSearchProvider = FutureProvider.autoDispose
    .family<List<StockLevelRow>, String>((ref, query) async {
      final repo = ref.read(stockLevelRepoProvider);
      return repo.search(query: query);
    });

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;

  const _SectionCard({required this.title, required this.child, this.trailing});

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
            Row(
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (trailing != null) trailing!,
              ],
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

class _ResponsiveStockListOrTable extends StatelessWidget {
  final List<StockLevelRow> rows;
  const _ResponsiveStockListOrTable({required this.rows});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;

    if (w < 560) {
      return ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: rows.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final e = rows[i];
          return ListTile(
            dense: true,
            title: Text(
              e.companyLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                Chip(
                  label: Text('Dispo: ${e.stockOnHand}'),
                  visualDensity: VisualDensity.compact,
                ),
                Chip(
                  label: Text('Alloué: ${e.stockAllocated}'),
                  visualDensity: VisualDensity.compact,
                ),
                Chip(
                  label: Text(Formatters.dateFull(e.updatedAt)),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          );
        },
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 16,
        headingRowHeight: 36,
        dataRowMinHeight: 40,
        dataRowMaxHeight: 48,
        columns: const [
          DataColumn(label: Text('Société')),
          DataColumn(label: Text('Stock dispo')),
          DataColumn(label: Text('Alloué')),
          DataColumn(label: Text('Mis à jour')),
        ],
        rows: rows
            .map(
              (e) => DataRow(
                cells: [
                  DataCell(
                    SizedBox(
                      width: 280,
                      child: Text(
                        e.companyLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  DataCell(Text('${e.stockOnHand}')),
                  DataCell(Text('${e.stockAllocated}')),
                  DataCell(Text(Formatters.dateFull(e.updatedAt))),
                ],
              ),
            )
            .toList(),
      ),
    );
  }
}

class _TotalsBar extends StatelessWidget {
  final int onHand;
  final int allocated;
  final DateTime updatedAt;
  const _TotalsBar({
    required this.onHand,
    required this.allocated,
    required this.updatedAt,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget box(String title, String value) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value, textAlign: TextAlign.center),
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 520) {
          return Column(
            children: [
              box('Total disponible', '$onHand'),
              const SizedBox(height: 8),
              box('Total alloué', '$allocated'),
              const SizedBox(height: 8),
              box('Dernière MAJ', Formatters.dateFull(updatedAt)),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: box('Total disponible', '$onHand')),
            const SizedBox(width: 8),
            Expanded(child: box('Total alloué', '$allocated')),
            const SizedBox(width: 8),
            Expanded(
              child: box('Dernière MAJ', Formatters.dateFull(updatedAt)),
            ),
          ],
        );
      },
    );
  }
}

class _EmptyStockCard extends StatelessWidget {
  final String hint;
  final VoidCallback? onAdjust;
  const _EmptyStockCard({required this.hint, this.onAdjust});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.inventory_2_outlined, color: cs.primary),
            const SizedBox(width: 12),
            Expanded(child: Text(hint)),
            if (onAdjust != null) ...[
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: onAdjust,
                icon: const Icon(Icons.tune),
                label: const Text('Ajuster'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SizedBox(
        height: 96,
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              SizedBox(width: 12),
              CircularProgressIndicator(),
              SizedBox(width: 12),
              Text('Chargement du stock…'),
            ],
          ),
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
