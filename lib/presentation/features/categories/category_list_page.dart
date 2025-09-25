// Orchestration page for Category: load/search/sort by updatedAt desc, sync from remote, open details with publish actions in a right drawer.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:money_pulse/presentation/shared/formatters.dart';
import 'package:money_pulse/presentation/widgets/right_drawer.dart';

import 'package:money_pulse/domain/categories/entities/category.dart';
import 'package:money_pulse/domain/categories/repositories/category_repository.dart';
import 'widgets/category_form_panel.dart';
import 'widgets/category_tile.dart';
import 'widgets/category_context_menu.dart';
import 'widgets/category_details_panel.dart';
import 'package:money_pulse/presentation/app/providers.dart';
import 'package:money_pulse/infrastructure/categories/category_pull_service.dart';

class CategoryListPage extends ConsumerStatefulWidget {
  final String marketplaceBaseUri;
  const CategoryListPage({
    super.key,
    this.marketplaceBaseUri = 'http://127.0.0.1:8095',
  });

  @override
  ConsumerState<CategoryListPage> createState() => _CategoryListPageState();
}

class _CategoryListPageState extends ConsumerState<CategoryListPage> {
  late final CategoryRepository _repo = ref.read(categoryRepoProvider);
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      if (!mounted) return;
      setState(() => _query = _searchCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<List<Category>> _load() => _repo.findAllActive();

  String? _t(String? s) {
    if (s == null) return null;
    final v = s.trim();
    return v.isEmpty ? null : v;
  }

  String _fmtDate(DateTime? d) => d == null ? '—' : Formatters.dateFull(d);

  Future<void> _addOrEdit({Category? existing}) async {
    if (!mounted) return;
    final result = await showRightDrawer<CategoryFormResult>(
      context,
      child: CategoryFormPanel(existing: existing),
      widthFraction: 0.86,
      heightFraction: 0.96,
    );
    if (!mounted || result == null) return;

    if (existing == null) {
      final now = DateTime.now();
      final cat = Category(
        id: const Uuid().v4(),
        localId: null,
        remoteId: null,
        code: result.code,
        description: _t(result.description),
        typeEntry: result.typeEntry,
        createdAt: now,
        updatedAt: now,
        deletedAt: null,
        syncAt: null,
        account: null,
        version: 0,
        isDirty: true,
        status: null,
        isPublic: true,
      );
      await _repo.create(cat);
    } else {
      final updated = existing.copyWith(
        code: result.code,
        description: _t(result.description),
        typeEntry: result.typeEntry,
        updatedAt: DateTime.now(),
        isDirty: true,
      );
      await _repo.update(updated);
    }
    if (mounted) setState(() {});
  }

  Future<void> _delete(Category c) async {
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer la catégorie ?'),
        content: Text('« ${c.code} » sera déplacée dans la corbeille.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (!mounted || ok != true) return;
    await _repo.softDelete(c.id);
    if (mounted) setState(() {});
  }

  Future<void> _view(Category c) async {
    if (!mounted) return;
    await showRightDrawer<void>(
      context,
      child: CategoryDetailsPanel(
        category: c,
        marketplaceBaseUri: widget.marketplaceBaseUri,
        onEdit: () => _addOrEdit(existing: c),
        onDelete: () async {
          await _repo.softDelete(c.id);
          if (mounted) setState(() {});
        },
      ),
      widthFraction: 0.86,
      heightFraction: 0.96,
    );
    if (mounted) setState(() {});
  }

  Future<void> _share(Category c) async {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final text =
        'Catégorie: ${c.code}\n'
        'Description: ${c.description ?? '—'}\n'
        'Type: ${c.typeEntry}\n'
        'Mis à jour: ${_fmtDate(c.updatedAt)}\n'
        'Créée le: ${_fmtDate(c.createdAt)}';
    await Clipboard.setData(ClipboardData(text: text));
    messenger?.showSnackBar(
      const SnackBar(content: Text('Détails copiés dans le presse-papiers')),
    );
  }

  List<Category> _filterAndSort(List<Category> items) {
    final base = List<Category>.of(items);
    final q = _query;
    final filtered = q.isEmpty
        ? base
        : base.where((c) {
            final s = [
              c.code,
              c.description ?? '',
              c.remoteId ?? '',
              c.typeEntry,
              c.status ?? '',
            ].join(' ').toLowerCase();
            return s.contains(q);
          }).toList();

    filtered.sort((a, b) {
      final ad = a.updatedAt ?? a.createdAt;
      final bd = b.updatedAt ?? b.createdAt;
      return (bd).compareTo(ad);
    });
    return filtered;
  }

  Future<void> _showContextMenu(Offset position, Category c) async {
    if (!mounted) return;
    final action = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: buildCategoryContextMenuItems(),
    );
    if (!mounted) return;
    switch (action) {
      case CategoryContextMenu.view:
        _view(c);
        break;
      case CategoryContextMenu.edit:
        _addOrEdit(existing: c);
        break;
      case CategoryContextMenu.delete:
        _delete(c);
        break;
      case CategoryContextMenu.share:
        _share(c);
        break;
      default:
        break;
    }
  }

  Future<void> _syncNow() async {
    final svc = ref.read(
      categoryPullServiceProvider(widget.marketplaceBaseUri),
    );
    final n = await svc.syncAll(pageSize: 200);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$n éléments synchronisés')));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Category>>(
      future: _load(),
      builder: (context, snap) {
        final items = snap.data ?? const <Category>[];
        final filtered = _filterAndSort(items);

        final body = snap.connectionState == ConnectionState.waiting
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: () async => setState(() {}),
                child: items.isEmpty
                    ? _empty()
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 120),
                        itemBuilder: (_, i) {
                          if (i == 0) return _header(items);
                          final c = filtered[i - 1];
                          final subtitle = (c.description?.isNotEmpty == true)
                              ? c.description!
                              : 'Mis à jour ${_fmtDate(c.updatedAt)}';
                          return GestureDetector(
                            onLongPressStart: (d) =>
                                _showContextMenu(d.globalPosition, c),
                            onSecondaryTapDown: (d) =>
                                _showContextMenu(d.globalPosition, c),
                            child: CategoryTile(
                              code: c.code,
                              descriptionOrUpdatedText: subtitle,
                              onTap: () => _view(c),
                              onMore: () {
                                final box =
                                    context.findRenderObject() as RenderBox?;
                                final offset =
                                    box?.localToGlobal(Offset.zero) ??
                                    Offset.zero;
                                _showContextMenu(offset, c);
                              },
                            ),
                          );
                        },
                        separatorBuilder: (_, i) => i == 0
                            ? const SizedBox.shrink()
                            : const Divider(height: 1),
                        itemCount: filtered.isEmpty ? 1 : filtered.length + 1,
                      ),
              );

