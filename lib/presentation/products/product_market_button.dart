// Publish button that uploads product + images, persists remoteId/status locally, and notifies parent.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jaayko/domain/products/entities/product.dart';
import 'package:jaayko/infrastructure/products/product_marketplace_repo_provider.dart';

class ProductMarketButton extends ConsumerStatefulWidget {
  final Product product;
  final List<File> images;
  final String baseUri;
  final String? statusesCodeAfterPublish;
  final VoidCallback? onDone;

  const ProductMarketButton({
    super.key,
    required this.product,
    required this.images,
    required this.baseUri,
    this.statusesCodeAfterPublish,
    this.onDone,
  });

  @override
  ConsumerState<ProductMarketButton> createState() =>
      _ProductMarketButtonState();
}

class _ProductMarketButtonState extends ConsumerState<ProductMarketButton> {
  bool _loading = false;

  Future<void> _send() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final repo = ref.read(productMarketplaceRepoProvider(widget.baseUri));
      var updated = await repo.pushToMarketplace(widget.product, widget.images);

      if (widget.statusesCodeAfterPublish != null &&
          (updated.remoteId ?? '').isNotEmpty) {
        updated = await repo.changeRemoteStatus(
          product: updated,
          statusesCode: widget.statusesCodeAfterPublish!,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Publié: ${updated.name ?? 'Produit'}')),
      );
      widget.onDone?.call();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPublished =
        ((widget.product.remoteId ?? '').trim().isNotEmpty) ||
        widget.product.statuses == 'PUBLISHED';
    final disabled = _loading || isPublished || widget.images.isEmpty;
    final label = _loading
        ? 'Envoi…'
        : isPublished
        ? 'Déjà publié'
        : widget.images.isEmpty
        ? 'Ajouter une image'
        : 'Publier';

    return Tooltip(
      message: widget.images.isEmpty
          ? 'Ajoutez au moins une image'
          : (isPublished
                ? 'Le produit est déjà publié'
                : 'Publier sur le marché'),
      child: FilledButton.icon(
        onPressed: disabled ? null : _send,
        icon: _loading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.cloud_upload),
        label: Text(label),
      ),
    );
  }
}
