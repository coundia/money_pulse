// Category publish/unpublish actions that call remote create/put or local unpublish.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:money_pulse/domain/categories/entities/category.dart';
import 'package:money_pulse/infrastructure/categories/category_marketplace_repo_provider.dart';

class CategoryPublishActions extends ConsumerStatefulWidget {
  final Category category;
  final String baseUri;
  final VoidCallback? onChanged;

  const CategoryPublishActions({
    super.key,
    required this.category,
    required this.baseUri,
    this.onChanged,
  });

  @override
  ConsumerState<CategoryPublishActions> createState() =>
      _CategoryPublishActionsState();
}

class _CategoryPublishActionsState
    extends ConsumerState<CategoryPublishActions> {
  bool _loadingPublish = false;
  bool _loadingUnpublish = false;

  bool get _hasRemoteId => ((widget.category.remoteId ?? '').trim().isNotEmpty);

  Future<void> _doPublish() async {
    if (_loadingPublish) return;
    setState(() => _loadingPublish = true);
    try {
      final repo = ref.read(categoryMarketplaceRepoProvider(widget.baseUri));
      await repo.publish(widget.category);
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
      final repo = ref.read(categoryMarketplaceRepoProvider(widget.baseUri));
      await repo.unpublishLocal(widget.category);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Publication retirée localement')),
      );
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
    final canPublish = true;
    final canUnpublish = _hasRemoteId;

    final publishBtn = FilledButton.icon(
      onPressed: (!canPublish || _loadingPublish) ? null : _doPublish,
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
      onPressed: (!canUnpublish || _loadingUnpublish) ? null : _doUnpublish,
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
