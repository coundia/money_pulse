// Right-drawer quick order panel: French UI, prefill from session/prefs, only phone required, amount is read-only and not editable, payment and delivery inputs hidden, small info popup explains total, ENTER submits, "Effacer" also clears persisted prefs.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/formatters.dart';
import '../application/order_prefs_controller.dart';
import '../domain/entities/marketplace_item.dart';
import 'package:money_pulse/onboarding/presentation/providers/access_session_provider.dart';

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
    _amountCtrl.text = widget.item.defaultPrice.toString();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prefillFromSession();
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
    final cur = ref.read(orderPrefsProvider);
    if (cur.hasValue && cur.value != null) {
      _prefillFrom(cur.value!);
    } else {
      ref.invalidate(orderPrefsProvider);
    }
    final grant = ref.read(accessSessionProvider);
    if (grant != null) {
      final sessionPhone = grant.phone?.trim();
      final sessionUsername = grant.username?.trim();
      if (sessionPhone != null && sessionPhone.isNotEmpty) {
        _phoneCtrl.text = sessionPhone;
      } else if (sessionUsername != null && sessionUsername.isNotEmpty) {
        _phoneCtrl.text = sessionUsername;
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _clearFormFields() async {
    _nameCtrl.clear();
    _phoneCtrl.clear();
    _addressCtrl.clear();
    _noteCtrl.clear();
    _qtyCtrl.text = '1';
    _paymentMethod = 'Espèces';
    _deliveryMethod = 'Retrait';
    _lockAmountToItems = true;
    _amountCtrl.text = widget.item.defaultPrice.toString();
    await ref.read(orderPrefsProvider.notifier).clear();
    _didPrefill = false;
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Formulaire réinitialisé et mémoire effacée'),
        ),
      );
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final qty = _parseInt(_qtyCtrl.text, fallback: 1);
    final amountXof = _parseInt(
      _amountCtrl.text,
      fallback: widget.item.defaultPrice,
    );

    var buyerName = _nameCtrl.text.trim();
    if (buyerName.isEmpty) {
      final grant = ref.read(accessSessionProvider);
      buyerName = (grant?.username?.trim().isNotEmpty == true)
          ? grant!.username!.trim()
          : buyerName;
    }

    var phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) {
      final grant = ref.read(accessSessionProvider);
      phone = (grant?.phone?.trim().isNotEmpty == true)
          ? grant!.phone!.trim()
          : ((grant?.username?.trim().isNotEmpty == true)
                ? grant!.username!.trim()
                : phone);
    }

    final prefs = OrderPrefs(
      buyerName: buyerName.isEmpty ? null : buyerName,
      phone: phone.isEmpty ? null : phone,
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

  void _showAmountInfoPopup() {
    final qty = _parseInt(_qtyCtrl.text, fallback: 1);
    final unit = widget.item.defaultPrice;
    final total = _parseInt(_amountCtrl.text, fallback: unit);
    final unitStr = '${Formatters.amountFromCents(unit * 100)} FCFA';
    final totalStr = '${Formatters.amountFromCents(total * 100)} FCFA';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Détails du montant'),
        content: Text(
          'Quantité: $qty\nPrix unitaire: $unitStr\nTotal: $totalStr',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
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
                      IconButton(
                        tooltip: 'Détails du montant',
                        onPressed: _showAmountInfoPopup,
                        icon: const Icon(Icons.info_outline),
                      ),
                      FilledButton.icon(
                        onPressed: _submit,
                        icon: const Icon(Icons.check),
                        label: const Text('Valider'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _phoneCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Telephone ou Identifiant',
                    ),
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Identifiant requis'
                        : null,
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
                      Expanded(child: SizedBox.shrink()),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const SizedBox.shrink(),
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
    _phoneCtrl.text = s.phone ?? _phoneCtrl.text;
    _addressCtrl.text = s.address ?? _addressCtrl.text;
    _noteCtrl.text = s.note ?? _noteCtrl.text;
    _qtyCtrl.text = (s.quantity ?? int.tryParse(_qtyCtrl.text) ?? 1).toString();
    _paymentMethod = s.paymentMethod ?? _paymentMethod;
    _deliveryMethod = s.deliveryMethod ?? _deliveryMethod;
  }

  void _prefillFromSession() {
    final grant = ref.read(accessSessionProvider);
    if (grant == null) return;
    if (_nameCtrl.text.trim().isEmpty &&
        (grant.username?.trim().isNotEmpty ?? false)) {
      _nameCtrl.text = grant.username!.trim();
    }
    if (_phoneCtrl.text.trim().isEmpty) {
      final sessionPhone = grant.phone?.trim();
      final sessionUsername = grant.username?.trim();
      if (sessionPhone != null && sessionPhone.isNotEmpty) {
        _phoneCtrl.text = sessionPhone;
      } else if (sessionUsername != null && sessionUsername.isNotEmpty) {
        _phoneCtrl.text = sessionUsername;
      }
    }
  }
}
