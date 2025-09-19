// Three-action toolbar to publish, unpublish, and republish a product, handling remoteId presence and images requirement.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/domain/products/entities/product.dart';
import 'package:money_pulse/infrastructure/products/product_marketplace_repo_provider.dart';

class ProductPublishActions extends ConsumerStatefulWidget {
  final Product product;
  final String baseUri;
  final List<File> images;
  final VoidCallback? onChanged;

  const ProductPublishActions({
    super.key,
    required this.product,
    required this.baseUri,
    required this.images,
    this.onChanged,
  });

  @override
  ConsumerState<ProductPublishActions> createState() =>
      _ProductPublishActionsState();
}

class _ProductPublishActionsState extends ConsumerState<ProductPublishActions> {
  bool _loadingPublish = false;
  bool _loadingUnpublish = false;
  bool _loadingRepublish = false;

  bool get _hasRemoteId => ((widget.product.remoteId ?? '').trim().isNotEmpty);

  bool get _isPublished {
    final s = (widget.product.statuses ?? '').toUpperCase().trim();
    return s == 'PUBLISH' || s == 'PUBLISHED';
  }

  Future<void> _doPublish() async {
    if (_loadingPublish) return;
    setState(() => _loadingPublish = true);
    final repo = ref.read(productMarketplaceRepoProvider(widget.baseUri));
    try {
      var current = widget.product;
      if (!_hasRemoteId) {
        if (widget.images.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ajoutez au moins une image pour publier.'),
            ),
          );
          return;
        }
        current = await repo.pushToMarketplace(current, widget.images);
      }
      await repo.changeRemoteStatus(product: current, statusesCode: 'PUBLISH');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Publié: ${current.name ?? "Produit"}')),
      );
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
    if (!_hasRemoteId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Impossible de retirer la publication: identifiant distant manquant.",
          ),
        ),
      );
      return;
    }
    setState(() => _loadingUnpublish = true);
    final repo = ref.read(productMarketplaceRepoProvider(widget.baseUri));
    try {
      await repo.changeRemoteStatus(
        product: widget.product,
        statusesCode: 'UNPUBLISH',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Publication retirée: ${widget.product.name ?? "Produit"}',
          ),
        ),
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

  Future<void> _doRepublish() async {
    if (_loadingRepublish) return;
    setState(() => _loadingRepublish = true);
    final repo = ref.read(productMarketplaceRepoProvider(widget.baseUri));
    try {
      var current = widget.product;
      if (!_hasRemoteId) {
        if (widget.images.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ajoutez au moins une image pour republier.'),
            ),
          );
          return;
        }
        current = await repo.pushToMarketplace(current, widget.images);
      }
      await repo.changeRemoteStatus(product: current, statusesCode: 'PUBLISH');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Republié: ${current.name ?? "Produit"}')),
      );
      widget.onChanged?.call();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    } finally {
      if (mounted) setState(() => _loadingRepublish = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canPublish = !_isPublished;
    final canUnpublish = _isPublished && _hasRemoteId;
    final canRepublish =
        !_isPublished; // republish behaves like publish but label differs

    return LayoutBuilder(
      builder: (_, bc) {
        final compact = bc.maxWidth < 520;
        final children = <Widget>[
          Tooltip(
            message: canPublish ? 'Publier sur le marché' : 'Déjà publié',
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
                  : const Icon(Icons.unpublished_outlined),
              label: const Text('Retirer'),
            ),
          ),
          Tooltip(
            message: canRepublish ? 'Republier sur le marché' : 'Déjà publié',
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
