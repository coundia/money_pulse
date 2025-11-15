// Responsive product list tile with formatted price and an optional thumbnail.
// Shows a colored status chip below the price. Supports local file or remote URL.
// NEW: remote sync indicator (cloud) shown before the title when `remoteId` is present.
// NEW: `logoUrl` fallback + spinner while images load.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:jaayko/presentation/shared/formatters.dart';
import 'product_context_menu.dart';

class ProductTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final int priceCents;
  final String? statuses;

  /// Highest priority: local image path (fast & offline)
  final String? imagePath;

  /// Next priority: product remote image URL
  final String? imageUrl;

  /// Fallback: a logo URL (e.g., company/product logo) to show if no product image is available
  final String? logoUrl;

  /// Shows cloud indicator when present
  final String? remoteId;

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
    this.logoUrl, // ← NEW
    this.remoteId,
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

    // 1) Local file
    if (imagePath != null &&
        imagePath!.isNotEmpty &&
        File(imagePath!).existsSync()) {
      return _roundedThumb(
        child: Image.file(
          File(imagePath!),
          fit: BoxFit.cover,
          width: size,
          height: size,
          errorBuilder: (_, __, ___) =>
              const Icon(Icons.image_not_supported_outlined),
        ),
        size: size,
      );
    }

    // Helper for network image with spinner & graceful fallback
    Widget _net(String url) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        width: size,
        height: size,
        // Tiny spinner while loading
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
        errorBuilder: (_, __, ___) =>
            const Icon(Icons.image_not_supported_outlined),
      );
    }

    // 2) Product remote URL
    if (imageUrl != null && imageUrl!.trim().isNotEmpty) {
      return _roundedThumb(child: _net(imageUrl!), size: size);
    }

    // 3) Logo URL fallback (requested)
    if (logoUrl != null && logoUrl!.trim().isNotEmpty) {
      return _roundedThumb(child: _net(logoUrl!), size: size);
    }

    // 4) App transparent 1px placeholder asset (keeps layout nice if you want a consistent box)
    // Make sure you have this in pubspec:
    // assets:
    //   - assets/transparent_1px.png
    return _roundedThumb(
      child: Image.asset(
        'assets/transparent_1px.png',
        fit: BoxFit.cover,
        width: size,
        height: size,
        errorBuilder: (_, __, ___) {
          // 5) Last fallback: an avatar with the initial
          return CircleAvatar(
            radius: size / 2,
            child: Text(
              (title.isNotEmpty ? title.characters.first : '?').toUpperCase(),
            ),
          );
        },
      ),
      size: size,
    );
  }

  Widget _roundedThumb({required Widget child, required double size}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(width: size, height: size, child: child),
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
    final hasRemote = (remoteId ?? '').trim().isNotEmpty;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPressStart: (details) =>
          _showContextMenu(context, details.globalPosition),
      child: ListTile(
        onTap: onTap,
        leading: _leadingThumb(context),

        // Title row with cloud indicator BEFORE the product title
        title: Row(
          children: [
            Tooltip(
              message: hasRemote
                  ? 'Synchronisé (remoteId présent)'
                  : 'Non synchronisé (pas de remoteId)',
              child: Icon(
                hasRemote
                    ? Icons.cloud_done_outlined
                    : Icons.cloud_off_outlined,
                size: 18,
                color: hasRemote
                    ? Theme.of(context).colorScheme.tertiary
                    : Theme.of(context).colorScheme.outline,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),

        // Optional subtitle if you want to show it
        subtitle: (subtitle == null || subtitle!.trim().isEmpty)
            ? null
            : Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis),

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
