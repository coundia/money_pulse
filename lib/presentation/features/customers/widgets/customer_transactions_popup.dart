// Popup listing a customer's recent transactions with filters, reverse-delete, and live refresh (SRP).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jaayko/presentation/shared/formatters.dart';
import '../providers/customer_linked_providers.dart'; // <-- provides LinkedTxnRow + providers
import 'customer_linked_controller.dart';
import 'package:jaayko/presentation/widgets/right_drawer.dart';

// NOTE: Do NOT import TransactionEntry here; this popup works with LinkedTxnRow.

class CustomerTransactionsPopup extends ConsumerStatefulWidget {
  final String customerId;
  const CustomerTransactionsPopup({super.key, required this.customerId});

  @override
  ConsumerState<CustomerTransactionsPopup> createState() =>
      _CustomerTransactionsPopupState();
}

class _TxFilter {
  final String search;
  final Set<String>
  types; // uses typeEntry: DEBIT, CREDIT, DEBT, REMBOURSEMENT, PRET
  final DateTime? from;
  final DateTime? to;
  final int? minCents;
  final int? maxCents;
  const _TxFilter({
    this.search = '',
    this.types = const {},
    this.from,
    this.to,
    this.minCents,
    this.maxCents,
  });

  _TxFilter copyWith({
    String? search,
    Set<String>? types,
    DateTime? from,
    DateTime? to,
    int? minCents,
    int? maxCents,
  }) {
    return _TxFilter(
      search: search ?? this.search,
      types: types ?? this.types,
      from: from ?? this.from,
      to: to ?? this.to,
      minCents: minCents ?? this.minCents,
      maxCents: maxCents ?? this.maxCents,
    );
  }

  bool get hasAny =>
      search.trim().isNotEmpty ||
      types.isNotEmpty ||
      from != null ||
      to != null ||
      minCents != null ||
      maxCents != null;

  static _TxFilter empty() => const _TxFilter();
}

