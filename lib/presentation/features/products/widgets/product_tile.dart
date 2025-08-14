import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ProductTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final int priceCents;
  final int? stockQty; // show stock on the list
  final VoidCallback? onTap;

  /// Actions via long-press:
  /// 'view' | 'edit' | 'delete' | 'share' | 'adjust'
  final Future<void> Function(String action)? onMenuAction;

  const ProductTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.priceCents,
    this.stockQty,
    this.onTap,
    this.onMenuAction,
  });

  String _money(int cents) {
    final v = cents / 100.0;
    return NumberFormat.currency(symbol: '', decimalDigits: 0).format(v);
  }

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
          value: 'adjust',
          child: ListTile(
            leading: Icon(Icons.tune),
            title: Text('Ajuster stock'),
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: ListTile(
            leading: Icon(Icons.delete_outline),
            title: Text('Supprimer'),
          ),
        ),
        PopupMenuDivider(),
        PopupMenuItem(
          value: 'share',
          child: ListTile(
            leading: Icon(Icons.ios_share),
            title: Text('Partager'),
          ),
        ),
      ],
    );
    if (result != null) {
      await onMenuAction!(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Always display a stock chip; default to 0 when null
    final qty = stockQty ?? 0;
    final positive = qty > 0;

    final stockChip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (positive
            ? Colors.green.withOpacity(.12)
            : Colors.red.withOpacity(.12)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        positive ? 'Stock: $qty' : 'Rupture',
        style: TextStyle(
          color: positive ? Colors.green.shade800 : Colors.red.shade700,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );

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
        // Compact trailing to avoid overflow on small screens
        trailing: Wrap(
          spacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [stockChip, Text(_money(priceCents))],
        ),
      ),
    );
  }
}
