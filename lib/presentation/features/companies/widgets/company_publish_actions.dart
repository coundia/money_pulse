/* Publish/Unpublish/Republish actions: calls marketplace repo, reconciles, and invalidates providers.
   Now requires an authenticated user via requireAccess() before any action. */
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/domain/company/entities/company.dart';
import 'package:money_pulse/presentation/features/companies/providers/company_detail_providers.dart';
import 'package:money_pulse/presentation/features/companies/providers/company_list_providers.dart';
import 'package:money_pulse/onboarding/presentation/providers/access_session_provider.dart'
    show requireAccess;

import '../../../../infrastructure/company/repositories/company_marketplace_repo_provider.dart';

class CompanyPublishActions extends ConsumerStatefulWidget {
  final Company company;
  final String baseUri;
  final VoidCallback? onChanged;

  const CompanyPublishActions({
    super.key,
    required this.company,
    required this.baseUri,
    this.onChanged,
  });

  @override
  ConsumerState<CompanyPublishActions> createState() =>
      _CompanyPublishActionsState();
}

class _CompanyPublishActionsState extends ConsumerState<CompanyPublishActions> {
  bool _busy = false;

  bool get _isPublished {
    final s = (widget.company.status ?? '').toUpperCase();
    return (s.startsWith('PUBLISH')) && widget.company.isPublic == true;
  }

  Future<bool> _mustBeLoggedIn() async {
    final ok = await requireAccess(context, ref);
    if (!mounted) return false;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connexion requise pour cette action.')),
      );
    }
    return ok;
  }

  Future<void> _do(Future<Company> Function() op, String okMsg) async {
    if (_busy) return;

    // ✅ Exiger l'accès avant d'exécuter l'opération
    if (!await _mustBeLoggedIn()) return;

    setState(() => _busy = true);
    try {
      final repo = ref.read(companyMarketplaceRepoProvider(widget.baseUri));
      final updated =
          await op(); // publish/unpublish/republish already reconciles
      // Sécurité : s’assurer d’une réconciliation juste après
      await repo.reconcileFromRemote(updated);

      // Invalidate detail + list providers pour recharger la ligne locale
      ref.invalidate(companyByIdProvider(updated.id));
      ref.invalidate(companyListProvider);
      ref.invalidate(companyCountProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(okMsg)));
      }
      widget.onChanged?.call();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canPublish = !_isPublished;
    final canUnpublish = _isPublished;
    final canRepublish =
        !_isPublished; // gardé identique à votre logique actuelle

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.icon(
          onPressed: (!canPublish || _busy)
              ? null
              : () => _do(
                  () => ref
                      .read(companyMarketplaceRepoProvider(widget.baseUri))
                      .publish(widget.company),
                  'Société publiée',
                ),
          icon: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.cloud_upload),
          label: const Text('Publier'),
        ),
        FilledButton.tonalIcon(
          onPressed: (!canUnpublish || _busy)
              ? null
              : () => _do(
                  () => ref
                      .read(companyMarketplaceRepoProvider(widget.baseUri))
                      .unpublish(widget.company),
                  'Publication retirée',
                ),
          icon: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.unpublished_outlined),
          label: const Text('Retirer'),
        ),
        OutlinedButton.icon(
          onPressed: (!canRepublish || _busy)
              ? null
              : () => _do(
                  () => ref
                      .read(companyMarketplaceRepoProvider(widget.baseUri))
                      .republish(widget.company),
                  'Société republiée',
                ),
          icon: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh),
          label: const Text('Republier'),
        ),
      ],
    );
  }
}
