import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:money_pulse/presentation/shared/formatters.dart';
import 'package:money_pulse/presentation/widgets/right_drawer.dart';
import 'package:money_pulse/presentation/app/providers.dart';

import 'package:money_pulse/domain/categories/entities/category.dart';
import 'package:money_pulse/domain/categories/repositories/category_repository.dart';

// Widgets internes
import 'widgets/category_form_panel.dart';
import 'widgets/category_tile.dart';
import 'widgets/category_context_menu.dart';
import 'widgets/category_details_panel.dart';

class CategoryListPage extends ConsumerStatefulWidget {
  const CategoryListPage({super.key});
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
        remoteId: null,
        code: result.code,
        description: _t(result.description),
        typeEntry: result.typeEntry, // ✅ prend la valeur du formulaire
        createdAt: now,
        updatedAt: now,
        deletedAt: null,
        syncAt: null,
        version: 0,
        isDirty: true,
      );

      await _repo.create(cat);
    } else {
      final updated = existing.copyWith(
        code: result.code,
        description: _t(result.description),
        typeEntry: result.typeEntry, // ✅ prend la valeur du formulaire
        updatedAt: DateTime.now(),
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

  Future<void> _share(Category c) async {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final text =
        'Catégorie: ${c.code}\n'
        'Description: ${c.description ?? '—'}\n'
        'Type: ${c.typeEntry}\n'
        'Mis à jour: ${_fmtDate(c.updatedAt)}\n'
        'Créée le: ${_fmtDate(c.createdAt)}\n'
        'ID: ${c.id}';
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
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
              c.typeEntry, // ✅ recherche aussi par type
            ].join(' ').toLowerCase();
            return s.contains(q);
          }).toList();
    filtered.sort(
      (a, b) => a.code.toLowerCase().compareTo(b.code.toLowerCase()),
    );
    return filtered;
  }

  Widget _header(List<Category> items) {
    final debitCount = items.where((e) => e.typeEntry == Category.debit).length;
    final creditCount = items
        .where((e) => e.typeEntry == Category.credit)
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
              avatar: const Icon(Icons.category_outlined, size: 18),
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
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _searchCtrl,
          decoration: InputDecoration(
            hintText: 'Rechercher par code, description ou type',
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            isDense: true,
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(k, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 6),
          Expanded(child: Text(v)),
        ],
      ),
    );
  }

  Future<void> _view(Category c) async {
    if (!mounted) return;
    await showRightDrawer<void>(
      context,
      child: CategoryDetailsPanel(
        category: c,
        onEdit: () {
          if (!mounted) return;
          _addOrEdit(existing: c);
        },
      ),
      widthFraction: 0.86,
      heightFraction: 0.96,
    );
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
                onRefresh: () async {
                  if (!mounted) return;
                  setState(() {});
                },
                child: items.isEmpty
                    ? _empty()
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 120),
                        itemBuilder: (_, i) {
                          if (i == 0) return _header(items);
                          final c = filtered[i - 1];
                          final updatedText =
                              'Mis à jour ${_fmtDate(c.updatedAt)}';
                          final subtitle = (c.description?.isNotEmpty == true)
                              ? c.description!
                              : updatedText;

                          return GestureDetector(
                            onLongPressStart: (d) =>
                                _showContextMenu(d.globalPosition, c),
                            onSecondaryTapDown: (d) =>
                                _showContextMenu(d.globalPosition, c),
                            child: CategoryTile(
                              code: c.code,
                              descriptionOrUpdatedText: subtitle,
                              onTap: () => _addOrEdit(existing: c),
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
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'refresh' && mounted) setState(() {});
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'refresh',
                    child: ListTile(
                      leading: Icon(Icons.refresh),
                      title: Text('Rafraîchir'),
                    ),
                  ),
                ],
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
