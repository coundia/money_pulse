// Reusable movement list item widgets (tile and card) with condensed visuals.
import 'package:flutter/material.dart';
import '../../../shared/formatters.dart';
import '../../../../domain/stock/repositories/stock_movement_repository.dart';
import 'movement_type_ui.dart';

class MovementTile extends StatelessWidget {
  final StockMovementRow row;
  final VoidCallback? onTap;
  const MovementTile({super.key, required this.row, this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = MovementTypeUi.color(context, row.type);
    final pu = Formatters.amountFromCents(row.unitPriceCents);
    final tot = Formatters.amountFromCents(row.totalCents);
    return ListTile(
      dense: true,
      onTap: onTap,
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: color.withOpacity(0.12),
        foregroundColor: color,
        child: Text(row.type.substring(0, 1)),
      ),
      title: Text(
        row.productLabel,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${row.companyLabel} • Qté ${row.quantity} • PU $pu • Total $tot • ${Formatters.dateFull(row.createdAt)}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
    );
  }
}

class MovementCard extends StatelessWidget {
  final StockMovementRow row;
  final VoidCallback? onTap;
  const MovementCard({super.key, required this.row, this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = MovementTypeUi.color(context, row.type);
    final pu = Formatters.amountFromCents(row.unitPriceCents);
    final tot = Formatters.amountFromCents(row.totalCents);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: color.withOpacity(0.12),
              foregroundColor: color,
              child: Text(row.type.substring(0, 1)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.productLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${row.companyLabel} • ${Formatters.dateFull(row.createdAt)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Qté ${row.quantity} • PU $pu • Total $tot',
                    style: const TextStyle(fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
