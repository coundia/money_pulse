// Right-drawer quick order panel: French UI, ENTER submits, AmountFieldQuickPad.
// Prefills from OrderPrefs (immediate + listen). Refresh button re-applies last
// saved order fields (esp. phone). Only phone is required. Amount stays tied to
// the clicked product price and syncs with quantity when locked.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/formatters.dart';
import '../../presentation/features/transactions/widgets/amount_field_quickpad.dart';
import '../application/order_prefs_controller.dart';
import '../domain/entities/marketplace_item.dart';

class OrderQuickPanel extends ConsumerStatefulWidget {
  final MarketplaceItem item;
  const OrderQuickPanel({super.key, required this.item});

  @override
  ConsumerState<OrderQuickPanel> createState() => _OrderQuickPanelState();
}

class _OrderQuickPanelState extends ConsumerState<OrderQuickPanel> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  final _amountCtrl = TextEditingController();

  String _paymentMethod = 'Espèces';
  String _deliveryMethod = 'Retrait';
  bool _lockAmountToItems = true;
  bool _didPrefill = false;

  @override
  void initState() {
    super.initState();

    // Always start with clicked product price in XOF
    _amountCtrl.text = widget.item.defaultPrice.toString();

    // Immediate prefill from current provider value, then listen for late load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cur = ref.read(orderPrefsProvider);
      if (cur.hasValue && !_didPrefill && cur.value != null) {
        _prefillFrom(cur.value!);
        _didPrefill = true;
        if (mounted) setState(() {});
      }
      ref.listen<AsyncValue<OrderPrefs>>(orderPrefsProvider, (prev, next) {
        if (!_didPrefill && next.hasValue && next.value != null) {
          _prefillFrom(next.value!);
          _didPrefill = true;
          if (mounted) setState(() {});
        }
      });
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _noteCtrl.dispose();
    _qtyCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  int _parseInt(String v, {int fallback = 0}) {
    return int.tryParse(v.replaceAll(RegExp(r'[^0-9]'), '')) ?? fallback;
  }

  void _syncAmountFromItems() {
    final qty = _parseInt(_qtyCtrl.text, fallback: 1);
    final unitXof = widget.item.defaultPrice;
    _amountCtrl.text = (qty * unitXof).toString();
  }

  Future<void> _reloadFromPrefs() async {
    // Re-apply last saved order (esp. phone) without touching amount
    final cur = ref.read(orderPrefsProvider);
    if (cur.hasValue && cur.value != null) {
      _prefillFrom(cur.value!);
      if (mounted) setState(() {});
    } else {
      // Force a reload; listener above will fill when available
      ref.invalidate(orderPrefsProvider);
    }
  }

  void _clearFormFields() {
    _nameCtrl.clear();
    _phoneCtrl.clear();
    _addressCtrl.clear();
    _noteCtrl.clear();
    _qtyCtrl.text = '1';
    _paymentMethod = 'Espèces';
    _deliveryMethod = 'Retrait';
    _lockAmountToItems = true;
    _amountCtrl.text = widget.item.defaultPrice.toString();
    setState(() {});
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final qty = _parseInt(_qtyCtrl.text, fallback: 1);
    final amountXof = _parseInt(
      _amountCtrl.text,
      fallback: widget.item.defaultPrice,
    );

    final prefs = OrderPrefs(
      buyerName: _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      address: _addressCtrl.text.trim().isEmpty
          ? null
          : _addressCtrl.text.trim(),
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      quantity: qty,
      amountCents: amountXof * 100,
      paymentMethod: _paymentMethod,
      deliveryMethod: _deliveryMethod,
    );

    await ref.read(orderPrefsProvider.notifier).save(prefs);

    if (mounted) {
      final totalStr = '${Formatters.amountFromCents(amountXof * 100)} FCFA';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Commande enregistrée • ${widget.item.name} • $qty x • $totalStr',
          ),
        ),
      );
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final amountXof = _parseInt(
      _amountCtrl.text,
      fallback: widget.item.defaultPrice,
    );
    final totalStr = '${Formatters.amountFromCents(amountXof * 100)} FCFA';

    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.enter): ActivateIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<Intent>(
            onInvoke: (_) {
              _submit();
              return null;
            },
          ),
        },
        child: FocusTraversalGroup(
          child: Scaffold(
            appBar: AppBar(
              title: Text('Commander • ${widget.item.name}'),
              actions: [
                IconButton(
                  tooltip: 'Remplir avec la dernière commande',
                  onPressed: _reloadFromPrefs,
                  icon: const Icon(Icons.refresh),
                ),
                IconButton(
                  tooltip: 'Effacer le formulaire',
                  onPressed: _clearFormFields,
                  icon: const Icon(Icons.delete_sweep),
                ),
              ],
            ),
            body: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          totalStr,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: _submit,
                        icon: const Icon(Icons.check),
                        label: const Text('Valider'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Nom non obligatoire
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(labelText: 'Nom complet'),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),

                  // Téléphone OBLIGATOIRE
                  TextFormField(
                    controller: _phoneCtrl,
                    decoration: const InputDecoration(labelText: 'Téléphone'),
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Téléphone requis'
                        : null,
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _addressCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Adresse de livraison',
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _qtyCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Quantité',
                          ),
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.next,
                          onChanged: (_) {
                            if (_lockAmountToItems)
                              setState(() => _syncAmountFromItems());
                          },
                          validator: (v) {
                            final q = _parseInt(v ?? '');
                            return q <= 0 ? 'Quantité invalide' : null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _paymentMethod,
                          items: const [
                            DropdownMenuItem(
                              value: 'Espèces',
                              child: Text('Espèces'),
                            ),
                            DropdownMenuItem(
                              value: 'Mobile Money',
                              child: Text('Mobile Money'),
                            ),
                            DropdownMenuItem(
                              value: 'Transfert bancaire',
                              child: Text('Transfert bancaire'),
                            ),
                          ],
                          onChanged: (v) =>
                              setState(() => _paymentMethod = v ?? 'Espèces'),
                          decoration: const InputDecoration(
                            labelText: 'Paiement',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  DropdownButtonFormField<String>(
                    value: _deliveryMethod,
                    items: const [
                      DropdownMenuItem(
                        value: 'Retrait',
                        child: Text('Retrait en magasin'),
                      ),
                      DropdownMenuItem(
                        value: 'Livraison',
                        child: Text('Livraison à domicile'),
                      ),
                    ],
                    onChanged: (v) =>
                        setState(() => _deliveryMethod = v ?? 'Retrait'),
                    decoration: const InputDecoration(
                      labelText: 'Mode de réception',
                    ),
                  ),
                  const SizedBox(height: 12),

                  AmountFieldQuickPad(
                    controller: _amountCtrl,
                    quickUnits: const [
                      0,
                      2000,
                      5000,
                      10000,
                      20000,
                      50000,
                      100000,
                      200000,
                      300000,
                      400000,
                      500000,
                      1000000,
                    ],
                    lockToItems: _lockAmountToItems,
                    onToggleLock: (v) {
                      setState(() {
                        _lockAmountToItems = v ?? true;
                        if (_lockAmountToItems) _syncAmountFromItems();
                      });
                    },
                    onChanged: () => setState(() {}),
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _noteCtrl,
                    decoration: const InputDecoration(labelText: 'Notes'),
                    minLines: 2,
                    maxLines: 4,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 20),

                  FilledButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Valider la commande'),
                  ),
                ],
              ),
            ),
            bottomNavigationBar: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Total: $totalStr',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.close),
                    label: const Text('Fermer'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _prefillFrom(OrderPrefs s) {
    _nameCtrl.text = s.buyerName ?? _nameCtrl.text;
    _phoneCtrl.text = s.phone ?? _phoneCtrl.text; // ← phone restored
    _addressCtrl.text = s.address ?? _addressCtrl.text;
    _noteCtrl.text = s.note ?? _noteCtrl.text;
    _qtyCtrl.text = (s.quantity ?? int.tryParse(_qtyCtrl.text) ?? 1).toString();
    _paymentMethod = s.paymentMethod ?? _paymentMethod;
    _deliveryMethod = s.deliveryMethod ?? _deliveryMethod;
    // amount stays as clicked product price; not overridden
  }
}
