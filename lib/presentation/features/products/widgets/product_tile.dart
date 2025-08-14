// lib/presentation/features/products/widgets/product_tile.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ProductTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final int priceCents;
  final VoidCallback? onTap;

  /// Actions possibles :
  /// 'view' | 'edit' | 'delete' | 'share' | 'adjust'
  final Future<void> Function(String action)? onMenuAction;

  const ProductTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.priceCents,
    this.onTap,
    this.onMenuAction,
  });

  String _money(int cents) {
    final v = cents / 100.0;
    return NumberFormat.currency(symbol: '', decimalDigits: 0).format(v);
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
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
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_money(priceCents)),
          if (onMenuAction != null)
            PopupMenuButton<String>(
              onSelected: (v) async => onMenuAction!(v),
              itemBuilder: (_) => const [
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
            ),
        ],
      ),
    );
  }
}
