import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:money_pulse/presentation/app/providers.dart';
import 'package:money_pulse/domain/categories/entities/category.dart';

class CategoryFormSheet extends ConsumerStatefulWidget {
  final Category? category;
  const CategoryFormSheet({super.key, this.category});

  @override
  ConsumerState<CategoryFormSheet> createState() => _CategoryFormSheetState();
}

class _CategoryFormSheetState extends ConsumerState<CategoryFormSheet> {
  final formKey = GlobalKey<FormState>();
  final codeCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final c = widget.category;
    if (c != null) {
      codeCtrl.text = c.code;
      descCtrl.text = c.description ?? '';
    }
  }

  @override
  void dispose() {
    codeCtrl.dispose();
    descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!formKey.currentState!.validate()) return;
    setState(() => saving = true);
    final repo = ref.read(categoryRepoProvider);
    final now = DateTime.now();
    final code = codeCtrl.text.trim().toUpperCase().replaceAll(' ', '_');
    final desc = descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim();
    try {
      if (widget.category == null) {
        final c = Category(
          id: const Uuid().v4(),
          code: code,
          description: desc,
          createdAt: now,
          updatedAt: now,
          version: 0,
          isDirty: true,
        );
        await repo.create(c);
      } else {
        final updated = widget.category!.copyWith(
          code: code,
          description: desc,
        );
        await repo.update(updated);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => saving = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: insets),
      child: Form(
        key: formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: codeCtrl,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Code',
                ),
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: descCtrl,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Description',
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: saving ? null : _submit,
                icon: const Icon(Icons.check),
                label: Text(
                  saving
                      ? 'Saving...'
                      : (widget.category == null ? 'Save' : 'Update'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
