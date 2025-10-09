// Mini right-drawer quick order panel (French UI) with duplicate-order guard and confirmation.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/formatters.dart';
import '../../presentation/widgets/right_drawer.dart';
import '../application/order_prefs_controller.dart';
import '../domain/entities/marketplace_item.dart';
import 'package:money_pulse/onboarding/presentation/providers/access_session_provider.dart';
import '../domain/entities/order_command_request.dart';
import '../infrastructure/order_command_repo_provider.dart';
import 'package:flutter/foundation.dart';
import 'widgets/order_confirmation_panel.dart';
import '../infrastructure/order_guard_provider.dart';

class OrderQuickPanel extends ConsumerStatefulWidget {
  final MarketplaceItem item;
  final String baseUri;
  const OrderQuickPanel({
    super.key,
    required this.item,
    this.baseUri = 'http://127.0.0.1:8095',
  });

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

  String _paymentMethod = 'NA';
  String _deliveryMethod = 'NA';
  bool _lockAmountToItems = true;
  bool _didPrefill = false;
  bool _submitting = false;

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

  int _parseInt(String v, {int fallback = 0}) =>
      int.tryParse(v.replaceAll(RegExp(r'[^0-9]'), '')) ?? fallback;

  void _syncAmountFromItems() {
    final qty = _parseInt(_qtyCtrl.text, fallback: 1);
    final unitXof = widget.item.defaultPrice;
    _amountCtrl.text = (qty * unitXof).toString();
  }

  void _setQty(int q) {
    if (q < 1) q = 1;
    _qtyCtrl.text = q.toString();
    if (_lockAmountToItems) {
      setState(() => _syncAmountFromItems());
    } else {
      setState(() {});
    }
  }

