import 'package:flutter/material.dart';
import 'package:money_pulse/presentation/shared/formatters.dart';

class PosCartLine {
  final String? productId;
  final String label;
  final int quantity;
  final int unitPrice;

  const PosCartLine({
    this.productId,
    required this.label,
    required this.quantity,
    required this.unitPrice,
  });

  int get lineTotal => quantity * unitPrice;

  factory PosCartLine.fromMap(Map<String, Object?> m) => PosCartLine(
    productId: m['productId'] as String?,
    label: (m['label'] as String?) ?? '—',
    quantity: (m['quantity'] as int?) ?? 0,
    unitPrice: (m['unitPrice'] as int?) ?? 0,
  );
}

class PosCheckoutPanel extends StatefulWidget {
  final List<PosCartLine> lines;
  final String initialTypeEntry;
  final String? initialDescription;
  final DateTime? initialWhen;
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
  late DateTime _when;
  late String _typeEntry;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _when = widget.initialWhen ?? DateTime.now();
    _typeEntry = widget.initialTypeEntry == 'DEBIT' ? 'DEBIT' : 'CREDIT';
    _descCtrl.text = widget.initialDescription ?? '';
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _safePop([dynamic result]) async {
    if (_closing) return;
    _closing = true;
    await Future.delayed(Duration.zero);
    if (!mounted) return;
    final nav = Navigator.of(context);
    if (nav.canPop()) nav.pop(result);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _when,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      _when = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _when.hour,
        _when.minute,
        _when.second,
        _when.millisecond,
        _when.microsecond,
      );
    });
  }

  int get _totalCents => widget.lines.fold(0, (p, e) => p + e.lineTotal);
  Color get _accent => _typeEntry == 'CREDIT' ? Colors.green : Colors.red;

  Widget _dateChip(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: _pickDate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_month),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                Formatters.dateFull(_when),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _typeToggle(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(10),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
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
          onSelectionChanged: (s) => setState(() => _typeEntry = s.first),
          showSelectedIcon: false,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = Formatters.amountFromCents(_totalCents);

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
                LayoutBuilder(
                  builder: (context, c) {
                    final narrow = c.maxWidth < 420;
                    if (narrow) {
                      return Column(
                        children: [
                          _dateChip(context),
                          const SizedBox(height: 8),
                          _typeToggle(context),
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: _dateChip(context)),
                        const SizedBox(width: 12),
                        Expanded(child: _typeToggle(context)),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
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
                            _typeEntry == 'CREDIT' ? Icons.north : Icons.south,
                            color: _accent,
                          ),
                        ),
                        title: Text(
                          l.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${l.quantity} × ${Formatters.amountFromCents(l.unitPrice)}',
                        ),
                        trailing: Text(
                          Formatters.amountFromCents(l.lineTotal),
                          style: TextStyle(
                            color: _accent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      );
                    },
                  ),
          ),
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
                            final payload = {
                              'typeEntry': _typeEntry,
                              'when': _when,
                              'description': _descCtrl.text.trim().isEmpty
                                  ? null
                                  : _descCtrl.text.trim(),
                              'categoryId': null,
                            };
                            _safePop(payload);
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
