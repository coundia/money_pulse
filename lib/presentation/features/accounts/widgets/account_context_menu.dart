import 'package:flutter/material.dart';

Future<void> showAccountContextMenu(
  BuildContext context,
  Offset globalPosition, {
  required bool canMakeDefault,
  required VoidCallback onView,
  VoidCallback? onMakeDefault,
  required VoidCallback onEdit,
  required VoidCallback onDelete,
  required VoidCallback onShare,
}) async {
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
  final result = await showMenu<String>(
    context: context,
    position: RelativeRect.fromLTRB(
      globalPosition.dx,
      globalPosition.dy,
      overlay.size.width - globalPosition.dx,
      overlay.size.height - globalPosition.dy,
    ),
    items: [
      const PopupMenuItem(
        value: 'view',
        child: ListTile(leading: Icon(Icons.info_outline), title: Text('View')),
      ),
      if (canMakeDefault)
        const PopupMenuItem(
          value: 'default',
          child: ListTile(
            leading: Icon(Icons.star_border),
            title: Text('Make default'),
          ),
        ),
      const PopupMenuItem(
        value: 'edit',
        child: ListTile(
          leading: Icon(Icons.edit_outlined),
          title: Text('Edit'),
        ),
      ),
      const PopupMenuItem(
        value: 'share',
        child: ListTile(
          leading: Icon(Icons.ios_share_outlined),
          title: Text('Share'),
        ),
      ),
      const PopupMenuItem(
        value: 'delete',
        child: ListTile(
          leading: Icon(Icons.delete_outline),
          title: Text('Delete'),
        ),
      ),
    ],
  );

  switch (result) {
    case 'view':
      onView();
      break;
    case 'default':
      if (onMakeDefault != null) onMakeDefault();
      break;
    case 'edit':
      onEdit();
      break;
    case 'share':
      onShare();
      break;
    case 'delete':
      onDelete();
      break;
  }
}
