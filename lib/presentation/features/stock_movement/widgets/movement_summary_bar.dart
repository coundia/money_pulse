/// Compact summary and active filter chips for stock movement lists.
import 'package:flutter/material.dart';
import 'package:money_pulse/presentation/shared/formatters.dart';
import 'package:money_pulse/domain/stock/repositories/stock_movement_repository.dart';
import 'movement_filters.dart';
import 'movement_type_ui.dart';

class MovementSummaryBar extends StatelessWidget {
  final List<StockMovementRow> source;
  final MovementFilters filters;
  final VoidCallback onClearFilters;

  const MovementSummaryBar({
    super.key,
    required this.source,
    required this.filters,
    required this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    final rows = filters.apply(source);
    final count = rows.length;
    final sumQty = rows.fold<int>(0, (p, e) => p + e.quantity);
    final sumTotal = rows.fold<int>(0, (p, e) => p + e.totalCents);

    final chips = <Widget>[];
    if (filters.type != 'ALL') {
      chips.add(
        _pill(
          context,
          label: MovementTypeUi.fr(filters.type),
          icon: MovementTypeUi.icon(filters.type),
          color: MovementTypeUi.color(context, filters.type),
        ),
      );
    }
    if (filters.range != null) {
      chips.add(
        _pill(
          context,
          label: '${_fmt(filters.range!.start)} → ${_fmt(filters.range!.end)}',
          icon: Icons.event,
        ),
      );
    }
    if (filters.minQty > 0) {
      chips.add(
        _pill(
          context,
          label: 'Qté ≥ ${filters.minQty}',
          icon: Icons.filter_alt,
        ),
      );
    }
    if (chips.isEmpty) {
      chips.add(
        _pill(context, label: 'Aucun filtre', icon: Icons.filter_alt_off),
      );
    } else {
      chips.add(
        TextButton.icon(
          onPressed: onClearFilters,
          icon: const Icon(Icons.filter_alt_off),
          label: const Text('Réinitialiser'),
        ),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _stat(context, Icons.list_alt, 'Éléments', '$count'),
                  _stat(context, Icons.summarize, 'Qté', '$sumQty'),
                  _stat(
                    context,
                    Icons.payments,
                    'Montant',
                    Formatters.amountFromCents(sumTotal),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerLeft,
          child: Wrap(spacing: 6, runSpacing: 6, children: chips),
        ),
      ],
    );
  }

  static Widget _stat(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: cs.primary),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          ),
          Text(value, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  static Widget _pill(
    BuildContext context, {
    required String label,
    required IconData icon,
    Color? color,
  }) {
    final cs = Theme.of(context).colorScheme;
    final fg = color ?? cs.onSurfaceVariant;
    return Chip(
      avatar: Icon(icon, size: 16, color: fg),
      label: Text(label, style: TextStyle(color: fg)),
      backgroundColor: fg.withOpacity(0.08),
      side: BorderSide(color: fg.withOpacity(0.22)),
      visualDensity: VisualDensity.compact,
    );
  }

  static String _fmt(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final da = d.day.toString().padLeft(2, '0');
    return '$y-$m-$da';
  }
}
