import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/presentation/app/providers.dart';

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

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(categoriesProvider);
    if (items.isEmpty) return const Center(child: Text('No categories'));
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemBuilder: (_, i) => ListTile(
        title: Text(items[i].code),
        subtitle: Text(items[i].description ?? ''),
      ),
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemCount: items.length,
    );
  }
}
