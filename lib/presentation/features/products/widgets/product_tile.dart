// Responsive product list tile with formatted price and a colored status chip replacing stock badge.
import 'package:flutter/material.dart';
import 'package:money_pulse/presentation/shared/formatters.dart';
import 'product_context_menu.dart';

class ProductTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final int priceCents;
  final String? statuses;
  final VoidCallback? onTap;
  final Future<void> Function(String action)? onMenuAction;

  const ProductTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.priceCents,
    this.statuses,
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

  @override
  Widget build(BuildContext context) {
    final price = Formatters.amountFromCents(priceCents);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPressStart: (details) =>
          _showContextMenu(context, details.globalPosition),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          child: Text(
            (title.isNotEmpty ? title.characters.first : '?').toUpperCase(),
          ),
        ),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: (subtitle == null || subtitle!.isEmpty)
            ? null
            : Text(subtitle!),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('$price', style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}
