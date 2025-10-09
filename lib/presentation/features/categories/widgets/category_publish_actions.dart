// Category publish/unpublish actions that call remote and ensure local is in-sync,
// now requiring an authenticated user via requireAccess() before any action.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:money_pulse/domain/categories/entities/category.dart';
import 'package:money_pulse/infrastructure/categories/category_marketplace_repo_provider.dart';
import 'package:money_pulse/onboarding/presentation/providers/access_session_provider.dart'
    show requireAccess;

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

  bool get _isPublished {
    final s = (widget.category.status ?? '').toUpperCase();
    final pub = widget.category.isPublic;
    return (s == 'PUBLISH' || s == 'PUBLISHED') && pub == true;
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

  Future<void> _doPublish() async {
    // ✅ Exiger l'accès avant l'action
    if (!await _mustBeLoggedIn()) return;

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
    //  Exiger l'accès avant l'action
    if (!await _mustBeLoggedIn()) return;

    if (_loadingUnpublish) return;
    setState(() => _loadingUnpublish = true);
    try {
      final repo = ref.read(categoryMarketplaceRepoProvider(widget.baseUri));
      await repo.unpublish(widget.category);
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
