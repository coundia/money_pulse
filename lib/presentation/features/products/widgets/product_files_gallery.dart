// Gallery widget for listing product files with responsive grid and right-drawer preview.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:jaayko/domain/products/entities/product_file.dart';
import 'package:jaayko/presentation/widgets/right_drawer.dart';
import 'package:jaayko/presentation/features/products/product_file_repo_provider.dart';

final productFilesProvider = FutureProvider.autoDispose
    .family<List<ProductFile>, String>((ref, productId) async {
      final repo = ref.read(productFileRepoProvider);
      final rows = await repo.findByProduct(productId);

      print("productId ******");
      print(productId);
      print(rows);
      rows.sort((a, b) {
        final def = (b.isDefault ?? 0).compareTo(a.isDefault ?? 0);
        if (def != 0) return def;
        return b.updatedAt.compareTo(a.updatedAt);
      });
      return rows;
    });

class ProductFilesGallery extends ConsumerWidget {
  final String productId;
  const ProductFilesGallery({super.key, required this.productId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(productFilesProvider(productId));
    return async.when(
      data: (files) {
        if (files.isEmpty) {
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.image_outlined),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Aucun fichier lié à ce produit.'),
                  ),
                ],
              ),
            ),
          );
        }

        final images = files.where((f) {
          final mt = (f.mimeType ?? '').toLowerCase();
          return mt.startsWith('image/');
        }).toList();

        return _Section(
          title: 'Fichiers',
          trailing: Chip(
            label: Text('${files.length}'),
            visualDensity: VisualDensity.compact,
          ),
          child: LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth;
              int cross = 2;
              if (w >= 1080)
                cross = 6;
              else if (w >= 820)
                cross = 5;
              else if (w >= 640)
                cross = 4;
              else if (w >= 460)
                cross = 3;

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cross,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 1,
                ),
                itemCount: images.length,
                itemBuilder: (_, i) {
                  final f = images[i];
                  final path = f.filePath ?? '';
                  Widget thumb;
                  if (path.isEmpty || !File(path).existsSync()) {
                    thumb = _BrokenThumb(name: f.fileName ?? '—');
                  } else {
                    thumb = ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.file(File(path), fit: BoxFit.cover),
                          if ((f.isDefault ?? 0) == 1)
                            Align(
                              alignment: Alignment.topRight,
                              child: Container(
                                margin: const EdgeInsets.all(6),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Défaut',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  }

                  return InkWell(
                    onTap: () => _openPreview(context, f),
                    borderRadius: BorderRadius.circular(12),
                    child: thumb,
                  );
                },
              );
            },
          ),
        );
      },
      loading: () => const _LoadingCard(),
      error: (e, _) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.error_outline),
              const SizedBox(width: 8),
              Expanded(child: Text('Erreur de chargement des fichiers.')),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openPreview(BuildContext context, ProductFile f) async {
    final path = f.filePath ?? '';
    await showRightDrawer<void>(
      context,
      widthFraction: 0.92,
      heightFraction: 0.96,
      child: _ImagePreviewPanel(title: f.fileName ?? 'Aperçu', path: path),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  const _Section({required this.title, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: cs.surfaceVariant.withOpacity(0.35),
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.all(12),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SizedBox(
        height: 96,
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              SizedBox(width: 12),
              CircularProgressIndicator(),
              SizedBox(width: 12),
              Text('Chargement des fichiers…'),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrokenThumb extends StatelessWidget {
  final String name;
  const _BrokenThumb({required this.name});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.broken_image_outlined, size: 28),
            const SizedBox(height: 6),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImagePreviewPanel extends StatelessWidget {
  final String title;
  final String path;
  const _ImagePreviewPanel({required this.title, required this.path});

  @override
  Widget build(BuildContext context) {
    final file = File(path);
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          tooltip: 'Fermer',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: Center(
        child: file.existsSync()
            ? InteractiveViewer(
                minScale: 0.5,
                maxScale: 5,
                child: Image.file(file, fit: BoxFit.contain),
              )
            : const Text('Fichier introuvable.'),
      ),
    );
  }
}
