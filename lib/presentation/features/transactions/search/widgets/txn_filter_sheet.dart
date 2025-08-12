import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/txn_search_filters.dart';

Future<TxnFilterState?> openTxnFilterSheet(
  BuildContext context,
  TxnFilterState f,
) async {
  final theme = Theme.of(context);

  final fromCtrl = TextEditingController(
    text: f.from == null ? '' : DateFormat.yMMMd('fr_FR').format(f.from!),
  );
  final toCtrl = TextEditingController(
    text: f.to == null ? '' : DateFormat.yMMMd('fr_FR').format(f.to!),
  );
  final minCtrl = TextEditingController(
    text: f.minCents == null ? '' : (f.minCents! ~/ 100).toString(),
  );
  final maxCtrl = TextEditingController(
    text: f.maxCents == null ? '' : (f.maxCents! ~/ 100).toString(),
  );

  // État local de la sheet
  var type = f.type;
  var sortBy = f.sortBy;
  DateTime? from = f.from;
  DateTime? to = f.to;

  DateTime _strip(DateTime d) => DateTime(d.year, d.month, d.day);

  return showModalBottomSheet<TxnFilterState>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      return SafeArea(
        child: StatefulBuilder(
          builder: (ctx, setState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
                top: 12,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // poignée
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Filtres', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),

                  // Type
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Type', style: theme.textTheme.labelLarge),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<TxnTypeFilter>(
                    segments: const [
                      ButtonSegment(
                        value: TxnTypeFilter.all,
                        icon: Icon(Icons.all_inclusive),
                        label: Text('Tous'),
                      ),
                      ButtonSegment(
                        value: TxnTypeFilter.expense,
                        icon: Icon(Icons.south),
                        label: Text('Dépense'),
                      ),
                      ButtonSegment(
                        value: TxnTypeFilter.income,
                        icon: Icon(Icons.north),
                        label: Text('Revenu'),
                      ),
                    ],
                    selected: {type},
                    onSelectionChanged: (s) => setState(() => type = s.first),
                    showSelectedIcon: false,
                  ),
                  const SizedBox(height: 16),

                  // Dates
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Plage de dates',
                      style: theme.textTheme.labelLarge,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: fromCtrl,
                          readOnly: true,
                          decoration: const InputDecoration(
                            labelText: 'Du',
                            prefixIcon: Icon(Icons.event),
                          ),
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: from ?? DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                              locale: const Locale('fr', 'FR'),
                            );
                            if (picked != null) {
                              setState(() {
                                from = _strip(picked);
                                fromCtrl.text = DateFormat.yMMMd(
                                  'fr_FR',
                                ).format(from!);
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: toCtrl,
                          readOnly: true,
                          decoration: const InputDecoration(
                            labelText: 'Au',
                            prefixIcon: Icon(Icons.event_available),
                          ),
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: to ?? DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                              locale: const Locale('fr', 'FR'),
                            );
                            if (picked != null) {
                              setState(() {
                                to = _strip(picked);
                                toCtrl.text = DateFormat.yMMMd(
                                  'fr_FR',
                                ).format(to!);
                              });
                            }
                          },
                        ),
                      ),
                      IconButton(
                        tooltip: 'Effacer',
                        onPressed: () {
                          setState(() {
                            from = null;
                            to = null;
                            fromCtrl.clear();
                            toCtrl.clear();
                          });
                        },
                        icon: const Icon(Icons.clear),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Montants
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Montant (XOF)',
                      style: theme.textTheme.labelLarge,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: minCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Min',
                            prefixIcon: Icon(Icons.monetization_on_outlined),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: maxCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Max',
                            prefixIcon: Icon(Icons.monetization_on_outlined),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Effacer',
                        onPressed: () {
                          setState(() {
                            minCtrl.clear();
                            maxCtrl.clear();
                          });
                        },
                        icon: const Icon(Icons.clear),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Tri
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Trier par', style: theme.textTheme.labelLarge),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<TxnSortBy>(
                    segments: const [
                      ButtonSegment(
                        value: TxnSortBy.dateDesc,
                        label: Text('Date ↓'),
                        icon: Icon(Icons.history),
                      ),
                      ButtonSegment(
                        value: TxnSortBy.dateAsc,
                        label: Text('Date ↑'),
                        icon: Icon(Icons.history_toggle_off),
                      ),
                      ButtonSegment(
                        value: TxnSortBy.amountDesc,
                        label: Text('Montant ↓'),
                        icon: Icon(Icons.trending_down),
                      ),
                      ButtonSegment(
                        value: TxnSortBy.amountAsc,
                        label: Text('Montant ↑'),
                        icon: Icon(Icons.trending_up),
                      ),
                    ],
                    selected: {sortBy},
                    onSelectionChanged: (s) => setState(() => sortBy = s.first),
                    showSelectedIcon: false,
                  ),
                  const SizedBox(height: 20),

                  // Actions
                  Row(
                    children: [
                      TextButton(
                        onPressed: () =>
                            Navigator.pop(ctx, const TxnFilterState()),
                        child: const Text('Réinitialiser'),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: () {
                          int? parseOrNull(TextEditingController c) {
                            if (c.text.trim().isEmpty) return null;
                            final n = int.tryParse(c.text.trim());
                            return n == null ? null : n * 100;
                          }

                          final min = parseOrNull(minCtrl);
                          final max = parseOrNull(maxCtrl);

                          Navigator.pop(
                            ctx,
                            TxnFilterState(
                              type: type,
                              from: from,
                              to: to,
                              minCents: min,
                              maxCents: max,
                              sortBy: sortBy,
                            ),
                          );
                        },
                        child: const Text('Appliquer'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      );
    },
  );
}
