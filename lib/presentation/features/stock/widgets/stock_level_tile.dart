// Reusable list/grid tile for StockLevel with context menu and responsive layout.
import 'package:flutter/material.dart';
import 'package:money_pulse/presentation/shared/formatters.dart';
import 'package:money_pulse/domain/stock/repositories/stock_level_repository.dart';
import 'stock_level_context_menu.dart';

class StockLevelTile extends StatelessWidget {
  final StockLevelRow row;
  final VoidCallback? onTap;
  final void Function(StockLevelMenuAction action)? onMenu;
  const StockLevelTile({super.key, required this.row, this.onTap, this.onMenu});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final net = row.stockOnHand - row.stockAllocated;

    return InkWell(
      onTap: onTap,
      onLongPress: () => _openMenu(context),
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              CircleAvatar(
                child: Text(row.productLabel.characters.first.toUpperCase()),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.productLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      row.companyLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Chip(
                          visualDensity: VisualDensity.compact,
                          label: Text('Dispo: ${row.stockOnHand}'),
                        ),
                        Chip(
                          visualDensity: VisualDensity.compact,
                          label: Text('Alloué: ${row.stockAllocated}'),
                        ),
                        Chip(
                          visualDensity: VisualDensity.compact,
                          label: Text('Net: $net'),
                        ),
                        Chip(
                          visualDensity: VisualDensity.compact,
                          label: Text(
                            'Maj ${Formatters.timeHm(row.updatedAt)}',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Menu',
                icon: const Icon(Icons.more_vert),
                onPressed: () => _openMenu(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openMenu(BuildContext context) async {
    final action = await showStockLevelContextMenu(context);
    if (action != null) onMenu?.call(action);
  }
}
