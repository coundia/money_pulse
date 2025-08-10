import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/presentation/app/providers.dart';
import 'package:money_pulse/presentation/features/categories/category_form_sheet.dart';
import 'package:money_pulse/domain/categories/entities/category.dart';

class CategoryListPage extends ConsumerStatefulWidget {
  const CategoryListPage({super.key});

  @override
  ConsumerState<CategoryListPage> createState() => _CategoryListPageState();
}

class _CategoryListPageState extends ConsumerState<CategoryListPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(categoriesProvider.notifier).load();
    });
  }

  Future<void> _reload() async {
    await ref.read(categoriesProvider.notifier).load();
  }

  Future<bool?> _confirmDelete(BuildContext context, Category c) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete category?'),
        content: Text(c.code),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(categoriesProvider);
    if (items.isEmpty) return const Center(child: Text('No categories'));
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemBuilder: (_, i) {
        final c = items[i];
        return Dismissible(
          key: ValueKey(c.id),
          direction: DismissDirection.endToStart,
          confirmDismiss: (_) => _confirmDelete(context, c),
          background: Container(
            alignment: Alignment.centerRight,
            color: Colors.red,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          onDismissed: (_) async {
            await ref.read(categoryRepoProvider).softDelete(c.id);
            await _reload();
            if (mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('Deleted ${c.code}')));
            }
          },
          child: ListTile(
            title: Text(c.code),
            subtitle: Text(c.description ?? ''),
            onTap: () async {
              final ok = await showModalBottomSheet<bool>(
                context: context,
                isScrollControlled: true,
                builder: (_) => CategoryFormSheet(category: c),
              );
              if (ok == true) {
                await _reload();
              }
            },
            trailing: IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () async {
                final ok = await showModalBottomSheet<bool>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => CategoryFormSheet(category: c),
                );
                if (ok == true) {
                  await _reload();
                }
              },
            ),
          ),
        );
      },
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemCount: items.length,
    );
  }
}