class _CustomerTransactionsPopupState
    extends ConsumerState<CustomerTransactionsPopup> {
  bool _dirty = false;
  _TxFilter _filter = _TxFilter.empty();

  // Labels par TYPE (typeEntry)
  static const Map<String, String> _typeLabels = {
    'DEBIT': 'Dépense',
    'CREDIT': 'Revenu',
    'DEBT': 'Dette',
    'REMBOURSEMENT': 'Remboursement',
    'PRET': 'Prêt',
  };

  // Labels par STATUT (status)
  static const Map<String, String> _statusLabels = {
    'DEBT': 'Dette',
    'REPAYMENT': 'Remboursement',
    'LOAN': 'Prêt',
    'REVERSED': 'Annulé',
  };

  String _typeLabel(String? t) {
    final k = (t ?? '').toUpperCase();
    return _typeLabels[k] ?? (t ?? '—');
  }

  String _statusLabel(String? s) {
    if (s == null || s.isEmpty) return 'Autre';
    final k = s.toUpperCase();
    return _statusLabels[k] ?? s;
  }

  IconData _typeIcon(String? t) {
    switch ((t ?? '').toUpperCase()) {
      case 'DEBIT':
        return Icons.remove_circle_outline;
      case 'CREDIT':
        return Icons.add_circle_outline;
      case 'DEBT':
        return Icons.shopping_cart_checkout_outlined;
      case 'REMBOURSEMENT':
        return Icons.payments_outlined;
      case 'PRET':
        return Icons.account_balance_outlined;
      default:
        return Icons.receipt_long_outlined;
    }
  }

  Color _statusColor(BuildContext context, String? s) {
    final scheme = Theme.of(context).colorScheme;
    switch ((s ?? '').toUpperCase()) {
      case 'DEBT':
        return scheme.error;
      case 'REPAYMENT':
        return scheme.primary;
      case 'LOAN':
        return scheme.tertiary;
      case 'REVERSED':
        return scheme.outline;
      default:
        return scheme.secondary;
    }
  }

  Future<void> _reverseOne(
    BuildContext context,
    String txId,
    String title,
    int amount,
  ) async {
    final controller = CustomerLinkedController();
    final ok = await showRightDrawer<bool>(
      context,
      child: _TxReverseConfirmPanel(
        title: title,
        amountCents: amount,
        onConfirm: () async {
          final done = await controller.reverseTransaction(
            context: context,
            ref: ref,
            txId: txId,
          );
          if (done) {
            await controller.refreshAll(ref, widget.customerId);
            setState(() => _dirty = true);
          }
          return done;
        },
      ),
      widthFraction: 0.86,
      heightFraction: 0.5,
    );
    if (ok == true) {
      await controller.refreshAll(ref, widget.customerId);
      setState(() => _dirty = true);
    }
  }

  // *************** FILTERS APPLY ON LinkedTxnRow ****************
  List<LinkedTxnRow> _applyFilters(List<LinkedTxnRow> rows) {
    Iterable<LinkedTxnRow> list = rows;
    final f = _filter;

    if (f.search.trim().isNotEmpty) {
      final q = f.search.toLowerCase().trim();
      list = list.where((r) {
        final label =
            (r.description?.isNotEmpty == true
                    ? r.description!
                    : _typeLabel(r.typeEntry))
                .toLowerCase();
        return label.contains(q);
      });
    }
    if (f.types.isNotEmpty) {
      list = list.where((r) => f.types.contains((r.typeEntry).toUpperCase()));
    }
    if (f.from != null) {
      final start = DateTime(f.from!.year, f.from!.month, f.from!.day);
      list = list.where((r) => !r.dateTransaction.isBefore(start));
    }
    if (f.to != null) {
      final end = DateTime(f.to!.year, f.to!.month, f.to!.day, 23, 59, 59, 999);
      list = list.where((r) => !r.dateTransaction.isAfter(end));
    }
    if (f.minCents != null) {
      list = list.where((r) => r.amount >= f.minCents!);
    }
    if (f.maxCents != null) {
      list = list.where((r) => r.amount <= f.maxCents!);
    }

    final out = list.toList()
      ..sort((a, b) => b.dateTransaction.compareTo(a.dateTransaction));
    return out;
  }

  Map<String, int> _statusTotals(List<LinkedTxnRow> filtered) {
    final map = <String, int>{};
    for (final r in filtered) {
      final key = (r.status ?? '').isEmpty ? 'OTHER' : r.status!.toUpperCase();
      map[key] = (map[key] ?? 0) + r.amount;
    }
    return map;
  }

  Widget _statusTotalsChips(BuildContext context, Map<String, int> totals) {
    if (totals.isEmpty) return const SizedBox.shrink();
    final keys = totals.keys.toList()
      ..sort((a, b) => a.compareTo(b)); // ordre stable
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final k in keys)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Chip(
                label: Text(
                  '${_statusLabel(k)}: ${Formatters.amountFromCents(totals[k] ?? 0)}',
                ),
                backgroundColor: _statusColor(context, k).withOpacity(0.12),
                labelStyle: TextStyle(color: _statusColor(context, k)),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
        ],
      ),
    );
  }

  Widget _activeFiltersBar() {
    if (!_filter.hasAny) return const SizedBox.shrink();

    final chips = <Widget>[];
    if (_filter.search.trim().isNotEmpty) {
      chips.add(
        InputChip(
          label: Text('Recherche: ${_filter.search.trim()}'),
          onDeleted: () =>
              setState(() => _filter = _filter.copyWith(search: '')),
        ),
      );
    }
    if (_filter.types.isNotEmpty) {
      for (final t in _filter.types) {
        chips.add(
          InputChip(
            label: Text(_typeLabels[t] ?? t),
            onDeleted: () {
              final next = Set<String>.from(_filter.types)..remove(t);
              setState(() => _filter = _filter.copyWith(types: next));
            },
          ),
        );
      }
    }
    if (_filter.from != null) {
      chips.add(
        InputChip(
          label: Text('Du: ${Formatters.dateFull(_filter.from!)}'),
          onDeleted: () =>
              setState(() => _filter = _filter.copyWith(from: null)),
        ),
      );
    }
    if (_filter.to != null) {
      chips.add(
        InputChip(
          label: Text('Au: ${Formatters.dateFull(_filter.to!)}'),
          onDeleted: () => setState(() => _filter = _filter.copyWith(to: null)),
        ),
      );
    }
    if (_filter.minCents != null) {
      chips.add(
        InputChip(
          label: Text('Min: ${Formatters.amountFromCents(_filter.minCents!)}'),
          onDeleted: () =>
              setState(() => _filter = _filter.copyWith(minCents: null)),
        ),
      );
    }
    if (_filter.maxCents != null) {
      chips.add(
        InputChip(
          label: Text('Max: ${Formatters.amountFromCents(_filter.maxCents!)}'),
          onDeleted: () =>
              setState(() => _filter = _filter.copyWith(maxCents: null)),
        ),
      );
    }

    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
        child: Row(
          children: [
            Expanded(child: Wrap(spacing: 8, runSpacing: -6, children: chips)),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () => setState(() => _filter = _TxFilter.empty()),
              icon: const Icon(Icons.filter_alt_off_outlined),
              label: const Text('Réinitialiser'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openFilters() async {
    final next = await showRightDrawer<_TxFilter>(
      context,
      child: _TxFiltersPanel(initial: _filter),
      widthFraction: 0.86,
      heightFraction: 0.96,
    );
    if (next != null) {
      setState(() => _filter = next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final txsAsync = ref.watch(
      recentTransactionsOfCustomerProvider(widget.customerId),
    );
    final controller = CustomerLinkedController();

    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pop<bool>(_dirty);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Transactions du client'),
          leading: IconButton(
            tooltip: 'Fermer',
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).maybePop(_dirty),
          ),
          actions: [
            IconButton(
              tooltip: 'Filtrer',
              icon: const Icon(Icons.filter_list),
              onPressed: _openFilters,
            ),
            IconButton(
              tooltip: 'Rafraîchir',
              icon: const Icon(Icons.refresh),
              onPressed: () async {
                await controller.refreshAll(ref, widget.customerId);
                setState(() {});
              },
            ),
          ],
        ),
        body: Column(
          children: [
            _activeFiltersBar(),
            Expanded(
              child: txsAsync.when(
                data: (List<LinkedTxnRow> rows) {
                  final filtered = _applyFilters(rows);
                  if (filtered.isEmpty) {
                    return const Center(child: Text('Aucune transaction'));
                  }
                  final total = filtered.fold<int>(0, (p, e) => p + e.amount);
                  final perStatus = _statusTotals(filtered);

                  return RefreshIndicator(
                    onRefresh: () async {
                      await controller.refreshAll(ref, widget.customerId);
                      setState(() {});
                    },
                    child: ListView.separated(
                      padding: const EdgeInsets.only(top: 8),
                      itemCount: filtered.length + 2, // + header rows
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        // Row 0: Total filtré
                        if (i == 0) {
                          return ListTile(
                            dense: true,
                            leading: const Icon(Icons.summarize_outlined),
                            title: const Text('Total filtré'),
                            trailing: Text(
                              Formatters.amountFromCents(total),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          );
                        }
                        // Row 1: Totaux par statut (chips)
                        if (i == 1) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            child: _statusTotalsChips(context, perStatus),
                          );
                        }

                        final r = filtered[i - 2];
                        final label = (r.description?.isNotEmpty ?? false)
                            ? r.description!
                            : _typeLabel(r.typeEntry);

                        return ListTile(
                          dense: true,
                          leading: Icon(_typeIcon(r.typeEntry)),
                          title: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  Formatters.dateFull(r.dateTransaction),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: _statusColor(
                                    context,
                                    r.status,
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _statusLabel(r.status),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _statusColor(context, r.status),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                Formatters.amountFromCents(r.amount),
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(width: 6),
                              PopupMenuButton<String>(
                                onSelected: (v) {
                                  if (v == 'delete') {
                                    _reverseOne(
                                      context,
                                      r.id,
                                      'Supprimer (annuler) ?',
                                      r.amount,
                                    );
                                  }
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete_outline, size: 18),
                                        SizedBox(width: 8),
                                        Text('Supprimer (annuler)'),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          onLongPress: () => _reverseOne(
                            context,
                            r.id,
                            'Supprimer (annuler) ?',
                            r.amount,
                          ),
                        );
                      },
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Erreur: $e')),
              ),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () => controller.addQuickTransaction(
                  context,
                  ref,
                  widget.customerId,
                ),
                icon: const Icon(Icons.add),
                label: const Text('Nouvelle transaction'),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TxReverseConfirmPanel extends StatefulWidget {
  final String title;
  final int amountCents;
  final Future<bool> Function() onConfirm;
  const _TxReverseConfirmPanel({
    required this.title,
    required this.amountCents,
    required this.onConfirm,
  });

  @override
  State<_TxReverseConfirmPanel> createState() => _TxReverseConfirmPanelState();
}

class _TxReverseConfirmPanelState extends State<_TxReverseConfirmPanel> {
  bool _busy = false;

  Future<void> _confirm() async {
    if (_busy) return;
    setState(() => _busy = true);
    final ok = await widget.onConfirm();
    if (!mounted) return;
    setState(() => _busy = false);
    Navigator.of(context).pop<bool>(ok);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        leading: IconButton(
          tooltip: 'Fermer',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).maybePop(false),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Confirmer l’annulation'),
              subtitle: Text(
                'Montant: ${Formatters.amountFromCents(widget.amountCents)}',
              ),
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => Navigator.of(context).maybePop(false),
                    icon: const Icon(Icons.close),
                    label: const Text('Annuler'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _confirm,
                    icon: const Icon(Icons.check),
                    label: Text(_busy ? 'Traitement…' : 'Confirmer'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TxFiltersPanel extends StatefulWidget {
  final _TxFilter initial;
  const _TxFiltersPanel({required this.initial});

  @override
  State<_TxFiltersPanel> createState() => _TxFiltersPanelState();
}

class _TxFiltersPanelState extends State<_TxFiltersPanel> {
  late TextEditingController _search;
  late TextEditingController _minCtrl;
  late TextEditingController _maxCtrl;
  DateTime? _from;
  DateTime? _to;
  Set<String> _types = {};

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(text: widget.initial.search);
    _minCtrl = TextEditingController(
      text: widget.initial.minCents == null
          ? ''
          : (widget.initial.minCents! / 100).toStringAsFixed(2),
    );
    _maxCtrl = TextEditingController(
      text: widget.initial.maxCents == null
          ? ''
          : (widget.initial.maxCents! / 100).toStringAsFixed(2),
    );
    _from = widget.initial.from;
    _to = widget.initial.to;
    _types = Set<String>.from(widget.initial.types);
  }

  @override
  void dispose() {
    _search.dispose();
    _minCtrl.dispose();
    _maxCtrl.dispose();
    super.dispose();
  }

  int? _parseToCents(String v) {
    final t = v.replaceAll(RegExp(r'\s'), '').replaceAll(',', '.').trim();
    if (t.isEmpty) return null;
    final d = double.tryParse(t);
    if (d == null) return null;
    final cents = (d * 100).round();
    return cents < 0 ? 0 : cents;
  }

  Future<void> _pickFrom() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _from ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _from = picked);
  }

  Future<void> _pickTo() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _to ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _to = picked);
  }

  void _toggleType(String t) {
    final k = t.toUpperCase();
    setState(() {
      if (_types.contains(k)) {
        _types.remove(k);
      } else {
        _types.add(k);
      }
    });
  }

  void _apply() {
    final minC = _parseToCents(_minCtrl.text);
    final maxC = _parseToCents(_maxCtrl.text);
    final out = _TxFilter(
      search: _search.text,
      types: _types,
      from: _from,
      to: _to,
      minCents: minC,
      maxCents: maxC,
    );
    Navigator.of(context).pop<_TxFilter>(out);
  }

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];
    for (final e in _CustomerTransactionsPopupState._typeLabels.entries) {
      chips.add(
        FilterChip(
          label: Text(e.value),
          selected: _types.contains(e.key),
          onSelected: (_) => _toggleType(e.key),
        ),
      );
    }

    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.enter): const _SubmitIntent(),
        LogicalKeySet(LogicalKeyboardKey.numpadEnter): const _SubmitIntent(),
      },
      child: Actions(
        actions: {
          _SubmitIntent: CallbackAction<_SubmitIntent>(
            onInvoke: (_) {
              _apply();
              return null;
            },
          ),
        },
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Filtres'),
            leading: IconButton(
              tooltip: 'Fermer',
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.of(context).pop<_TxFilter>(_TxFilter.empty()),
                child: const Text('Réinitialiser'),
              ),
              const SizedBox(width: 4),
              FilledButton.icon(
                onPressed: _apply,
                icon: const Icon(Icons.check),
                label: const Text('Appliquer'),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                controller: _search,
                decoration: const InputDecoration(
                  labelText: 'Rechercher dans la description',
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: chips),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _minCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9,.\s]')),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Montant min',
                        prefixIcon: Icon(Icons.low_priority),
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _maxCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9,.\s]')),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Montant max',
                        prefixIcon: Icon(Icons.high_quality),
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickFrom,
                      icon: const Icon(Icons.today_outlined),
                      label: Text(
                        _from == null ? 'Du —' : Formatters.dateFull(_from!),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickTo,
                      icon: const Icon(Icons.event_outlined),
                      label: Text(
                        _to == null ? 'Au —' : Formatters.dateFull(_to!),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SafeArea(
                top: false,
                child: FilledButton.icon(
                  onPressed: _apply,
                  icon: const Icon(Icons.check),
                  label: const Text('Appliquer'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubmitIntent extends Intent {
  const _SubmitIntent();
}
