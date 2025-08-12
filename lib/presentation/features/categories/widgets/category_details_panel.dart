import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/domain/categories/entities/category.dart';
import 'package:money_pulse/presentation/shared/formatters.dart';
import 'package:money_pulse/presentation/widgets/key_value_row.dart';
import 'package:money_pulse/presentation/app/providers.dart';

class CategoryDetailsPanel extends ConsumerWidget {
  final Category category;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const CategoryDetailsPanel({
    super.key,
    required this.category,
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
        '\nVersion: ${c.version}'
        '\nID: ${c.id}';
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(content: Text('Détails copiés dans le presse-papiers')),
    );
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer la catégorie ?'),
        content: const Text(
          'Cette action est irréversible. Voulez-vous vraiment supprimer cette catégorie ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.onErrorContainer,
              backgroundColor: Theme.of(ctx).colorScheme.errorContainer,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    return result ?? false;
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
          TextButton.icon(
            onPressed: () {
              Navigator.of(context).maybePop();
              if (onEdit != null) {
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => onEdit!.call(),
                );
              }
            },
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Modifier'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          KeyValueRow(label: 'Code', value: c.code),
          KeyValueRow(label: 'Description', value: c.description ?? '—'),
          KeyValueRow(label: 'Type', value: c.typeEntry ?? '—'),
          const SizedBox(height: 8),
          KeyValueRow(label: 'ID distant', value: c.remoteId ?? '—'),
          const Divider(height: 24),
          KeyValueRow(label: 'Créée le', value: _fmtDate(c.createdAt)),
          KeyValueRow(label: 'Mis à jour le', value: _fmtDate(c.updatedAt)),
          KeyValueRow(label: 'Supprimée le', value: _fmtDate(c.deletedAt)),
          KeyValueRow(label: 'Synchronisée le', value: _fmtDate(c.syncAt)),
          KeyValueRow(label: 'Version', value: '${c.version}'),
          const SizedBox(height: 12),
          const Text('ID', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          SelectableText(c.id),
          const SizedBox(height: 24),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _copyAll(context),
                icon: const Icon(Icons.copy_all_outlined),
                label: const Text('Copier les détails'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () async {
                  final ok = await _confirmDelete(context);
                  if (!ok) return;
                  try {
                    final repo = ref.read(categoryRepoProvider);
                    await repo.softDelete(c.id);
                    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                      const SnackBar(content: Text('Catégorie supprimée')),
                    );
                    Navigator.of(context).maybePop();
                    onDelete?.call();
                    try {
                      ref.invalidate(categoryRepoProvider);
                    } catch (_) {}
                  } catch (e) {
                    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                      SnackBar(content: Text('Échec de la suppression : $e')),
                    );
                  }
                },
                icon: const Icon(Icons.delete_outline),
                label: const Text('Supprimer'),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
