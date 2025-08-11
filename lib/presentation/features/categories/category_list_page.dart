import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:money_pulse/presentation/shared/formatters.dart';
import 'package:money_pulse/presentation/widgets/right_drawer.dart';
import 'package:money_pulse/presentation/app/providers.dart';
import 'package:money_pulse/domain/categories/entities/category.dart';
import 'package:money_pulse/domain/categories/repositories/category_repository.dart';

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
    final result = await showRightDrawer<_CategoryFormResult>(
      context,
      child: _CategoryFormPanel(existing: existing),
      widthFraction: 0.86,
      heightFraction: 0.96,
    );
    if (result == null) return;
    if (existing == null) {
      final now = DateTime.now();
      final cat = Category(
        id: const Uuid().v4(),
        remoteId: null,
        code: result.code,
        description: _t(result.description),
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
        updatedAt: DateTime.now(),
      );
      await _repo.update(updated);
    }
    if (mounted) setState(() {});
  }

  Future<void> _delete(Category c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer la catégorie ?'),
        content: Text('« ${c.code} » sera déplacée dans la corbeille.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _repo.softDelete(c.id);
      if (mounted) setState(() {});
    }
  }

  Future<void> _share(Category c) async {
    final text =
        'Catégorie: ${c.code}\nDescription: ${c.description ?? '—'}\nMis à jour: ${_fmtDate(c.updatedAt)}\nCréée le: ${_fmtDate(c.createdAt)}\nID: ${c.id}';
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
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
            ].join(' ').toLowerCase();
            return s.contains(q);
          }).toList();
    filtered.sort(
      (a, b) => a.code.toLowerCase().compareTo(b.code.toLowerCase()),
    );
    return filtered;
  }

  Widget _header(List<Category> items) {
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
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _searchCtrl,
          decoration: InputDecoration(
            hintText: 'Rechercher par code ou description',
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
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Détails de la catégorie'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _kv('Code', c.code),
              _kv('Description', c.description ?? '—'),
              const SizedBox(height: 8),
              _kv('ID distant', c.remoteId ?? '—'),
              const SizedBox(height: 8),
              _kv('Créée le', _fmtDate(c.createdAt)),
              _kv('Mis à jour le', _fmtDate(c.updatedAt)),
              _kv('Supprimée le', _fmtDate(c.deletedAt)),
              _kv('Synchronisée le', _fmtDate(c.syncAt)),
              _kv('Version', '${c.version}'),
              const SizedBox(height: 8),
              const Text('ID', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              SelectableText(c.id),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _addOrEdit(existing: c);
            },
            child: const Text('Modifier'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Future<void> _showContextMenu(Offset position, Category c) async {
    final v = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: const [
        PopupMenuItem(
          value: 'view',
          child: ListTile(
            leading: Icon(Icons.visibility_outlined),
            title: Text('Voir'),
          ),
        ),
        PopupMenuItem(
          value: 'edit',
          child: ListTile(
            leading: Icon(Icons.edit_outlined),
            title: Text('Modifier'),
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: ListTile(
            leading: Icon(Icons.delete_outline),
            title: Text('Supprimer'),
          ),
        ),
        PopupMenuItem(
          value: 'share',
          child: ListTile(
            leading: Icon(Icons.share_outlined),
            title: Text('Copier les détails'),
          ),
        ),
      ],
    );
    switch (v) {
      case 'view':
        _view(c);
        break;
      case 'edit':
        _addOrEdit(existing: c);
        break;
      case 'delete':
        _delete(c);
        break;
      case 'share':
        _share(c);
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
                onRefresh: () async => setState(() {}),
                child: items.isEmpty
                    ? _empty()
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 120),
                        itemBuilder: (_, i) {
                          if (i == 0) return _header(items);
                          final c = filtered[i - 1];
                          final updatedText =
                              'Mis à jour ${_fmtDate(c.updatedAt)}';
                          return GestureDetector(
                            onLongPressStart: (d) =>
                                _showContextMenu(d.globalPosition, c),
                            onSecondaryTapDown: (d) =>
                                _showContextMenu(d.globalPosition, c),
                            child: ListTile(
                              leading: CircleAvatar(
                                child: Text(
                                  (c.code.isNotEmpty ? c.code[0] : '?')
                                      .toUpperCase(),
                                ),
                              ),
                              title: Text(c.code),
                              subtitle: Text(
                                c.description?.isNotEmpty == true
                                    ? c.description!
                                    : updatedText,
                              ),
                              onTap: () => _addOrEdit(existing: c),
                              trailing: IconButton(
                                tooltip: 'Actions',
                                onPressed: () async {
                                  final box =
                                      context.findRenderObject() as RenderBox?;
                                  final offset =
                                      box?.localToGlobal(Offset.zero) ??
                                      Offset.zero;
                                  _showContextMenu(offset, c);
                                },
                                icon: const Icon(Icons.more_vert),
                              ),
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
                  if (v == 'refresh') setState(() {});
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

class _CategoryFormResult {
  final String code;
  final String? description;
  const _CategoryFormResult({required this.code, this.description});
}

class _CategoryFormPanel extends StatefulWidget {
  final Category? existing;
  const _CategoryFormPanel({this.existing});
  @override
  State<_CategoryFormPanel> createState() => _CategoryFormPanelState();
}

class _CategoryFormPanelState extends State<_CategoryFormPanel> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _code = TextEditingController(
    text: widget.existing?.code ?? '',
  );
  late final TextEditingController _desc = TextEditingController(
    text: widget.existing?.description ?? '',
  );

  @override
  void dispose() {
    _code.dispose();
    _desc.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      _CategoryFormResult(
        code: _code.text.trim(),
        description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(isEdit ? 'Modifier la catégorie' : 'Ajouter une catégorie'),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text(isEdit ? 'Enregistrer' : 'Ajouter'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _code,
              decoration: const InputDecoration(
                labelText: 'Code',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
              autofocus: true,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _desc,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
