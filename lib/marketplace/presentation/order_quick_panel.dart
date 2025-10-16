// Mini right-drawer quick order panel (French UI) with duplicate-order guard and confirmation.
// Keyboard-safe + Reveal-on-focus edition:
//  - Inputs appear as compact rows; expand only when tapped/focused
//  - Strong auto-scroll to keep focused input visible with header + keyboard
//  - Bottom spacer tied to keyboard height for reliable scroll room
//  - Same UX goodies (top "Valider", stepper, prefs, duplicate guard)
//
// NOTE: showRightDrawer removed; confirmation uses showModalBottomSheet.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/formatters.dart';
// REMOVED: import '../../presentation/widgets/right_drawer.dart';
import '../../shared/constants/env.dart';
import '../application/order_prefs_controller.dart';
import '../domain/entities/marketplace_item.dart';
import 'package:money_pulse/onboarding/presentation/providers/access_session_provider.dart';
import '../domain/entities/order_command_request.dart';
import '../infrastructure/order_command_repo_provider.dart';
import 'widgets/order_confirmation_panel.dart';
import '../infrastructure/order_guard_provider.dart';

class OrderQuickPanel extends ConsumerStatefulWidget {
  final MarketplaceItem item;
  final String baseUri;
  const OrderQuickPanel({
    super.key,
    required this.item,
    this.baseUri = Env.BASE_URI,
  });

  static const double suggestedWidthFraction = 0.62;
  static const double suggestedHeightFraction = 0.50;

  @override
  ConsumerState<OrderQuickPanel> createState() => _OrderQuickPanelState();
}

class _OrderQuickPanelState extends ConsumerState<OrderQuickPanel> {
  final _formKey = GlobalKey<FormState>();
  final _scrollCtrl = ScrollController();

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  final _amountCtrl = TextEditingController();

  // Focus nodes (only the focused row expands)
  final _fPhone = FocusNode();
  final _fQty = FocusNode();

  String _paymentMethod = 'NA';
  String _deliveryMethod = 'NA';
  bool _lockAmountToItems = true;
  bool _didPrefill = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _amountCtrl.text = widget.item.defaultPrice.toString();

    // Attach scroll helpers + mutual exclusive expansion
    _attachAutoScroll(_fPhone, others: [_fQty]);
    _attachAutoScroll(_fQty, others: [_fPhone]);

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
    _scrollCtrl.dispose();
    _fPhone.dispose();
    _fQty.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _qtyCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  // ---- Strong auto-scroll + single-expand logic ----------------------------

  void _attachAutoScroll(FocusNode node, {List<FocusNode> others = const []}) {
    node.addListener(() {
      if (node.hasFocus) {
        // collapse others
        for (final f in others) {
          if (f.hasFocus) f.unfocus();
        }
        // let the keyboard open/layout settle, then scroll
        Future.delayed(const Duration(milliseconds: 90), () {
          if (!mounted) return;
          _scrollFocusedIntoView(nodeContext: node.context);
        });
      }
    });
  }

  void _scrollFocusedIntoView({BuildContext? nodeContext}) {
    if (nodeContext == null) return;
    final rb = nodeContext.findRenderObject();
    if (rb is! RenderBox) return;

    final view = MediaQuery.of(context).size;
    final insets = MediaQuery.of(context).viewInsets.bottom; // keyboard
    final topPad = MediaQuery.of(context).padding.top;

    const appBarH = 58.0; // our AppBar height
    const safeTopBand = 16.0; // margin under the app bar
    const safeBottomBand = 20.0; // margin above the keyboard

    final box = rb;
    final offset = box.localToGlobal(Offset.zero);
    final fieldTop = offset.dy;
    final fieldBottom = fieldTop + box.size.height;

    final visibleTop = topPad + appBarH + safeTopBand;
    final visibleBottom = view.height - insets - safeBottomBand;
    final current = _scrollCtrl.offset;

    double? target;
    if (fieldBottom > visibleBottom) {
      final delta = fieldBottom - visibleBottom;
      target = (current + delta).clamp(
        _scrollCtrl.position.minScrollExtent,
        _scrollCtrl.position.maxScrollExtent,
      );
    } else if (fieldTop < visibleTop) {
      final delta = visibleTop - fieldTop;
      target = (current - delta).clamp(
        _scrollCtrl.position.minScrollExtent,
        _scrollCtrl.position.maxScrollExtent,
      );
    }

    if (target != null && target != current) {
      _scrollCtrl.animateTo(
        target,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    }
  }

  // ---- Helpers --------------------------------------------------------------

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
          'Vous avez déjà commandé « ${widget.item.name} ». '
          'Voulez-vous confirmer une nouvelle commande pour ce produit ?',
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

  // --- NEW: Bottom-sheet confirmation (replaces showRightDrawer) ------------
  Future<void> _showConfirmationSheet({
    required String productName,
    required String totalStr,
    required int quantity,
  }) async {
    final h = MediaQuery.of(context).size.height;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _BottomSheetContainer(
          height:
              h *
              OrderConfirmationPanel.suggestedHeightFraction, // keep same feel
          child: OrderConfirmationPanel(
            productName: productName,
            totalStr: totalStr,
            quantity: quantity,
          ),
        );
      },
    );
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