        return Scaffold(
          appBar: AppBar(
            title: const Text('Catégories'),
            actions: [
              IconButton(
                onPressed: () => _addOrEdit(),
                icon: const Icon(Icons.add),
                tooltip: 'Ajouter une catégorie',
              ),
              IconButton(
                onPressed: _syncNow,
                icon: const Icon(Icons.sync),
                tooltip: 'Synchroniser',
              ),
              IconButton(
                onPressed: () => setState(() {}),
                icon: const Icon(Icons.refresh),
                tooltip: 'Rafraîchir',
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _addOrEdit(),
            icon: const Icon(Icons.add),
            label: const Text('Ajouter une catégorie'),
          ),
          body: body,
        );
      },
    );
  }

  Widget _header(List<Category> items) {
    final debitCount = items.where((e) => e.typeEntry == Category.debit).length;
    final creditCount = items
        .where((e) => e.typeEntry == Category.credit)
        .length;
    final publishedCount = items
        .where((e) => (e.remoteId ?? '').isNotEmpty)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text('Catégories', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Chip(
              avatar: const Icon(Icons.list_alt, size: 18),
              label: Text('Total: ${items.length}'),
            ),
            Chip(
              avatar: const Icon(Icons.remove_circle_outline, size: 18),
              label: Text('Débit: $debitCount'),
            ),
            Chip(
              avatar: const Icon(Icons.add_circle_outline, size: 18),
              label: Text('Crédit: $creditCount'),
            ),
            Chip(
              avatar: const Icon(Icons.cloud_done_outlined, size: 18),
              label: Text('Publiés: $publishedCount'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _searchCtrl,
          decoration: InputDecoration(
            hintText: 'Rechercher par code, description, type ou statut',
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            isDense: true,
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _empty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.category_outlined, size: 72),
            const SizedBox(height: 12),
            const Text(
              'Aucune catégorie',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            const Text(
              'Créez votre première catégorie pour organiser vos transactions.',
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _addOrEdit(),
              icon: const Icon(Icons.add),
              label: const Text('Ajouter une catégorie'),
            ),
          ],
        ),
      ),
    );
  }
}
