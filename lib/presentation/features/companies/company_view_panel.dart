import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/presentation/shared/formatters.dart';
import 'providers/company_detail_providers.dart';

// NEW
import 'package:money_pulse/presentation/widgets/right_drawer.dart';
import 'company_form_panel.dart';
import 'company_delete_panel.dart';

class CompanyViewPanel extends ConsumerWidget {
  final String companyId;
  const CompanyViewPanel({super.key, required this.companyId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(companyByIdProvider(companyId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Détails société'),
        leading: IconButton(
          tooltip: 'Fermer',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: async.when(
        data: (c) {
          if (c == null) {
            return const Center(child: Text('Société introuvable'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ListTile(
                title: Text(
                  c.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                subtitle: Text(c.code),
                leading: const CircleAvatar(child: Icon(Icons.business)),
              ),
              const Divider(),
              _Info('Téléphone', c.phone ?? '—'),
              _Info('Email', c.email ?? '—'),
              _Info('Site web', c.website ?? '—'),
              _Info('N° fiscal', c.taxId ?? '—'),
              _Info('Devise', c.currency ?? '—'),
              const Divider(),
              _Info(
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
              _Info('Par défaut', c.isDefault ? 'Oui' : 'Non'),
              _Info('Créé le', Formatters.dateFull(c.createdAt)),
              _Info('Mis à jour', Formatters.dateFull(c.updatedAt)),
              const Divider(),
              _Info('Identifiant', c.id),
              const SizedBox(height: 12),
              // Actions inline (optionnel si tu préfères en bas)
              // ListTile(
              //   contentPadding: EdgeInsets.zero,
              //   title: Row(
              //     children: [
              //       FilledButton.icon(
              //         onPressed: () async { /* idem boutons bas */ },
              //         icon: const Icon(Icons.edit_outlined),
              //         label: const Text('Modifier'),
              //       ),
              //       const SizedBox(width: 8),
              //       FilledButton.tonalIcon(
              //         onPressed: () async { /* idem boutons bas */ },
              //         icon: const Icon(Icons.delete_outline),
              //         label: const Text('Supprimer'),
              //       ),
              //     ],
              //   ),
              // ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur: $e')),
      ),

      // Boutons d’action en bas, un par ligne (UX cohérente avec tes autres écrans)
      bottomNavigationBar: async.maybeWhen(
        data: (c) {
          if (c == null) return null;

          Future<void> onEdit() async {
            final ok = await showRightDrawer<bool>(
              context,
              child: CompanyFormPanel(initial: c),
              widthFraction: 0.86,
              heightFraction: 0.96,
            );
            if (ok == true) {
              // Recharger la vue
              ref.invalidate(companyByIdProvider(companyId));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Société mise à jour')),
                );
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
              // Fermer la vue après suppression pour revenir à la liste
              Navigator.of(context).pop(true);
              // (Le parent peut rafraîchir sa liste via le résultat)
            }
          }

          return SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
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

class _Info extends StatelessWidget {
  final String title;
  final String value;
  const _Info(this.title, this.value);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      title: Text(title),
      subtitle: Text(value),
      contentPadding: EdgeInsets.zero,
    );
  }
}
