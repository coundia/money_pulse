import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:money_pulse/domain/categories/entities/category.dart';
import 'package:money_pulse/presentation/shared/formatters.dart';

class CategoryDetailsPanel extends StatelessWidget {
  final Category category;
  final VoidCallback? onEdit;

  const CategoryDetailsPanel({super.key, required this.category, this.onEdit});

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

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(k, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 6),
          Expanded(child: Text(v)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
            tooltip: 'Copier les détails',
            onPressed: () => _copyAll(context),
            icon: const Icon(Icons.copy_all_outlined),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).maybePop();
              if (onEdit == null) return;
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => onEdit!.call(),
              );
            },
            child: const Text('Modifier'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _kv('Code', c.code),
          _kv('Description', c.description ?? '—'),
          _kv('Type', c.typeEntry ?? '—'),
          const SizedBox(height: 8),
          _kv('ID distant', c.remoteId ?? '—'),
          const Divider(height: 24),
          _kv('Créée le', _fmtDate(c.createdAt)),
          _kv('Mis à jour le', _fmtDate(c.updatedAt)),
          _kv('Supprimée le', _fmtDate(c.deletedAt)),
          _kv('Synchronisée le', _fmtDate(c.syncAt)),
          _kv('Version', '${c.version}'),
          const SizedBox(height: 12),
          const Text('ID', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          SelectableText(c.id),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
