// Right-drawer panel to add to or set a customer's balance using CheckoutCartUseCase.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/presentation/shared/formatters.dart';
import 'package:money_pulse/presentation/app/providers.dart';
import 'package:money_pulse/presentation/app/account_selection.dart';
import 'package:money_pulse/presentation/widgets/right_drawer.dart';
import 'package:money_pulse/presentation/features/transactions/providers/transaction_list_providers.dart';
import 'package:money_pulse/presentation/app/providers/checkout_cart_usecase_provider.dart'
    hide checkoutCartUseCaseProvider;

class CustomerBalanceAdjustPanel extends ConsumerStatefulWidget {
  final String customerId;
  final int currentBalanceCents;
  final String? companyId;
  final String mode; // 'add' or 'set'
  const CustomerBalanceAdjustPanel({
    super.key,
    required this.customerId,
    required this.currentBalanceCents,
    this.companyId,
    this.mode = 'add',
  });

  @override
  ConsumerState<CustomerBalanceAdjustPanel> createState() =>
      _CustomerBalanceAdjustPanelState();
}

class _CustomerBalanceAdjustPanelState
    extends ConsumerState<CustomerBalanceAdjustPanel> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController(text: 'Ajustement solde client');
  bool _submitting = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  int _parseToCents(String v) {
    final s = v.replaceAll(RegExp(r'\s'), '').replaceAll(',', '.');
    final d = double.tryParse(s) ?? 0;
    return (d * 100).round();
  }

  Future<void> _save() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;

    final selectedAccountId = ref.read(selectedAccountIdProvider);
    if (selectedAccountId == null || selectedAccountId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sélectionnez d’abord un compte')),
      );
      return;
    }

    final usecase = ref.read(checkoutCartUseCaseProvider);
    final amountCents = _parseToCents(_amountCtrl.text);
    if (amountCents <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Montant invalide')));
      return;
    }

    final now = DateTime.now();
    late final String typeEntry;
    late final int delta;

    if (widget.mode == 'set') {
      delta = amountCents - widget.currentBalanceCents;
      if (delta == 0) {
        if (mounted) Navigator.of(context).pop(false);
        return;
      }
      typeEntry = delta > 0 ? 'CREDIT' : 'DEBIT';
    } else {
      delta = amountCents;
      typeEntry = 'CREDIT';
    }

    setState(() => _submitting = true);
    try {
      await usecase.execute(
        typeEntry: typeEntry,
        accountId: selectedAccountId,
        companyId: widget.companyId,
        customerId: widget.customerId,
        categoryId: null,
        description: _descCtrl.text.trim().isEmpty
            ? null
            : _descCtrl.text.trim(),
        when: now,
        lines: [
          {
            'productId': null,
            'label': 'Ajustement solde',
            'quantity': 1,
            'unitPrice': delta.abs(),
          },
        ],
      );

      await ref.read(transactionsProvider.notifier).load();
      await ref.read(balanceProvider.notifier).load();
      ref.invalidate(transactionListItemsProvider);
      ref.invalidate(selectedAccountProvider);

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Échec: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSet = widget.mode == 'set';
    final title = isSet ? 'Définir le solde' : 'Ajouter au solde';

    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.enter): const _SubmitIntent(),
        LogicalKeySet(LogicalKeyboardKey.numpadEnter): const _SubmitIntent(),
      },
      child: Actions(
        actions: {
          _SubmitIntent: CallbackAction<_SubmitIntent>(
            onInvoke: (_) {
              _save();
              return null;
            },
          ),
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(title),
            leading: IconButton(
              tooltip: 'Fermer',
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
          body: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Solde actuel'),
                        const SizedBox(height: 4),
                        Text(
                          Formatters.amountFromCents(
                            widget.currentBalanceCents,
                          ),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9,.\s]')),
                  ],
                  decoration: InputDecoration(
                    labelText: isSet ? 'Nouveau solde' : 'Montant à ajouter',
                    prefixIcon: const Icon(Icons.attach_money),
                    border: const OutlineInputBorder(),
                    helperText: (_amountCtrl.text.isEmpty)
                        ? null
                        : 'Aperçu: ${Formatters.amountFromCents(_parseToCents(_amountCtrl.text))}',
                    isDense: true,
                  ),
                  validator: (v) {
                    final cents = _parseToCents(v ?? '');
                    if (cents <= 0) return 'Montant invalide';
                    return null;
                  },
                  onChanged: (_) => setState(() {}),
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _save(),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final u in const [
                      1000,
                      2000,
                      5000,
                      10000,
                      20000,
                      50000,
                      100000,
                    ])
                      OutlinedButton(
                        onPressed: () {
                          final cur = _parseToCents(_amountCtrl.text);
                          final next = cur + u;
                          _amountCtrl.text = (next / 100).toStringAsFixed(2);
                          setState(() {});
                        },
                        child: Text(Formatters.amountFromCents(u)),
                      ),
                    if (!isSet)
                      OutlinedButton.icon(
                        onPressed: () {
                          _amountCtrl.text = (widget.currentBalanceCents / 100)
                              .toStringAsFixed(2);
                          setState(() {});
                        },
                        icon: const Icon(Icons.content_paste_go),
                        label: const Text('Coller solde actuel'),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Description (optionnel)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _save(),
                ),
                const SizedBox(height: 20),
                SafeArea(
                  top: false,
                  child: FilledButton.icon(
                    onPressed: _submitting ? null : _save,
                    icon: const Icon(Icons.check),
                    label: Text(_submitting ? 'Traitement...' : 'Valider'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SubmitIntent extends Intent {
  const _SubmitIntent();
}
