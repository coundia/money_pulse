// Publish/Unpublish toolbar for Company; updates remote and keeps local in sync.
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

  bool get _isPublished {
    final s = (widget.company.status ?? '').toUpperCase();
    final pub = widget.company.isPublic;
    return (s == 'PUBLISH' || s == 'PUBLISHED') && pub == true;
  }

  Future<void> _doPublish() async {
    if (_loadingPublish) return;
    setState(() => _loadingPublish = true);
    try {
      final repo = ref.read(companyMarketplaceRepoProvider(widget.baseUri));
      await repo.publish(widget.company);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Publié avec succès')));
      widget.onChanged?.call();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    } finally {
      if (mounted) setState(() => _loadingPublish = false);
    }
  }

  Future<void> _doUnpublish() async {
    if (_loadingUnpublish) return;
    setState(() => _loadingUnpublish = true);
    try {
      final repo = ref.read(companyMarketplaceRepoProvider(widget.baseUri));
      await repo.unpublish(widget.company);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Publication retirée')));
      widget.onChanged?.call();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    } finally {
      if (mounted) setState(() => _loadingUnpublish = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final publishBtn = FilledButton.icon(
      onPressed: _isPublished || _loadingPublish ? null : _doPublish,
      icon: _loadingPublish
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.cloud_upload),
      label: const Text('Publier'),
    );

    final unpublishBtn = FilledButton.tonalIcon(
      onPressed: (!_isPublished || _loadingUnpublish) ? null : _doUnpublish,
      icon: _loadingUnpublish
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.unpublished_outlined),
      label: const Text('Retirer'),
    );

    return LayoutBuilder(
      builder: (_, bc) {
        final compact = bc.maxWidth < 520;
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [publishBtn, const SizedBox(height: 8), unpublishBtn],
          );
        }
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [publishBtn, unpublishBtn],
        );
      },
    );
  }
}
