import 'package:flutter/material.dart';
import 'package:money_pulse/domain/units/entities/unit.dart';
import 'package:money_pulse/presentation/shared/formatters.dart';

class UnitViewPanel extends StatelessWidget {
  final Unit unit;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onShare;

  const UnitViewPanel({
    super.key,
    required this.unit,
    this.onEdit,
    this.onDelete,
    this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final title = unit.name?.isNotEmpty == true ? unit.name! : unit.code;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Fermer',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Détails de l’unité'),
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
                    const SizedBox(height: 4),
                    Text(
                      unit.code,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if ((unit.description ?? '').isNotEmpty) ...[
            Text('Description', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(unit.description!),
            const SizedBox(height: 16),
          ],

          Text('Détails', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _kv('Code', unit.code),
          _kv('Nom', unit.name ?? '—'),
          _kv('Version', '${unit.version}'),
          _kv('Marqué à synchroniser', unit.isDirty == 1 ? 'Oui' : 'Non'),

          const SizedBox(height: 8),
          Text('Métadonnées', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _kv('Créé le', Formatters.dateFull(unit.createdAt)),
          _kv('Mis à jour le', Formatters.dateFull(unit.updatedAt)),
          _kv(
            'Supprimé le',
            unit.deletedAt == null ? '—' : Formatters.dateFull(unit.deletedAt!),
          ),
          _kv(
            'SyncAt',
            unit.syncAt == null ? '—' : Formatters.dateFull(unit.syncAt!),
          ),
          _kv('ID', unit.id),
          _kv('Remote ID', unit.remoteId ?? '—'),

          const SizedBox(height: 24),
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

  Widget _kv(String k, String v) {
    final keyStyle = const TextStyle(fontWeight: FontWeight.w600);
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