  void _incQty(int delta) {
    final cur = _parseInt(_qtyCtrl.text, fallback: 1);
    _setQty(cur + delta);
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
    _paymentMethod = 'NA';
    _deliveryMethod = 'NA';
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

  Future<bool> _confirmDuplicateIfNeeded() async {
    final already = ref
        .read(orderedProductsGuardProvider)
        .contains(widget.item.id);
    if (!already) return true;
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmer une deuxième commande'),
        content: Text(
          'Vous avez déjà commandé « ${widget.item.name} ». Voulez-vous confirmer une nouvelle commande pour ce produit ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
    debugPrint(
      '[OrderQuickPanel] duplicate-check productId=${widget.item.id} confirm=$ok',
    );
    return ok == true;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_submitting) return;

    final proceed = await _confirmDuplicateIfNeeded();
    if (!proceed) return;

    final qty = _parseInt(_qtyCtrl.text, fallback: 1);
    final amountXof = _parseInt(
      _amountCtrl.text,
      fallback: widget.item.defaultPrice,
    );
    final amountCents = amountXof * 1;

    var buyerName = _nameCtrl.text.trim();
    final grant = ref.read(accessSessionProvider);
    if (buyerName.isEmpty) {
      final u = grant?.username?.trim();
      if (u != null && u.isNotEmpty) buyerName = u;
    }

    var identOrPhone = _phoneCtrl.text.trim();
    if (identOrPhone.isEmpty) {
      final p = grant?.phone?.trim();
      final u = grant?.username?.trim();
      if (p != null && p.isNotEmpty) {
        identOrPhone = p;
      } else if (u != null && u.isNotEmpty) {
        identOrPhone = u;
      }
    }

    final prefs = OrderPrefs(
      buyerName: buyerName.isEmpty ? null : buyerName,
      phone: identOrPhone.isEmpty ? null : identOrPhone,
      address: _addressCtrl.text.trim().isEmpty
          ? null
          : _addressCtrl.text.trim(),
      note: null,
      quantity: qty,
      amountCents: amountCents,
      paymentMethod: _paymentMethod,
      deliveryMethod: _deliveryMethod,
    );

    final cmd = OrderCommandRequest(
      productId: widget.item.id,
      userId: null,
      identifiant: prefs.phone ?? '',
      telephone: prefs.phone,
      mail: grant?.email,
      ville: null,
      remoteId: null,
      localId: null,
      status: null,
      buyerName: prefs.buyerName,
      address: prefs.address,
      notes: null,
      paymentMethod: prefs.paymentMethod,
      deliveryMethod: prefs.deliveryMethod,
      amountCents: prefs.amountCents ?? amountCents,
      quantity: prefs.quantity ?? qty,
      dateCommand: DateTime.now().toUtc(),
    );

    debugPrint(
      '[OrderQuickPanel] about to send command payload.map=${cmd.toJson()}',
    );

    setState(() => _submitting = true);
    try {
      await ref.read(orderCommandRepoProvider(widget.baseUri)).send(cmd);
      await ref.read(orderPrefsProvider.notifier).save(prefs);

      ref
          .read(orderedProductsGuardProvider.notifier)
          .markOrdered(widget.item.id);

      if (!mounted) return;

      final totalStr =
          '${Formatters.amountFromCents((prefs.amountCents ?? amountCents))} FCFA';

      Navigator.of(context).maybePop();

      await showRightDrawer(
        context,
        widthFraction: OrderConfirmationPanel.suggestedWidthFraction,
        heightFraction: OrderConfirmationPanel.suggestedHeightFraction,
        child: OrderConfirmationPanel(
          productName: widget.item.name,
          totalStr: totalStr,
          quantity: prefs.quantity ?? qty,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Échec de l’envoi: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showAmountInfoPopup() {
    final qty = _parseInt(_qtyCtrl.text, fallback: 1);
    final unit = widget.item.defaultPrice;
    final total = _parseInt(_amountCtrl.text, fallback: unit);
    final unitStr = '${Formatters.amountFromCents(unit)} FCFA';
    final totalStr = '${Formatters.amountFromCents(total)} FCFA';

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
    final totalStr = '${Formatters.amountFromCents(amountXof)} FCFA';

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
                    onPressed: _submitting ? null : _reloadFromPrefs,
                    icon: const Icon(Icons.refresh),
                  ),
                  IconButton(
                    tooltip: 'Effacer le formulaire',
                    onPressed: _submitting ? null : _clearFormFields,
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
                                'Prix unitaire: ${Formatters.amountFromCents(widget.item.defaultPrice)} FCFA',
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
                    decoration: const InputDecoration(
                      labelText: 'Identifiant',
                      hintText: 'Téléphone ou Email',
                    ),

                    textInputAction: TextInputAction.next,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Identifiant requis'
                        : null,
                    enabled: !_submitting,
                  ),
                  const SizedBox(height: 12),
                  _QtyWithStepper(
                    controller: _qtyCtrl,
                    onMinus: _submitting ? null : () => _incQty(-1),
                    onPlus: _submitting ? null : () => _incQty(1),
                    onChanged: () {
                      if (_lockAmountToItems) {
                        setState(() => _syncAmountFromItems());
                      } else {
                        setState(() {});
                      }
                    },
                    enabled: !_submitting,
                  ),
                  const SizedBox(height: 18),
                ],
              ),
            ),
            bottomNavigationBar: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        totalStr,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _submitting ? null : _submit,
                      icon: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check_circle),
                      label: Text(_submitting ? 'Envoi…' : 'Valider'),
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

class _QtyWithStepper extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;
  final VoidCallback onChanged;
  final bool enabled;

  const _QtyWithStepper({
    required this.controller,
    required this.onMinus,
    required this.onPlus,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  State<_QtyWithStepper> createState() => _QtyWithStepperState();
}

class _QtyWithStepperState extends State<_QtyWithStepper> {
  int _parseInt(String v, {int fallback = 1}) =>
      int.tryParse(v.replaceAll(RegExp(r'[^0-9]'), '')) ?? fallback;

  @override
  Widget build(BuildContext context) {
    final qty = _parseInt(widget.controller.text, fallback: 1);
    final canDec = qty > 1 && widget.enabled;

    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: widget.controller,
            enabled: widget.enabled,
            decoration: const InputDecoration(labelText: 'Quantité'),
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            onChanged: (_) => widget.onChanged(),
            validator: (v) {
              final q = _parseInt(v ?? '');
              return q <= 0 ? 'Quantité invalide' : null;
            },
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          height: 44,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Tooltip(
                message: 'Diminuer',
                child: IconButton.filledTonal(
                  onPressed: canDec ? widget.onMinus : null,
                  icon: const Icon(Icons.remove),
                ),
              ),
              const SizedBox(width: 6),
              Tooltip(
                message: 'Augmenter',
                child: IconButton.filled(
                  onPressed: widget.enabled ? widget.onPlus : null,
                  icon: const Icon(Icons.add),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
