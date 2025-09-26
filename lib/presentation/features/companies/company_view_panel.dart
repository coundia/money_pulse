// lib/presentation/features/companies/company_view_panel.dart
//
// Right-drawer company details with publish/unpublish actions,
// "Définir par défaut" button (only one default enforced by repo),
// and improved info layout.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:money_pulse/presentation/shared/formatters.dart';
import 'providers/company_detail_providers.dart';

import 'package:money_pulse/presentation/widgets/right_drawer.dart';
import 'company_form_panel.dart';
import 'company_delete_panel.dart';
import 'widgets/company_publish_actions.dart';

// 🆕 repo to update the "default" flag
import 'package:money_pulse/presentation/app/providers/company_repo_provider.dart';

class CompanyViewPanel extends ConsumerWidget {
  final String companyId;
  final String marketplaceBaseUri;
  const CompanyViewPanel({
    super.key,
    required this.companyId,
    this.marketplaceBaseUri = 'http://127.0.0.1:8095',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(companyByIdProvider(companyId));

    Future<void> onEdit() async {
      final c = await ref.read(companyByIdProvider(companyId).future);
      if (c == null) return;
      final ok = await showRightDrawer<bool>(
        context,
        child: CompanyFormPanel(initial: c),
        widthFraction: 0.86,
        heightFraction: 0.96,
      );
      if (ok == true) {
        ref.invalidate(companyByIdProvider(companyId));
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Société mise à jour')));
        }
      }
    }

    Future<void> onDelete() async {
      final ok = await showRightDrawer<bool>(
        context,
        child: CompanyDeletePanel(companyId: companyId),
        widthFraction: 0.86,
        heightFraction: 0.6,
      );
      if (ok == true && context.mounted) {
        Navigator.of(context).pop(true);
      }
    }

    Future<void> onCopy() async {
      final c = await ref.read(companyByIdProvider(companyId).future);
      if (c == null || !context.mounted) return;
      final text = [
        'Nom: ${c.name}',
        'Code: ${c.code}',
        'Statut: ${c.status ?? '—'}',
        'Public: ${c.isPublic ? 'Oui' : 'Non'}',
        'Téléphone: ${c.phone ?? '—'}',
        'Email: ${c.email ?? '—'}',
        'Site: ${c.website ?? '—'}',
        'N° fiscal: ${c.taxId ?? '—'}',
        'Devise: ${c.currency ?? '—'}',
        'Adresse: ${_addr(c.addressLine1, c.addressLine2, c.city, c.region, c.country, c.postalCode)}',
        'Créé: ${Formatters.dateFull(c.createdAt)}',
        'MAJ: ${Formatters.dateFull(c.updatedAt)}',
        'ID: ${c.id}',
        'RemoteId: ${c.remoteId ?? '—'}',
      ].join('\n');
      await Clipboard.setData(ClipboardData(text: text));
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(const SnackBar(content: Text('Détails copiés')));
    }

    // 🆕 Set this company as the single default (repo will unset others)
    Future<void> onSetDefault() async {
      final c = await ref.read(companyByIdProvider(companyId).future);
      if (c == null) return;
      final repo = ref.read(companyRepoProvider);
      await repo.update(c.copyWith(isDefault: true));
      // The repository normalizes default and unsets other defaults.
      ref.invalidate(companyByIdProvider(companyId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Définie comme société par défaut')),
        );
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Détails société'),
        leading: IconButton(
          tooltip: 'Fermer',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          IconButton(
            tooltip: 'Copier',
            onPressed: onCopy,
            icon: const Icon(Icons.copy_all_outlined),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              switch (v) {
                case 'edit':
                  onEdit();
                  break;
                case 'delete':
                  onDelete();
                  break;
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, size: 18),
                    SizedBox(width: 8),
                    Text('Modifier'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, size: 18),
                    SizedBox(width: 8),
                    Text('Supprimer'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: async.when(
        data: (c) {
          if (c == null) {
            return const Center(child: Text('Société introuvable'));
          }
          final isPublished =
              ((c.status ?? '').toUpperCase().startsWith('PUBLISH')) &&
              c.isPublic == true;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    runSpacing: 10,
                    spacing: 16,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const CircleAvatar(child: Icon(Icons.business)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    c.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleLarge,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Tooltip(
                                  message: isPublished
                                      ? 'Publié'
                                      : 'Non publié',
                                  child: Icon(
                                    isPublished
                                        ? Icons.cloud_done_outlined
                                        : Icons.cloud_off_outlined,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                Chip(label: Text('Code: ${c.code}')),
                                Chip(label: Text('Statut: ${c.status ?? '—'}')),
                                Chip(
                                  label: Text(
                                    'Public: ${c.isPublic ? 'Oui' : 'Non'}',
                                  ),
                                ),
                                if ((c.currency ?? '').isNotEmpty)
                                  Chip(label: Text('Devise: ${c.currency}')),
                                // 🆕 visual for default
                                Chip(
                                  avatar: Icon(
                                    c.isDefault
                                        ? Icons.star
                                        : Icons.star_border,
                                    size: 18,
                                  ),
                                  label: Text(
                                    c.isDefault
                                        ? 'Par défaut'
                                        : 'Non par défaut',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Créé: ${Formatters.dateFull(c.createdAt)} • '
                              'Modifié: ${Formatters.dateFull(c.updatedAt)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      CompanyPublishActions(
                        company: c,
                        baseUri: marketplaceBaseUri,
                        onChanged: () => Navigator.of(context).maybePop(true),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _KV('Téléphone', c.phone ?? '—'),
              _KV('Email', c.email ?? '—'),
              _KV('Site web', c.website ?? '—'),
              _KV('N° fiscal', c.taxId ?? '—'),
              _KV(
                'Adresse',
                _addr(
                  c.addressLine1,
                  c.addressLine2,
                  c.city,
                  c.region,
                  c.country,
                  c.postalCode,
                ),
              ),
              const Divider(),
              _KV('Devise', c.currency ?? '—'),
              _KV('Par défaut', c.isDefault ? 'Oui' : 'Non'),
              _KV('ID', c.id),
              _KV('RemoteId', c.remoteId ?? '—'),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur: $e')),
      ),
      bottomNavigationBar: async.maybeWhen(
        data: (c) {
          if (c == null) return null;
          return SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 🆕 Button only if not already default
                  if (!c.isDefault) ...[
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: onSetDefault,
                        icon: const Icon(Icons.star),
                        label: const Text('Définir comme société par défaut'),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Modifier'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Supprimer'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        orElse: () => null,
      ),
    );
  }

  static String _addr(
    String? l1,
    String? l2,
    String? city,
    String? region,
    String? country,
    String? pc,
  ) {
    final parts = <String>[
      if ((l1 ?? '').trim().isNotEmpty) l1!.trim(),
      if ((l2 ?? '').trim().isNotEmpty) l2!.trim(),
      [city, region].where((e) => (e ?? '').trim().isNotEmpty).join(' ').trim(),
      [pc, country].where((e) => (e ?? '').trim().isNotEmpty).join(' ').trim(),
    ].where((e) => e.isNotEmpty).toList();
    return parts.isEmpty ? '—' : parts.join('\n');
  }
}

class _KV extends StatelessWidget {
  final String k;
  final String v;
  const _KV(this.k, this.v);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      title: Text(k, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(v),
      contentPadding: EdgeInsets.zero,
    );
  }
}
