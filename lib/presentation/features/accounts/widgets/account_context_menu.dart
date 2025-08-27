/* Context menu for account tile; actions deferred to next frame to avoid layout conflicts with drawers. */
import 'package:flutter/material.dart';

Future<void> showAccountContextMenu(
  BuildContext context,
  Offset position, {
  required bool canMakeDefault,
  required VoidCallback onView,
  required VoidCallback onMakeDefault,
  required VoidCallback onEdit,
  required VoidCallback onDelete,
  required VoidCallback onShare,
  required VoidCallback onAdjustBalance,
  String? accountLabel,
  int? balanceCents,
  String? currency,
  DateTime? updatedAt,
}) async {
  void runNext(VoidCallback cb) {
    WidgetsBinding.instance.addPostFrameCallback((_) => cb());
  }

  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
  final selected = await showMenu<String>(
    context: context,
    position: RelativeRect.fromLTRB(
      position.dx,
      position.dy,
      overlay.size.width - position.dx,
      overlay.size.height - position.dy,
    ),
    items: [
      const PopupMenuItem<String>(
        value: 'view',
        child: ListTile(
          leading: Icon(Icons.visibility_outlined),
          title: Text('Ouvrir'),
        ),
      ),
      if (canMakeDefault)
        const PopupMenuItem<String>(
          value: 'default',
          child: ListTile(
            leading: Icon(Icons.star),
            title: Text('Définir par défaut'),
          ),
        ),
      const PopupMenuItem<String>(
        value: 'edit',
        child: ListTile(
          leading: Icon(Icons.edit_outlined),
          title: Text('Modifier'),
        ),
      ),
      const PopupMenuItem<String>(
        value: 'adjust',
        child: ListTile(
          leading: Icon(Icons.balance),
          title: Text('Ajuster le solde'),
        ),
      ),
      const PopupMenuItem<String>(
        value: 'share',
        child: ListTile(leading: Icon(Icons.share), title: Text('Partager')),
      ),
      const PopupMenuItem<String>(
        value: 'delete',
        child: ListTile(
          leading: Icon(Icons.delete_outline),
          title: Text('Supprimer'),
        ),
      ),
    ],
  );

  switch (selected) {
    case 'view':
      runNext(onView);
      break;
    case 'default':
      runNext(onMakeDefault);
      break;
    case 'edit':
      runNext(onEdit);
      break;
    case 'adjust':
      runNext(onAdjustBalance);
      break;
    case 'share':
      runNext(onShare); // <- ouvrira UnderConstructionDrawer
      break;
    case 'delete':
      runNext(onDelete);
      break;
    default:
      break;
  }
}
