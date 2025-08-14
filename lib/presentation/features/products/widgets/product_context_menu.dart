// Reusable product context menu model and items, including Duplicate action.
import 'package:flutter/material.dart';

abstract class ProductContextMenu {
  static const String view = 'view';
  static const String edit = 'edit';
  static const String adjust = 'adjust';
  static const String delete = 'delete';
  static const String share = 'share';
  static const String duplicate = 'duplicate';
}

List<PopupMenuEntry<String>> buildProductContextMenuItems({
  bool includeView = true,
  bool includeShare = true,
}) {
  return [
    if (includeView)
      const PopupMenuItem(
        value: ProductContextMenu.view,
        child: ListTile(
          leading: Icon(Icons.visibility_outlined),
          title: Text('Voir'),
        ),
      ),
    const PopupMenuItem(
      value: ProductContextMenu.edit,
      child: ListTile(
        leading: Icon(Icons.edit_outlined),
        title: Text('Modifier'),
      ),
    ),
    const PopupMenuItem(
      value: ProductContextMenu.duplicate,
      child: ListTile(
        leading: Icon(Icons.copy_all_outlined),
        title: Text('Dupliquer'),
      ),
    ),
    const PopupMenuItem(
      value: ProductContextMenu.adjust,
      child: ListTile(leading: Icon(Icons.tune), title: Text('Ajuster stock')),
    ),
    const PopupMenuItem(
      value: ProductContextMenu.delete,
      child: ListTile(
        leading: Icon(Icons.delete_outline),
        title: Text('Supprimer'),
      ),
    ),
    if (includeShare) const PopupMenuDivider(),
    if (includeShare)
      const PopupMenuItem(
        value: ProductContextMenu.share,
        child: ListTile(
          leading: Icon(Icons.ios_share),
          title: Text('Partager'),
        ),
      ),
  ];
}
