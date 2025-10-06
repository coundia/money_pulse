// Mini right-drawer quick order panel: French UI, compact width/height (background product stays visible), prefill from session/prefs, only "Identifiant" required, amount read-only (no input), payment/delivery/note hidden, ENTER submits, "Effacer" clears persisted prefs. Includes refresh that pulls connected user info.

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

  /// Utilisez cette méthode pour ouvrir le panel en mode "mini popup".
  /// Exemple d'appel:
  /// await showRightDrawer(context, child: OrderQuickPanel(item: item), widthFraction: 0.62, heightFraction: 0.92);
  static const double suggestedWidthFraction = 0.62;
  static const double suggestedHeightFraction = 0.50;

  @override
  ConsumerState<OrderQuickPanel> createState() => _OrderQuickPanelState();
}

class _OrderQuickPanelState extends ConsumerState<OrderQuickPanel> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
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
      note: null,
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
      barrierDismissible: true,
      builder: (_) => Align(
        alignment: Alignment.centerRight,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Material(
            color: Theme.of(context).colorScheme.surface,
            elevation: 16,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.receipt_long, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Détails du montant',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Fermer',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('Quantité'),
                      const Spacer(),
                      Text('$qty'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('Prix unitaire'),
                      const Spacer(),
                      Text(unitStr),
                    ],
                  ),
                  const Divider(height: 18),
                  Row(
                    children: [
                      Text(
                        'Total',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const Spacer(),
                      Text(
                        totalStr,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
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

    final isCompact = MediaQuery.of(context).size.width < 520;

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
            backgroundColor: Theme.of(context).colorScheme.surface,
            appBar: PreferredSize(
              preferredSize: const Size.fromHeight(58),
              child: AppBar(
                elevation: 0,
                centerTitle: false,
                titleSpacing: 12,
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Commander',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.item.name,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
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
            ),
            body: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Total à payer',
                                style: Theme.of(context).textTheme.labelMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                totalStr,
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Prix unitaire: ${Formatters.amountFromCents(widget.item.defaultPrice * 100)} FCFA',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Détails du montant',
                          onPressed: _showAmountInfoPopup,
                          icon: const Icon(Icons.info_outline),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _phoneCtrl,
                    autofocus: false,
                    decoration: const InputDecoration(
                      labelText: 'Identifiant',
                      hintText: 'Téléphone ou identifiant',
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s-]')),
                    ],
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
                          autofocus: true,
                          decoration: const InputDecoration(
                            labelText: 'Quantité',
                          ),
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
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
                      if (!isCompact) const SizedBox(width: 12),
                      if (!isCompact)
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: Theme.of(
                                context,
                              ).colorScheme.surfaceVariant.withOpacity(0.45),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.lock_outline, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Montant calculé automatiquement',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // Pas de champ montant: lecture seule affichée en haut
                  // Paiement et Mode de réception masqués pour simplicité
                  const SizedBox(height: 6),
                ],
              ),
            ),
            bottomNavigationBar: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                child: Row(
                  children: [
                    FilledButton.icon(
                      onPressed: _submit,
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Valider'),
                    ),
                  ],
                ),
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
