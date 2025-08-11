import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'report_range.dart';

class ReportPeriodSelector extends StatelessWidget {
  final ReportRange range;
  final bool isDebit;
  final ValueChanged<ReportRange> onChangeRange;
  final ValueChanged<bool> onToggleDebitCredit;

  const ReportPeriodSelector({
    super.key,
    required this.range,
    required this.isDebit,
    required this.onChangeRange,
    required this.onToggleDebitCredit,
  });

  Future<void> _pickCustomRange(BuildContext context) async {
    final initial = DateTimeRange(
      start: range.from,
      end: range.to.subtract(const Duration(milliseconds: 1)),
    );
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: initial,
    );
    if (picked != null) {
      onChangeRange(ReportRange.custom(picked.start, picked.end));
    }
  }

  @override
  Widget build(BuildContext context) {
    final density = VisualDensity.compact;

    Widget chip({
      required bool selected,
      required String label,
      required IconData icon,
      required VoidCallback onTap,
      String? tooltip,
    }) {
      final content = FilterChip(
        visualDensity: density,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        avatar: Icon(icon, size: 18),
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        side: BorderSide(
          color: selected
              ? Theme.of(context).colorScheme.primary.withOpacity(0.45)
              : Theme.of(context).dividerColor,
        ),
        onSelected: (_) {
          HapticFeedback.selectionClick();
          onTap();
        },
      );
      return tooltip == null
          ? content
          : Tooltip(message: tooltip, child: content);
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        // Tout sur une ligne avec scroll horizontal
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              const SizedBox(width: 8),
              chip(
                selected: range.kind == ReportRangeKind.thisMonth,
                label: 'Ce mois',
                icon: Icons.calendar_view_month,
                onTap: () => onChangeRange(ReportRange.thisMonth()),
                tooltip: '1er → fin de mois',
              ),
              const SizedBox(width: 8),
              chip(
                selected: range.kind == ReportRangeKind.thisYear,
                label: 'Cette année',
                icon: Icons.calendar_month,
                onTap: () => onChangeRange(ReportRange.thisYear()),
                tooltip: '1er jan → 31 déc',
              ),
              const SizedBox(width: 8),
              ActionChip(
                visualDensity: density,
                avatar: const Icon(Icons.date_range, size: 18),
                label: const Text('Plage'),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  _pickCustomRange(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
