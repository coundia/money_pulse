// UI button to send product with images to marketplace
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/domain/products/entities/product.dart';
import 'package:money_pulse/infrastructure/products/product_marketplace_repo_provider.dart';

class ProductMarketButton extends ConsumerStatefulWidget {
  final Product product;
  final List<File> images;
  final String baseUri;

  const ProductMarketButton({
    super.key,
    required this.product,
    required this.images,
    required this.baseUri,
  });

  @override
  ConsumerState<ProductMarketButton> createState() =>
      _ProductMarketButtonState();
}

class _ProductMarketButtonState extends ConsumerState<ProductMarketButton> {
  bool _loading = false;

  Future<void> _send() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(productMarketplaceRepoProvider(widget.baseUri));
      await repo.pushToMarketplace(widget.product, widget.images);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Produit envoyé au marché !')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: _loading ? null : _send,
      icon: _loading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.cloud_upload),
      label: const Text('Envoyer au marché'),
    );
  }
}
