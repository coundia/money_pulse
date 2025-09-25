// Right-drawer details for Category with publish/unpublish actions and improved UX.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/domain/categories/entities/category.dart';
import 'package:money_pulse/presentation/shared/formatters.dart';
import 'package:money_pulse/presentation/widgets/key_value_row.dart';

import 'category_publish_actions.dart';

class CategoryDetailsPanel extends ConsumerWidget {
  final Category category;
  final String marketplaceBaseUri;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const CategoryDetailsPanel({
    super.key,
    required this.category,
    required this.marketplaceBaseUri,
    this.onEdit,
    this.onDelete,
  });

  String _fmtDate(DateTime? d) => d == null ? '—' : Formatters.dateFull(d);

  Future<void> _copyAll(BuildContext context) async {
    final c = category;
    final text =
        'Catégorie: ${c.code}'
        '\nDescription: ${c.description ?? '—'}'
        '\nType: ${c.typeEntry ?? '—'}'
        '\nID distant: ${c.remoteId ?? '—'}'
        '\nCréée le: ${_fmtDate(c.createdAt)}'
        '\nMis à jour le: ${_fmtDate(c.updatedAt)}'
        '\nSupprimée le: ${_fmtDate(c.deletedAt)}'
        '\nSynchronisée le: ${_fmtDate(c.syncAt)}'
        '\nVersion: ${c.version}';
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(content: Text('Détails copiés dans le presse-papiers')),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = category;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Fermer',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('Détails de la catégorie'),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).maybePop();
              onEdit?.call();
            },
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Modifier',
          ),
          IconButton(
            onPressed: () => _copyAll(context),
            icon: const Icon(Icons.copy_all_outlined),
            tooltip: 'Copier',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: CategoryPublishActions(
                category: c,
                baseUri: marketplaceBaseUri,
                onChanged: () => Navigator.of(context).maybePop(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          KeyValueRow(label: 'Code', value: c.code),
          KeyValueRow(label: 'Description', value: c.description ?? '—'),
          KeyValueRow(label: 'Type', value: c.typeEntry ?? '—'),
          const Divider(height: 24),
          KeyValueRow(label: 'ID distant', value: c.remoteId ?? '—'),
          KeyValueRow(label: 'Créée le', value: _fmtDate(c.createdAt)),
          KeyValueRow(label: 'Mis à jour le', value: _fmtDate(c.updatedAt)),
          KeyValueRow(label: 'Supprimée le', value: _fmtDate(c.deletedAt)),
          KeyValueRow(label: 'Synchronisée le', value: _fmtDate(c.syncAt)),
          KeyValueRow(label: 'Version', value: '${c.version}'),
          const SizedBox(height: 24),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Supprimer'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