      // Close current panel if it's inside a route/sheet
      Navigator.of(context).maybePop();

      // Show confirmation in a bottom sheet (no right drawer)
      await _showConfirmationSheet(
        productName: widget.item.name,
        totalStr: totalStr,
        quantity: prefs.quantity ?? qty,
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
        LogicalKeySet(LogicalKeyboardKey.enter): const ActivateIntent(),
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
            resizeToAvoidBottomInset: true,
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
                  const SizedBox(width: 6),
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: FilledButton.icon(
                      onPressed: _submitting ? null : _submit,
                      icon: _submitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check),
                      label: Text(_submitting ? 'Envoi…' : 'Valider'),
                    ),
                  ),
                ],
              ),
            ),
            body: SafeArea(
              bottom: false,
              child: SingleChildScrollView(
                controller: _scrollCtrl,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // TOTAL CARD
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Theme.of(context).dividerColor,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Total à payer',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.labelMedium,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    totalStr,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Prix unitaire: ${Formatters.amountFromCents(widget.item.defaultPrice)} FCFA',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
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

                      // PHONE — reveal on focus
                      _RevealOnFocus(
                        label: 'Identifiant',
                        hint: 'Téléphone ou Email',
                        helper:
                            'Nous permet de vous joindre pour la livraison.',
                        preview: () => _phoneCtrl.text.trim().isEmpty
                            ? '—'
                            : _phoneCtrl.text.trim(),
                        focusNode: _fPhone,
                        scrollController: _scrollCtrl,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Identifiant requis'
                            : null,
                        fieldBuilder: (ctx) => TextFormField(
                          focusNode: _fPhone,
                          controller: _phoneCtrl,
                          autofocus: true,
                          decoration: const InputDecoration(
                            labelText: 'Identifiant',
                            hintText: 'Téléphone ou Email',
                            helperText:
                                'Nous permet de vous joindre pour la livraison.',
                          ),
                          textInputAction: TextInputAction.next,
                          enabled: !_submitting,
                        ),
                      ),

                      const SizedBox(height: 12),

                      // QUANTITY — reveal on focus
                      _RevealOnFocus(
                        label: 'Quantité',
                        hint: 'Minimum 1.',
                        preview: () => _qtyCtrl.text.trim().isEmpty
                            ? '1'
                            : _qtyCtrl.text.trim(),
                        focusNode: _fQty,
                        scrollController: _scrollCtrl,
                        fieldBuilder: (ctx) => _QtyWithStepper(
                          controller: _qtyCtrl,
                          focusNode: _fQty,
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
                      ),

                      const SizedBox(height: 18),

                      // Spacer that matches keyboard height to always allow scroll room
                      const _KeyboardInsetSpacer(extra: 24),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom CTA (mirrors top)
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

/// Adds bottom space equal to the keyboard height + [extra].
class _KeyboardInsetSpacer extends StatelessWidget {
  final double extra;
  const _KeyboardInsetSpacer({this.extra = 0});
  @override
  Widget build(BuildContext context) {
    final kb = MediaQuery.of(context).viewInsets.bottom;
    return SizedBox(height: kb + extra);
  }
}

/// Collapsed row that expands into the real field when focused/tapped,
/// and auto-scrolls into a safe visible region with header+keyboard.
class _RevealOnFocus extends StatefulWidget {
  final String label;
  final String? hint;
  final String? helper;
  final String Function()? preview; // how to display collapsed value
  final FocusNode focusNode;
  final ScrollController scrollController;
  final Widget Function(BuildContext) fieldBuilder;
  final String? Function(String?)? validator;

  const _RevealOnFocus({
    required this.label,
    this.hint,
    this.helper,
    this.preview,
    required this.focusNode,
    required this.scrollController,
    required this.fieldBuilder,
    this.validator,
  });

  @override
  State<_RevealOnFocus> createState() => _RevealOnFocusState();
}

class _RevealOnFocusState extends State<_RevealOnFocus>
    with SingleTickerProviderStateMixin {
  bool get _expanded => widget.focusNode.hasFocus;

  void _requestFocus() {
    if (!widget.focusNode.hasFocus) {
      FocusScope.of(context).requestFocus(widget.focusNode);
    }
  }

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {}); // rebuild to switch collapsed/expanded
    if (widget.focusNode.hasFocus) {
      // after expand, ensure visible
      Future.delayed(const Duration(milliseconds: 80), () {
        final rb = context.findRenderObject();
        if (rb is! RenderBox) return;
        final view = MediaQuery.of(context).size;
        final insets = MediaQuery.of(context).viewInsets.bottom;
        final topPad = MediaQuery.of(context).padding.top;
        const appBarH = 58.0;
        const safeTopBand = 16.0;
        const safeBottomBand = 20.0;

        final offset = rb.localToGlobal(Offset.zero);
        final fieldTop = offset.dy;
        final fieldBottom = fieldTop + rb.size.height;

        final visibleTop = topPad + appBarH + safeTopBand;
        final visibleBottom = view.height - insets - safeBottomBand;

        final pos = widget.scrollController.position;
        final current = widget.scrollController.offset;

        double? target;
        if (fieldBottom > visibleBottom) {
          final delta = fieldBottom - visibleBottom;
          target = (current + delta).clamp(
            pos.minScrollExtent,
            pos.maxScrollExtent,
          );
        } else if (fieldTop < visibleTop) {
          final delta = visibleTop - fieldTop;
          target = (current - delta).clamp(
            pos.minScrollExtent,
            pos.maxScrollExtent,
          );
        }

        if (target != null && target != current) {
          widget.scrollController.animateTo(
            target,
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final collapsed = _CollapsedRow(
      label: widget.label,
      hint: widget.hint,
      helper: widget.helper,
      value: widget.preview?.call(),
      onTap: _requestFocus,
    );

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeOut,
      child: _expanded
          ? AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              child: Column(
                key: const ValueKey('expanded'),
                children: [widget.fieldBuilder(context)],
              ),
            )
          : Container(key: const ValueKey('collapsed'), child: collapsed),
    );
  }
}

class _CollapsedRow extends StatelessWidget {
  final String label;
  final String? hint;
  final String? helper;
  final String? value;
  final VoidCallback onTap;

  const _CollapsedRow({
    required this.label,
    this.hint,
    this.helper,
    this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = (value == null || value!.isEmpty) ? (hint ?? '—') : value!;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 6),
              Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if ((helper ?? '').isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  helper!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _QtyWithStepper extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;
  final VoidCallback onChanged;
  final bool enabled;

  const _QtyWithStepper({
    required this.controller,
    this.focusNode,
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
            focusNode: widget.focusNode,
            controller: widget.controller,
            enabled: widget.enabled,
            decoration: const InputDecoration(
              labelText: 'Quantité',
              helperText: 'Minimum 1.',
            ),
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

/// Drawer-like bottom sheet container with rounded top corners.
class _BottomSheetContainer extends StatelessWidget {
  final double height;
  final Widget child;
  const _BottomSheetContainer({required this.height, required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Material(
          color: cs.surface,
          elevation: 10,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
          ),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(height: height, width: double.infinity, child: child),
        ),
      ),
    );
  }
}
