// Responsive product list tile with formatted price and an optional thumbnail.
// Shows a colored status chip below the price. Supports local file or remote URL.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:money_pulse/presentation/shared/formatters.dart';
import 'product_context_menu.dart';

class ProductTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final int priceCents;
  final String? statuses;
  final String? imagePath; // local file path (preferred if present)
  final String? imageUrl; // remote url fallback
  final VoidCallback? onTap;
  final Future<void> Function(String action)? onMenuAction;

  const ProductTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.priceCents,
    this.statuses,
    this.imagePath,
    this.imageUrl,
    this.onTap,
    this.onMenuAction,
  });

  Future<void> _showContextMenu(BuildContext context, Offset globalPos) async {
    if (onMenuAction == null) return;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPos.dx,
        globalPos.dy,
        overlay.size.width - globalPos.dx,
        overlay.size.height - globalPos.dy,
      ),
      items: buildProductContextMenuItems(),
    );
    if (result != null) {
      await onMenuAction!(result);
    }
  }

  Widget _leadingThumb(BuildContext context) {
    const double size = 48;
    Widget img;

    if (imagePath != null &&
        imagePath!.isNotEmpty &&
        File(imagePath!).existsSync()) {
      img = Image.file(
        File(imagePath!),
        fit: BoxFit.cover,
        width: size,
        height: size,
        errorBuilder: (_, __, ___) =>
            const Icon(Icons.image_not_supported_outlined),
      );
    } else if (imageUrl != null && imageUrl!.isNotEmpty) {
      img = Image.network(
        imageUrl!,
        fit: BoxFit.cover,
        width: size,
        height: size,
        errorBuilder: (_, __, ___) =>
            const Icon(Icons.image_not_supported_outlined),
      );
    } else {
      // Fallback avatar with initial
      return CircleAvatar(
        radius: size / 2,
        child: Text(
          (title.isNotEmpty ? title.characters.first : '?').toUpperCase(),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(width: size, height: size, child: img),
    );
  }

  Color _statusBg(String s, ColorScheme cs) {
    switch (s) {
      case 'PUBLISH':
      case 'PUBLISHED':
        return Colors.green.withOpacity(.12);
      case 'UNPUBLISH':
      case 'ARCHIVED':
        return cs.surfaceVariant;
      case 'DELETE':
        return Colors.red.withOpacity(.12);
      case 'PROMO':
        return Colors.orange.withOpacity(.14);
      default:
        return cs.surfaceVariant;
    }
  }

  Color _statusFg(String s, ColorScheme cs) {
    switch (s) {
      case 'PUBLISH':
      case 'PUBLISHED':
        return Colors.green.shade800;
      case 'UNPUBLISH':
      case 'ARCHIVED':
        return cs.onSurfaceVariant;
      case 'DELETE':
        return Colors.red.shade700;
      case 'PROMO':
        return Colors.orange.shade800;
      default:
        return cs.onSurfaceVariant;
    }
  }

  Widget _statusChip(BuildContext context) {
    final s = (statuses ?? '').trim();
    if (s.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _statusBg(s, cs),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        s,
        style: TextStyle(
          color: _statusFg(s, cs),
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final price = Formatters.amountFromCents(priceCents);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPressStart: (details) =>
          _showContextMenu(context, details.globalPosition),
      child: ListTile(
        onTap: onTap,
        leading: _leadingThumb(context),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),

        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('$price', style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            _statusChip(context),
          ],
        ),
      ),
    );
  }
}
