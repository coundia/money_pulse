// Bottom-sheet filter UI returning MovementFilters via Navigator.pop.
import 'package:flutter/material.dart';
import 'movement_filters.dart';
import 'movement_type_ui.dart';

class MovementFilterSheet extends StatefulWidget {
  final MovementFilters initial;
  const MovementFilterSheet({super.key, required this.initial});

  @override
  State<MovementFilterSheet> createState() => _MovementFilterSheetState();
}

class _MovementFilterSheetState extends State<MovementFilterSheet> {
  late String _type;
  DateTimeRange? _range;
  late int _minQty;

  @override
  void initState() {
    super.initState();
    _type = widget.initial.type;
    _range = widget.initial.range;
    _minQty = widget.initial.minQty;
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final initial =
        _range ??
        DateTimeRange(
          start: DateTime(now.year, now.month, now.day),
          end: DateTime(now.year, now.month, now.day),
        );
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: initial,
    );
    if (picked != null) setState(() => _range = picked);
  }

  static String _fmt(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final da = d.day.toString().padLeft(2, '0');
    return '$y-$m-$da';
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: insets, left: 16, right: 16, top: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Filtres',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const Text(
                  'Type : ',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 8),
                Wrap(
                  spacing: 6,
                  children: MovementTypeUi.values
                      .map(
                        (t) => ChoiceChip(
                          label: Text(MovementTypeUi.fr(t)),
                          selected: _type == t,
                          onSelected: (_) => setState(() => _type = t),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickRange,
                  icon: const Icon(Icons.event),
                  label: Text(
                    _range == null
                        ? 'Période : Toutes'
                        : 'Période : ${_fmt(_range!.start)} → ${_fmt(_range!.end)}',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (_range != null)
                IconButton(
                  tooltip: 'Effacer',
                  onPressed: () => setState(() => _range = null),
                  icon: const Icon(Icons.clear),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text(
                'Qté min : ',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 8),
              DropdownButton<int>(
                value: _minQty,
                onChanged: (v) => setState(() => _minQty = v ?? 0),
                items: const [
                  DropdownMenuItem(value: 0, child: Text('0')),
                  DropdownMenuItem(value: 1, child: Text('1')),
                  DropdownMenuItem(value: 5, child: Text('5')),
                  DropdownMenuItem(value: 10, child: Text('10')),
                  DropdownMenuItem(value: 50, child: Text('50')),
                ],
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => setState(() {
                  _type = 'ALL';
                  _range = null;
                  _minQty = 0;
                }),
                icon: const Icon(Icons.filter_alt_off),
                label: const Text('Réinitialiser'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.close),
                  label: const Text('Annuler'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(
                    MovementFilters(
                      type: _type,
                      range: _range,
                      minQty: _minQty,
                    ),
                  ),
                  icon: const Icon(Icons.check),
                  label: const Text('Appliquer'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
