import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

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

  Future<List<Category>> _load() => _repo.findAllActive();

  Future<void> _addOrEdit({Category? existing}) async {
    final result = await showDialog<_CategoryFormResult>(
      context: context,
      builder: (_) => _CategoryFormDialog(existing: existing),
    );
    if (result == null) return;

    try {
      if (existing == null) {
        final now = DateTime.now();
        final cat = Category(
          id: const Uuid().v4(),
          remoteId: null,
          code: result.code,
          description: result.description?.trim().isEmpty == true
              ? null
              : result.description!.trim(),
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
          description: result.description?.trim().isEmpty == true
              ? null
              : result.description!.trim(),
        );
        await _repo.update(updated);
      }
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
    }
  }

  Future<void> _delete(Category c) async {
    await _repo.softDelete(c.id);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addOrEdit(),
        icon: const Icon(Icons.add),
        label: const Text('Add category'),
      ),
      body: FutureBuilder<List<Category>>(
        future: _load(),
        builder: (context, snap) {
          final items = snap.data ?? const <Category>[];
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (items.isEmpty) {
            return const Center(child: Text('No categories'));
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final c = items[i];
              return ListTile(
                leading: CircleAvatar(
                  child: Text(
                    (c.code.isNotEmpty ? c.code[0] : '?').toUpperCase(),
                  ),
                ),
                title: Text(c.code),
                subtitle: Text(c.description ?? ''),
                onTap: () => _addOrEdit(existing: c),
                trailing: PopupMenuButton<String>(
                  onSelected: (v) {
                    switch (v) {
                      case 'edit':
                        _addOrEdit(existing: c);
                        break;
                      case 'delete':
                        _delete(c);
                        break;
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        leading: Icon(Icons.edit_outlined),
                        title: Text('Edit'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(Icons.delete_outline),
                        title: Text('Delete'),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/* ------------------------------ Add/Edit dialog ------------------------------ */

class _CategoryFormResult {
  final String code;
  final String? description;
  const _CategoryFormResult({required this.code, this.description});
}

class _CategoryFormDialog extends StatefulWidget {
  final Category? existing;
  const _CategoryFormDialog({this.existing});

  @override
  State<_CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends State<_CategoryFormDialog> {
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

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return AlertDialog(
      title: Text(isEdit ? 'Edit category' : 'Add category'),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _code,
                decoration: const InputDecoration(
                  labelText: 'Code (e.g. Food)',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
                autofocus: true,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _desc,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(
              context,
              _CategoryFormResult(
                code: _code.text.trim(),
                description: _desc.text.trim().isEmpty
                    ? null
                    : _desc.text.trim(),
              ),
            );
          },
          child: Text(isEdit ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}
