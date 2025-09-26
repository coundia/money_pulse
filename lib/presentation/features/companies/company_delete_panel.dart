// lib/presentation/features/companies/company_delete_panel.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../infrastructure/company/repositories/company_marketplace_repo_provider.dart';
import '../../app/providers/company_repo_provider.dart';
import 'providers/company_detail_providers.dart';
// ⚠️ Adapte ce chemin si nécessaire pour atteindre le provider du repo marketplace.

class CompanyDeletePanel extends ConsumerStatefulWidget {
  final String companyId;
  final String marketplaceBaseUri;

  const CompanyDeletePanel({
    super.key,
    required this.companyId,
    this.marketplaceBaseUri = 'http://127.0.0.1:8095',
  });

  @override
  ConsumerState<CompanyDeletePanel> createState() => _CompanyDeletePanelState();
}

class _CompanyDeletePanelState extends ConsumerState<CompanyDeletePanel> {
  bool _alsoRemote = true;
  bool _busy = false;
  String? _error;

  Future<void> _confirm() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      // Charger la société pour affichage et pour passer au repo
      final company = await ref.read(
        companyByIdProvider(widget.companyId).future,
      );
      if (company == null) {
        throw Exception("Société introuvable");
      }

      if (_alsoRemote) {
        // Supprimer côté API puis soft delete local
        final marketplace = ref.read(
          companyMarketplaceRepoProvider(widget.marketplaceBaseUri),
        );
        // Appel direct delete + soft delete
        await marketplace.deleteRemoteAndSoftDeleteLocal(company);
      } else {
        // Seulement local
        await ref.read(companyRepoProvider).softDelete(widget.companyId);
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(companyByIdProvider(widget.companyId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Supprimer la société'),
        leading: IconButton(
          tooltip: 'Fermer',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur: $e')),
        data: (c) {
          if (c == null) {
            return const Center(child: Text('Société introuvable'));
          }

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.business)),
                  title: Text(
                    c.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    'Code: ${c.code}  •  RemoteId: ${c.remoteId ?? '—'}',
                  ),
                ),
                const SizedBox(height: 8),
                const ListTile(
                  leading: Icon(Icons.warning_amber_rounded, color: Colors.red),
                  title: Text('Confirmer la suppression ?'),
                  subtitle: Text(
                    'Cette action effectue un "soft delete" en local.',
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile.adaptive(
                  value: _alsoRemote,
                  onChanged: _busy
                      ? null
                      : (v) => setState(() => _alsoRemote = v),
                  title: const Text('Supprimer aussi côté serveur'),
                  subtitle: const Text(
                    'Appelle l’API de suppression distante avant de supprimer localement',
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: _busy
                            ? null
                            : () => Navigator.of(context).pop(false),
                        child: const Text('Annuler'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: _busy ? null : _confirm,
                        icon: _busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.delete_outline),
                        label: const Text('Supprimer'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
