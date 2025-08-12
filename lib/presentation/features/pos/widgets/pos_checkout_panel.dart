import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Lightweight view model for displaying a cart line in the checkout panel.
/// (UI only — persistence is the caller’s responsibility)
class PosCartLine {
  final String? productId;
  final String label; // what the user sees (ex: name or code)
  final int quantity; // units
  final int unitPrice; // cents

  const PosCartLine({
    this.productId,
    required this.label,
    required this.quantity,
    required this.unitPrice,
  });

  int get lineTotal => quantity * unitPrice;

  /// Optional: create from a map shaped like your use case lines
  /// { 'productId': String?, 'label': String, 'quantity': int, 'unitPrice': int }
  factory PosCartLine.fromMap(Map<String, Object?> m) => PosCartLine(
    productId: m['productId'] as String?,
    label: (m['label'] as String?) ?? '—',
    quantity: (m['quantity'] as int?) ?? 0,
    unitPrice: (m['unitPrice'] as int?) ?? 0,
  );
}

class PosCheckoutPanel extends StatefulWidget {
  /// Lines to display (snapshot). Typically built from your cart state.
  final List<PosCartLine> lines;

  /// ‘CREDIT’ = sale / income (default), ‘DEBIT’ = purchase / expense
  final String initialTypeEntry;

  /// Optional prefilled description
  final String? initialDescription;

  /// Optional initial date (defaults to now)
  final DateTime? initialWhen;

  /// Optional account label (purely informational)
  final String? accountLabel;

  const PosCheckoutPanel({
    super.key,
    required this.lines,
    this.initialTypeEntry = 'CREDIT',
    this.initialDescription,
    this.initialWhen,
    this.accountLabel,
  });

  @override
  State<PosCheckoutPanel> createState() => _PosCheckoutPanelState();
}

class _PosCheckoutPanelState extends State<PosCheckoutPanel> {
  final _descCtrl = TextEditingController();
  late String _typeEntry; // 'CREDIT' or 'DEBIT'
  late DateTime _when;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _typeEntry = (widget.initialTypeEntry == 'DEBIT') ? 'DEBIT' : 'CREDIT';
    _when = widget.initialWhen ?? DateTime.now();
    _descCtrl.text = widget.initialDescription ?? '';
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _safePop([dynamic result]) async {
    if (_closing) return; // prevents double pop
    _closing = true;
    // let current frame settle (avoids !_debugLocked)
    await Future.delayed(Duration.zero);
    if (!mounted) return;
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop(result);
    }
  }

  String _money(int cents) {
    // Display in whole units without currency symbol (ex: "1 500")
    final v = cents / 100.0;
    return NumberFormat.decimalPattern().format(v);
  }

  int get _totalCents => widget.lines.fold(0, (p, e) => p + e.lineTotal);

  Color get _accent => _typeEntry == 'CREDIT' ? Colors.green : Colors.red;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _when,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    // keep current time-of-day
    setState(
      () => _when = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _when.hour,
        _when.minute,
        _when.second,
        _when.millisecond,
        _when.microsecond,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = _money(_totalCents);
    final isSale = _typeEntry == 'CREDIT';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Fermer',
          icon: const Icon(Icons.close),
          onPressed: () => _safePop(false),
        ),
        title: const Text('Validation du panier'),
      ),
      body: Column(
        children: [
          // Header: account + period + type (income/expense)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if ((widget.accountLabel ?? '').isNotEmpty)
                  Row(
                    children: [
                      const Icon(Icons.account_balance_wallet, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        widget.accountLabel!,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: _pickDate,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Theme.of(
                                context,
                              ).colorScheme.outlineVariant,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.calendar_month),
                              const SizedBox(width: 8),
                              Text(DateFormat.yMMMd().format(_when)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                            value: 'DEBIT',
                            icon: Icon(Icons.south),
                            label: Text('Dépense'),
                          ),
                          ButtonSegment(
                            value: 'CREDIT',
                            icon: Icon(Icons.north),
                            label: Text('Vente'),
                          ),
                        ],
                        selected: {_typeEntry},
                        onSelectionChanged: (s) =>
                            setState(() => _typeEntry = s.first),
                        showSelectedIcon: false,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Lines
          Expanded(
            child: widget.lines.isEmpty
                ? const Center(child: Text('Aucun article'))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    itemCount: widget.lines.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final l = widget.lines[i];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: _accent.withOpacity(0.12),
                          child: Icon(
                            isSale ? Icons.north : Icons.south,
                            color: _accent,
                          ),
                        ),
                        title: Text(
                          l.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${l.quantity} × ${_money(l.unitPrice)}',
                        ),
                        trailing: Text(
                          _money(l.lineTotal),
                          style: TextStyle(
                            color: _accent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Note / Description
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: TextField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                labelText: 'Description (facultatif)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              minLines: 1,
              maxLines: 3,
            ),
          ),

          // Footer: total + actions
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).dividerColor,
                  width: 0.6,
                ),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(
                        'Total',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Spacer(),
                      Text(
                        total,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: _accent,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _safePop(false),
                          child: const Text('Annuler'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () {
                            // Keep the contract simple: return true on confirm.
                            // Caller has the cart lines; it can run the Checkout use case
                            // with _typeEntry / _when / _descCtrl.text if needed
                            // by storing them externally or using a scoped controller.
                            _safePop(true);
                          },
                          icon: const Icon(Icons.check),
                          label: const Text('Confirmer'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
