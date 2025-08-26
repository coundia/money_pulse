// Popup menu model for StockLevel actions

import 'package:flutter/material.dart'
    show showModalBottomSheet, ListTile, Divider, Icons, Colors;
import 'package:flutter/widgets.dart';

enum StockLevelMenuAction { view, edit, delete }

Future<StockLevelMenuAction?> showStockLevelContextMenu(
  BuildContext context,
) async {
  return showModalBottomSheet<StockLevelMenuAction>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      return SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: const Icon(Icons.visibility_outlined),
              title: const Text('Voir'),
              onTap: () => Navigator.of(ctx).pop(StockLevelMenuAction.view),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Modifier'),
              onTap: () => Navigator.of(ctx).pop(StockLevelMenuAction.edit),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Supprimer'),
              textColor: Colors.red,
              onTap: () => Navigator.of(ctx).pop(StockLevelMenuAction.delete),
            ),
          ],
        ),
      );
    },
  );
}
