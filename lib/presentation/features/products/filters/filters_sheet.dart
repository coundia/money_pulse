import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../filters/product_filters.dart';

class FiltersSheet extends StatefulWidget {
  final ProductFilters initial;
  const FiltersSheet({super.key, required this.initial});

  @override
  State<FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends State<FiltersSheet> {
  late ProductFilters _f;
  final _minCtrl = TextEditingController();
  final _maxCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _f = widget.initial;
    if (_f.minPriceCents != null) {
      _minCtrl.text = (_f.minPriceCents! ~/ 100).toString();
    }
    if (_f.maxPriceCents != null) {
      _maxCtrl.text = (_f.maxPriceCents! ~/ 100).toString();
    }
  }

  @override
  void dispose() {
    _minCtrl.dispose();
    _maxCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final init =
        _f.dateRange ??
        DateTimeRange(
          start: DateTime(now.year, now.month, now.day),
          end: DateTime(now.year, now.month, now.day),
        );
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: init,
    );
    if (picked != null) {
      setState(() => _f = _f.copyWith(dateRange: picked));
    }
  }

  void _applyAndClose() {
    int? minC;
    int? maxC;
    final minTxt = _minCtrl.text.trim();
    final maxTxt = _maxCtrl.text.trim();
    if (minTxt.isNotEmpty) minC = (int.tryParse(minTxt) ?? 0) * 100;
    if (maxTxt.isNotEmpty) maxC = (int.tryParse(maxTxt) ?? 0) * 100;

    Navigator.of(context).pop(
      _f.copyWith(
        minPriceCents: minC,
        clearMin: minTxt.isEmpty,
        maxPriceCents: maxC,
        clearMax: maxTxt.isEmpty,
      ),
    );
  }

  void _reset() {
    setState(() {
      _f = const ProductFilters();
      _minCtrl.clear();
      _maxCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Responsive, no overflow: everything is placed inside SingleChildScrollView + Wraps.
    return SafeArea(
      top: false,
      child: LayoutBuilder(
        builder: (context, bc) {
          final isNarrow = bc.maxWidth < 520;
          final fieldWidth = isNarrow ? bc.maxWidth : (bc.maxWidth - 24) / 2;

          return SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              bottom: MediaQuery.viewInsetsOf(context).bottom + 12,
              top: 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      'Filtres',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _reset,
                      icon: const Icon(Icons.filter_alt_off),
                      label: const Text('Réinitialiser'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // DATE FIELD + RANGE  (Wrap = no overflow)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text('Date :'),
                    SegmentedButton<DateField>(
                      segments: const [
                        ButtonSegment(
                          value: DateField.created,
                          label: Text('Création'),
                          icon: Icon(Icons.event_available),
                        ),
                        ButtonSegment(
                          value: DateField.updated,
                          label: Text('Mise à jour'),
                          icon: Icon(Icons.update),
                        ),
                      ],
                      selected: {_f.dateField},
                      onSelectionChanged: (s) =>
                          setState(() => _f = _f.copyWith(dateField: s.first)),
                    ),
                    OutlinedButton.icon(
                      onPressed: _pickDateRange,
                      icon: const Icon(Icons.event),
                      label: Text(
                        _f.dateRange == null
                            ? 'Période : Toutes'
                            : '${_fmtDate(_f.dateRange!.start)} → ${_fmtDate(_f.dateRange!.end)}',
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // PRICE MIN / MAX  (no overflow, width-constrained)
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: fieldWidth),
                      child: TextField(
                        controller: _minCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Prix min ',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: fieldWidth),
                      child: TextField(
                        controller: _maxCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Prix max (€)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // STOCK  (Wrap = no overflow)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text('Stock :'),
                    SegmentedButton<StockFilter>(
                      segments: const [
                        ButtonSegment(
                          value: StockFilter.any,
                          label: Text('Tous'),
                          icon: Icon(Icons.inventory_2_outlined),
                        ),
                        ButtonSegment(
                          value: StockFilter.inStock,
                          label: Text('En stock'),
                          icon: Icon(Icons.check_circle_outline),
                        ),
                        ButtonSegment(
                          value: StockFilter.outOfStock,
                          label: Text('Rupture'),
                          icon: Icon(Icons.remove_circle_outline),
                        ),
                      ],
                      selected: {_f.stock},
                      onSelectionChanged: (s) =>
                          setState(() => _f = _f.copyWith(stock: s.first)),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                // ACTIONS (Wrap to avoid overflow)
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: isNarrow ? double.infinity : 220,
                      child: FilledButton.icon(
                        onPressed: _applyAndClose,
                        icon: const Icon(Icons.check),
                        label: const Text('Appliquer'),
                      ),
                    ),
                    SizedBox(
                      width: isNarrow ? double.infinity : 220,
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.close),
                        label: const Text('Fermer'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  static String _fmtDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final da = d.day.toString().padLeft(2, '0');
    return '$y-$m-$da';
  }
}
