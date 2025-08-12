import 'package:flutter/material.dart';

class UnitContextMenu {
  static const view = 'view';
  static const edit = 'edit';
  static const delete = 'delete';
  static const share = 'share';
}

List<PopupMenuEntry<String>> buildUnitContextMenuItems() => const [
  PopupMenuItem(
    value: UnitContextMenu.view,
    child: ListTile(
      leading: Icon(Icons.visibility_outlined),
      title: Text('Voir'),
    ),
  ),
  PopupMenuItem(
    value: UnitContextMenu.edit,
    child: ListTile(
      leading: Icon(Icons.edit_outlined),
      title: Text('Modifier'),
    ),
  ),
  PopupMenuItem(
    value: UnitContextMenu.delete,
    child: ListTile(
      leading: Icon(Icons.delete_outline),
      title: Text('Supprimer'),
    ),
  ),
  PopupMenuDivider(),
  PopupMenuItem(
    value: UnitContextMenu.share,
    child: ListTile(leading: Icon(Icons.ios_share), title: Text('Partager')),
  ),
];
