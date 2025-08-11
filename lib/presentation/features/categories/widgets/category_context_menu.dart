import 'package:flutter/material.dart';

class CategoryContextMenu {
  static const String view = 'view';
  static const String edit = 'edit';
  static const String delete = 'delete';
  static const String share = 'share';
}

List<PopupMenuEntry<String>> buildCategoryContextMenuItems() => const [
  PopupMenuItem(
    value: CategoryContextMenu.view,
    child: ListTile(
      leading: Icon(Icons.visibility_outlined),
      title: Text('Voir'),
    ),
  ),
  PopupMenuItem(
    value: CategoryContextMenu.edit,
    child: ListTile(
      leading: Icon(Icons.edit_outlined),
      title: Text('Modifier'),
    ),
  ),
  PopupMenuItem(
    value: CategoryContextMenu.delete,
    child: ListTile(
      leading: Icon(Icons.delete_outline),
      title: Text('Supprimer'),
    ),
  ),
  PopupMenuItem(
    value: CategoryContextMenu.share,
    child: ListTile(
      leading: Icon(Icons.share_outlined),
      title: Text('Copier les détails'),
    ),
  ),
];
