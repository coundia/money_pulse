// Publish/unpublish/republish toolbar for Company with strict reconcile after each action.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/domain/company/entities/company.dart';

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
  bool _loadingPublish = false;
  bool _loadingUnpublish = false;
  bool _loadingRepublish = false;

  bool get _hasRemoteId => ((widget.company.remoteId ?? '').trim().isNotEmpty);

  bool get _isPublished {
    final s = (widget.company.status ?? '').toUpperCase().trim();
    return (s.startsWith('PUBLISH')) && widget.company.isPublic == true;
  }

  Future<void> _doPublish() async {
    if (_loadingPublish) return;
    setState(() => _loadingPublish = true);
    final repo = ref.read(companyMarketplaceRepoProvider(widget.baseUri));
    try {
      await repo.publish(widget.company);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Publié: ${widget.company.name}')));
      widget.onChanged?.call();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur publication: $e')));
    } finally {
      if (mounted) setState(() => _loadingPublish = false);
    }
  }

  Future<void> _doUnpublish() async {
    if (_loadingUnpublish) return;
    setState(() => _loadingUnpublish = true);
    final repo = ref.read(companyMarketplaceRepoProvider(widget.baseUri));
    try {
      await repo.unpublish(widget.company);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Publication retirée: ${widget.company.name}')),
      );
      widget.onChanged?.call();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur retrait: $e')));
    } finally {
      if (mounted) setState(() => _loadingUnpublish = false);
    }
  }

  Future<void> _doRepublish() async {
    if (_loadingRepublish) return;
    setState(() => _loadingRepublish = true);
    final repo = ref.read(companyMarketplaceRepoProvider(widget.baseUri));
    try {
      await repo.republish(widget.company);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Republié: ${widget.company.name}')),
      );
      widget.onChanged?.call();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur republication: $e')));
    } finally {
      if (mounted) setState(() => _loadingRepublish = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canPublish = !_isPublished;
    final canUnpublish =
        _isPublished || _hasRemoteId; // autoriser unpublish si remoteId présent
    final canRepublish = !_isPublished; // visible si non publié

    return LayoutBuilder(
      builder: (_, bc) {
        final compact = bc.maxWidth < 520;

        final children = <Widget>[
          Tooltip(
            message: canPublish ? 'Publier' : 'Déjà publié',
            child: FilledButton.icon(
              onPressed: (!canPublish || _loadingPublish) ? null : _doPublish,
              icon: _loadingPublish
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_upload),
              label: const Text('Publier'),
            ),
          ),
          Tooltip(
            message: canUnpublish
                ? 'Retirer la publication'
                : (_hasRemoteId ? 'Indisponible' : 'ID distant manquant'),
            child: FilledButton.tonalIcon(
              onPressed: (!canUnpublish || _loadingUnpublish)
                  ? null
                  : _doUnpublish,
              icon: _loadingUnpublish
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_off_outlined),
              label: const Text('Retirer'),
            ),
          ),
          Tooltip(
            message: canRepublish ? 'Republier' : 'Déjà publié',
            child: OutlinedButton.icon(
              onPressed: (!canRepublish || _loadingRepublish)
                  ? null
                  : _doRepublish,
              icon: _loadingRepublish
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              label: const Text('Republier'),
            ),
          ),
        ];

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.start,
                children: children
                    .map((w) => SizedBox(width: double.infinity, child: w))
                    .toList(),
              ),
            ],
          );
        }

        return Wrap(spacing: 8, runSpacing: 8, children: children);
      },
    );
  }
}
