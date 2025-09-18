import 'dart:io';
import 'package:flutter/material.dart';
import 'package:money_pulse/domain/products/entities/product.dart';
import 'package:money_pulse/presentation/features/products/marketplace_mapper.dart';
import 'package:money_pulse/infrastructure/marketplace/marketplace_api.dart';

class ProductMarketButton extends StatefulWidget {
  final Product product;
  final List<File> images; // fichiers physiques à envoyer
  final String baseUri; // ex: "http://127.0.0.1:8095"
  final String? accountId; // si ton API le veut
  final String? unitId; // si ton API le veut

  const ProductMarketButton({
    super.key,
    required this.product,
    required this.images,
    required this.baseUri,
    this.accountId,
    this.unitId,
  });

  @override
  State<ProductMarketButton> createState() => _ProductMarketButtonState();
}

class _ProductMarketButtonState extends State<ProductMarketButton> {
  bool _loading = false;

  Future<void> _send() async {
    if (_loading) return;
    setState(() => _loading = true);

    try {
      final productJson = productToMarketplaceJson(
        widget.product,
        account: widget.accountId,
        unit: widget.unitId,
        localId: widget.product.id, // ex: utilise l'id local
      );

      final res = await MarketplaceApi.uploadProduct(
        baseUri: Uri.parse(widget.baseUri),
        productJson: productJson,
        files: widget.images,
      );

      final ok = res.statusCode >= 200 && res.statusCode < 300;
      final msg = ok
          ? 'Produit envoyé avec succès.'
          : 'Échec envoi (${res.statusCode}).';
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
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
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.storefront),
      label: Text(_loading ? 'Envoi…' : 'Envoyer'),
    );
  }
}
