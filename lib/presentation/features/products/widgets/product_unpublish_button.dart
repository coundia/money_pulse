// Button to unpublish product on marketplace with robust enable logic and clear tooltip.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jaayko/domain/products/entities/product.dart';
import 'package:jaayko/infrastructure/products/product_marketplace_repo_provider.dart';

class ProductUnpublishButton extends ConsumerStatefulWidget {
  final Product product;
  final String baseUri;
  final String statusesCode;
  final VoidCallback? onDone;

  const ProductUnpublishButton({
    super.key,
    required this.product,
    required this.baseUri,
    required this.statusesCode,
    this.onDone,
  });

  @override
  ConsumerState<ProductUnpublishButton> createState() =>
      _ProductUnpublishButtonState();
}

class _ProductUnpublishButtonState
    extends ConsumerState<ProductUnpublishButton> {
  bool _loading = false;

  bool get _hasRemoteId => ((widget.product.remoteId ?? '').trim().isNotEmpty);

  bool get _looksPublished {
    final s = (widget.product.statuses ?? '').toUpperCase().trim();
    return s == 'PUBLISH' || s == 'PUBLISHED';
  }

  Future<void> _unpublish() async {
    if (_loading) return;

    if (!_hasRemoteId) {
      // Impossible d'appeler l’API sans remoteId
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Impossible de retirer la publication : identifiant distant manquant. "
            "Rouvrez la fiche après synchronisation, ou republiez pour récupérer l'ID.",
          ),
        ),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final repo = ref.read(productMarketplaceRepoProvider(widget.baseUri));
      final updated = await repo.withdrawPublicationWithApi(
        product: widget.product,
        statusesCode: widget.statusesCode,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Publication retirée: ${updated.name ?? 'Produit'}'),
        ),
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
    final canAction = !_loading && (_hasRemoteId || _looksPublished);

    return Tooltip(
      message: canAction
          ? 'Retirer la publication'
          : (_loading
                ? 'Traitement en cours…'
                : (_hasRemoteId
                      ? 'Indisponible'
                      : 'ID distant manquant — rouvrez le produit après publication')),
      child: FilledButton.tonalIcon(
        onPressed: canAction ? _unpublish : null,
        icon: _loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.unpublished_outlined),
        label: Text(_loading ? 'Retrait…' : 'Retirer publication'),
      ),
    );
  }
}
