// Context menu entries for product list item (FR labels, action keys used by list page).
import 'package:flutter/material.dart';

List<PopupMenuEntry<String>> buildProductContextMenuItems() {
  return [
    const PopupMenuItem(
      value: 'view',
      child: ListTile(leading: Icon(Icons.visibility), title: Text('Afficher')),
    ),
    const PopupMenuItem(
      value: 'edit',
      child: ListTile(leading: Icon(Icons.edit), title: Text('Modifier')),
    ),
    const PopupMenuItem(
      value: 'duplicate',
      child: ListTile(
        leading: Icon(Icons.control_point_duplicate),
        title: Text('Dupliquer'),
      ),
    ),
    const PopupMenuItem(
      value: 'adjust',
      child: ListTile(
        leading: Icon(Icons.inventory_2_outlined),
        title: Text('Ajuster le stock'),
      ),
    ),
    const PopupMenuDivider(),
    const PopupMenuItem(
      value: 'share',
      child: ListTile(
        leading: Icon(Icons.share_outlined),
        title: Text('Partager'),
      ),
    ),
    const PopupMenuItem(
      value: 'delete',
      child: ListTile(
        leading: Icon(Icons.delete_outline),
        title: Text('Supprimer'),
      ),
    ),
  ];
}
