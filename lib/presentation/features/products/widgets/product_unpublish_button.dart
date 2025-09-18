// Button to unpublish a product and mark it dirty locally.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/domain/products/entities/product.dart';
import 'package:money_pulse/infrastructure/products/product_marketplace_repo_provider.dart';

class ProductUnpublishButton extends ConsumerStatefulWidget {
  final Product product;
  final String baseUri;

  const ProductUnpublishButton({
    super.key,
    required this.product,
    required this.baseUri,
  });

  @override
  ConsumerState<ProductUnpublishButton> createState() =>
      _ProductUnpublishButtonState();
}

class _ProductUnpublishButtonState
    extends ConsumerState<ProductUnpublishButton> {
  bool _loading = false;

  Future<void> _unpublish() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final repo = ref.read(productMarketplaceRepoProvider(widget.baseUri));
      final updated = await repo.withdrawPublication(widget.product);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Publication retirée: ${updated.name ?? updated.code ?? 'Produit'}',
          ),
        ),
      );
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
    return FilledButton.tonalIcon(
      onPressed: isPublished && !_loading ? _unpublish : null,
      icon: _loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.unpublished_outlined),
      label: Text(_loading ? 'Retrait…' : 'Retirer publication'),
    );
  }
}
