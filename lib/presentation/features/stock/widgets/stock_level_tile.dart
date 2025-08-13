// Reusable tile for StockLevel rows with context menu

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'stock_level_context_menu.dart';
import 'package:money_pulse/domain/stock/repositories/stock_level_repository.dart';

class StockLevelTile extends StatelessWidget {
  final StockLevelRow row;
  final VoidCallback? onTap;
  final void Function(StockLevelMenuAction action)? onMenu;

  const StockLevelTile({super.key, required this.row, this.onTap, this.onMenu});

  @override
  Widget build(BuildContext context) {
    final nf = NumberFormat.decimalPattern();
    final subtitle =
        'Entreprise: ${row.companyLabel} • MAJ: ${DateFormat.yMMMd().add_Hm().format(row.updatedAt)}';
    final qty =
        'Stock: ${nf.format(row.stockOnHand)} • Alloué: ${nf.format(row.stockAllocated)}';

    return InkWell(
      onTap: onTap,
      child: ListTile(
        title: Text(
          row.productLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(subtitle),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(qty),
            const SizedBox(width: 8),
            PopupMenuButton<StockLevelMenuAction>(
              tooltip: 'Actions',
              onSelected: (a) => onMenu?.call(a),
              itemBuilder: (c) => const [
                PopupMenuItem(
                  value: StockLevelMenuAction.view,
                  child: Text('Voir'),
                ),
                PopupMenuItem(
                  value: StockLevelMenuAction.edit,
                  child: Text('Modifier'),
                ),
                PopupMenuItem(
                  value: StockLevelMenuAction.delete,
                  child: Text('Supprimer'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
