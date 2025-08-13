/// Reusable list tile for StockMovementRow.
import 'package:flutter/material.dart';
import '../../../../../domain/stock/repositories/stock_movement_repository.dart';
import 'stock_movement_context_menu.dart';

class StockMovementTile extends StatelessWidget {
  final StockMovementRow row;
  final VoidCallback? onTap;
  final void Function(StockMovementMenuAction action)? onMenu;
  const StockMovementTile({
    super.key,
    required this.row,
    this.onTap,
    this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(child: Text(row.type.substring(0, 1))),
      title: Text(
        '${row.productLabel} • ${row.companyLabel}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text('${row.type} • Qté: ${row.quantity}'),
      trailing: PopupMenuButton<StockMovementMenuAction>(
        onSelected: (a) => onMenu?.call(a),
        itemBuilder: (c) => const [
          PopupMenuItem(
            value: StockMovementMenuAction.view,
            child: Text('Voir'),
          ),
          PopupMenuItem(
            value: StockMovementMenuAction.edit,
            child: Text('Modifier'),
          ),
          PopupMenuItem(
            value: StockMovementMenuAction.delete,
            child: Text('Supprimer'),
          ),
        ],
        iconColor: cs.primary,
      ),
    );
  }
}
